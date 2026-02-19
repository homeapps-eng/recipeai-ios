import Foundation
import StoreKit
import Combine

@MainActor
final class StoreKitManager: ObservableObject {
    static let shared = StoreKitManager()

    @Published var products: [Product] = []
    @Published var purchasedSubscriptions: [Product] = []
    @Published var subscriptionStatus: SubscriptionStatus?
    @Published var subscriptionExpirationDate: Date?
    @Published var isAutoRenewing = true
    @Published var pendingSwitchProduct: Product?
    @Published var isLoading = false
    @Published var error: Error?

    // Product IDs - configured in App Store Connect
    private let productIds = [
        "com.homeapps.recipeai.monthly",
        "com.homeapps.recipeai.annual"
    ]

    private var transactionListener: Task<Void, Error>?

    private init() {
        transactionListener = listenForTransactions()
    }

    deinit {
        transactionListener?.cancel()
    }

    // MARK: - Public Properties

    var isPremium: Bool {
        !purchasedSubscriptions.isEmpty
    }

    func resetOnSignOut() {
        purchasedSubscriptions = []
        subscriptionStatus = nil
        subscriptionExpirationDate = nil
        isAutoRenewing = true
        pendingSwitchProduct = nil
        error = nil
    }

    var monthlyProduct: Product? {
        products.first { $0.id.contains("monthly") }
    }

    var annualProduct: Product? {
        products.first { $0.id.contains("annual") }
    }

    // MARK: - Load Products

    func loadProducts() async {
        isLoading = true
        error = nil

        do {
            products = try await Product.products(for: productIds)
            products.sort { $0.price < $1.price }
            isLoading = false
        } catch {
            self.error = error
            isLoading = false
        }
    }

    // MARK: - Purchase

    enum PurchaseResult {
        case success(Transaction)
        case cancelled
        case pending
    }

    func purchase(_ product: Product) async throws -> PurchaseResult? {
        isLoading = true
        error = nil

        do {
            let result = try await product.purchase()

            switch result {
            case .success(let verification):
                let transaction = try checkVerified(verification)

                // Update subscription status
                await updateSubscriptionStatus()

                // Sync with backend
                await syncWithBackend(transaction: transaction)

                // Finish the transaction
                await transaction.finish()

                isLoading = false
                return .success(transaction)

            case .userCancelled:
                isLoading = false
                return .cancelled

            case .pending:
                isLoading = false
                return .pending

            @unknown default:
                isLoading = false
                return nil
            }
        } catch {
            isLoading = false
            self.error = error
            throw error
        }
    }

    // MARK: - Restore Purchases

    func restorePurchases() async {
        isLoading = true

        do {
            try await AppStore.sync()
            await updateSubscriptionStatus()
        } catch {
            self.error = error
        }

        isLoading = false
    }

    // MARK: - Update Subscription Status

    func updateSubscriptionStatus() async {
        // Backend is the source of truth for which user has a subscription.
        // StoreKit entitlements are device-level (Apple ID), not app-user-level,
        // so a guest or different user on the same device would see stale data.
        guard let userId = UserDefaultsManager.shared.userId,
              !UserDefaultsManager.shared.isGuestUser else {
            // Guest users cannot have subscriptions
            purchasedSubscriptions = []
            subscriptionStatus = nil
            subscriptionExpirationDate = nil
            isAutoRenewing = true
            pendingSwitchProduct = nil
            UserDefaultsManager.shared.isPremium = false
            return
        }

        // Step 1: Check backend first to confirm this user has an active subscription
        await fetchStatusFromBackend(userId: userId)

        guard subscriptionStatus?.isActive == true else {
            // Backend says not active — don't trust device-level StoreKit entitlements
            purchasedSubscriptions = []
            subscriptionExpirationDate = nil
            pendingSwitchProduct = nil
            isAutoRenewing = true
            UserDefaultsManager.shared.isPremium = false
            return
        }

        // Step 2: Get the most recent active transaction from entitlements
        var mostRecentTransaction: Transaction?
        var isAutoRenewing = true

        for await result in Transaction.currentEntitlements {
            do {
                let transaction = try checkVerified(result)

                // Keep the most recently purchased transaction (handles plan switches)
                if mostRecentTransaction == nil || transaction.purchaseDate > mostRecentTransaction!.purchaseDate {
                    mostRecentTransaction = transaction
                }
            } catch {
                // Transaction verification failed
            }
        }

        // Step 3: Get auto-renewal status and pending switch info
        var pendingSwitch: Product?
        if let currentTx = mostRecentTransaction,
           let product = products.first(where: { $0.id == currentTx.productID }),
           let subscription = product.subscription {
            do {
                let statuses = try await subscription.status
                for status in statuses {
                    if status.state == .subscribed || status.state == .inGracePeriod {
                        let renewalInfo = try checkVerified(status.renewalInfo)
                        isAutoRenewing = renewalInfo.willAutoRenew

                        // Detect pending plan switch (crossgrade/downgrade deferred to next renewal)
                        if renewalInfo.currentProductID != currentTx.productID {
                            pendingSwitch = products.first(where: { $0.id == renewalInfo.currentProductID })
                        }
                    }
                }
            } catch {
                // Failed to get renewal info
            }
        }

        // Step 4: Update published properties
        var purchased: [Product] = []
        if let tx = mostRecentTransaction,
           let product = products.first(where: { $0.id == tx.productID }) {
            purchased.append(product)
        }

        purchasedSubscriptions = purchased
        subscriptionExpirationDate = mostRecentTransaction?.expirationDate
        self.isAutoRenewing = isAutoRenewing
        self.pendingSwitchProduct = pendingSwitch
        UserDefaultsManager.shared.isPremium = !purchased.isEmpty

        // Sync current state to backend
        if let tx = mostRecentTransaction {
            await syncWithBackend(transaction: tx, willAutoRenew: isAutoRenewing)
        }
    }

    // MARK: - Transaction Listener

    private func listenForTransactions() -> Task<Void, Error> {
        return Task.detached {
            for await result in Transaction.updates {
                do {
                    let transaction = try await self.checkVerified(result)
                    await self.updateSubscriptionStatus()
                    await self.syncWithBackend(transaction: transaction)
                    await transaction.finish()
                } catch {
                    // Transaction verification failed
                }
            }
        }
    }

    // MARK: - Verification

    private func checkVerified<T>(_ result: VerificationResult<T>) throws -> T {
        switch result {
        case .unverified:
            throw StoreKitError.verificationFailed
        case .verified(let safe):
            return safe
        }
    }

    // MARK: - Backend Sync

    private func syncWithBackend(transaction: Transaction, willAutoRenew: Bool? = nil) async {
        guard let userId = UserDefaultsManager.shared.userId else { return }

        do {
            let expiresMs: Int64? = transaction.expirationDate.map { Int64($0.timeIntervalSince1970 * 1000) }

            let request = AppleSubscriptionRequest(
                userId: userId,
                productId: transaction.productID,
                transactionId: String(transaction.id),
                originalTransactionId: String(transaction.originalID),
                expiresDate: expiresMs,
                autoRenewStatus: willAutoRenew
            )

            let _: AppleSubscriptionResponse = try await NetworkManager.shared.post(
                endpoint: .verifyAppleSubscription,
                body: request
            )
        } catch {
            // Failed to sync with backend
        }
    }

    private func fetchStatusFromBackend(userId: String) async {
        do {
            let status: SubscriptionStatus = try await NetworkManager.shared.get(
                endpoint: .getSubscriptionStatus(userId: userId)
            )
            subscriptionStatus = status
        } catch {
            // Failed to fetch — treat as not active to prevent stale data leaking
            subscriptionStatus = nil
        }
    }
}

// MARK: - StoreKit Error

enum StoreKitError: LocalizedError {
    case verificationFailed
    case purchaseFailed
    case productNotFound

    var errorDescription: String? {
        switch self {
        case .verificationFailed:
            return "Transaction verification failed"
        case .purchaseFailed:
            return "Purchase failed"
        case .productNotFound:
            return "Product not found"
        }
    }
}

// MARK: - Apple Subscription Models

struct AppleSubscriptionRequest: Codable {
    let userId: String
    let productId: String
    let transactionId: String
    let originalTransactionId: String
    let expiresDate: Int64?
    let autoRenewStatus: Bool?
}

struct AppleSubscriptionResponse: Codable {
    let success: Bool
    let message: String?
}

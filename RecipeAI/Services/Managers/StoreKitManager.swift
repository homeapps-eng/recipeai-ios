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
        var purchased: [Product] = []
        var latestExpirationDate: Date?

        for await result in Transaction.currentEntitlements {
            do {
                let transaction = try checkVerified(result)

                if let product = products.first(where: { $0.id == transaction.productID }) {
                    purchased.append(product)
                }

                // Get expiration date from transaction
                if let expirationDate = transaction.expirationDate {
                    if latestExpirationDate == nil || expirationDate > latestExpirationDate! {
                        latestExpirationDate = expirationDate
                    }
                }
            } catch {
                // Transaction verification failed
            }
        }

        purchasedSubscriptions = purchased
        subscriptionExpirationDate = latestExpirationDate
        UserDefaultsManager.shared.isPremium = !purchased.isEmpty

        // Also fetch from backend for accuracy
        if let userId = UserDefaultsManager.shared.userId {
            await fetchStatusFromBackend(userId: userId)
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

    private func syncWithBackend(transaction: Transaction) async {
        guard let userId = UserDefaultsManager.shared.userId else { return }

        do {
            // Get expiration date in milliseconds
            let expiresMs: Int64? = transaction.expirationDate.map { Int64($0.timeIntervalSince1970 * 1000) }

            let request = AppleSubscriptionRequest(
                userId: userId,
                productId: transaction.productID,
                transactionId: String(transaction.id),
                originalTransactionId: String(transaction.originalID),
                expiresDate: expiresMs,
                autoRenewStatus: nil // Will be set by webhook based on renewal info
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

            // If backend says not active, override local StoreKit cache
            if !status.isActive {
                purchasedSubscriptions = []
                subscriptionExpirationDate = nil
                UserDefaultsManager.shared.isPremium = false
            }
        } catch {
            // Failed to fetch status from backend
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

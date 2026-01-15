import Foundation
import Combine

@MainActor
final class SubscriptionManager: ObservableObject {
    static let shared = SubscriptionManager()

    @Published var subscriptionStatus: SubscriptionStatus?
    @Published var pricingPlans: [PricingPlan] = []
    @Published var isLoading = false
    @Published var error: Error?

    private var lastFetchTime: Date?
    private let cacheDuration: TimeInterval = AppConfig.subscriptionCacheDurationSeconds

    private init() {}

    // MARK: - Public Properties

    var isPremium: Bool {
        subscriptionStatus?.isPremium ?? UserDefaultsManager.shared.isPremium
    }

    var needsRefresh: Bool {
        guard let lastFetch = lastFetchTime else { return true }
        return Date().timeIntervalSince(lastFetch) > cacheDuration
    }

    // MARK: - Status Methods

    func fetchStatus(userId: String, forceRefresh: Bool = false) async {
        guard forceRefresh || needsRefresh else { return }

        isLoading = true
        error = nil

        do {
            let status: SubscriptionStatus = try await NetworkManager.shared.get(
                endpoint: .getSubscriptionStatus(userId: userId)
            )
            subscriptionStatus = status
            lastFetchTime = Date()

            // Update UserDefaults cache
            UserDefaultsManager.shared.isPremium = status.isPremium

            isLoading = false
        } catch {
            self.error = error
            isLoading = false
        }
    }

    func refreshStatus() async {
        guard let userId = UserDefaultsManager.shared.userId else { return }
        await fetchStatus(userId: userId, forceRefresh: true)
    }

    // MARK: - Pricing Plans

    func fetchPricingPlans(currency: String = "USD") async {
        isLoading = true
        error = nil

        do {
            let response: PricingPlansResponse = try await NetworkManager.shared.get(
                endpoint: .getPricingPlans(currency: currency)
            )
            pricingPlans = response.plans
            isLoading = false
        } catch {
            self.error = error
            isLoading = false
        }
    }

    // MARK: - Checkout

    func createCheckoutSession(userId: String, priceId: String) async throws -> URL {
        let request = CreateCheckoutRequest(
            userId: userId,
            priceId: priceId,
            successUrl: AppConfig.subscriptionSuccessURL,
            cancelUrl: AppConfig.subscriptionCancelURL
        )

        let response: CheckoutSessionResponse = try await NetworkManager.shared.post(
            endpoint: .createCheckoutSession,
            body: request
        )

        guard let url = URL(string: response.url) else {
            throw SubscriptionError.invalidCheckoutURL
        }

        return url
    }

    // MARK: - Customer Portal

    func getCustomerPortalURL(userId: String) async throws -> URL {
        let response: CustomerPortalResponse = try await NetworkManager.shared.get(
            endpoint: .getCustomerPortal(userId: userId)
        )

        guard let url = URL(string: response.url) else {
            throw SubscriptionError.invalidPortalURL
        }

        return url
    }

    // MARK: - Sync Subscription

    /// Manually syncs subscription status from Stripe (useful after checkout)
    func syncSubscription(userId: String) async throws {
        let _: SyncSubscriptionResponse = try await NetworkManager.shared.post(
            endpoint: .syncSubscription(userId: userId),
            body: EmptyRequest()
        )
        // After sync, fetch the updated status
        await fetchStatus(userId: userId, forceRefresh: true)
    }

    // MARK: - Cancel Subscription

    func cancelSubscription(userId: String) async throws {
        let _: CancelSubscriptionResponse = try await NetworkManager.shared.post(
            endpoint: .cancelSubscription(userId: userId),
            body: EmptyRequest()
        )

        // Refresh status after cancellation
        await fetchStatus(userId: userId, forceRefresh: true)
    }

    // MARK: - Clear

    func clear() {
        subscriptionStatus = nil
        pricingPlans = []
        lastFetchTime = nil
        error = nil
    }
}

// MARK: - Subscription Error

enum SubscriptionError: LocalizedError {
    case invalidCheckoutURL
    case invalidPortalURL
    case cancellationFailed

    var errorDescription: String? {
        switch self {
        case .invalidCheckoutURL:
            return "Failed to create checkout session"
        case .invalidPortalURL:
            return "Failed to get customer portal"
        case .cancellationFailed:
            return "Failed to cancel subscription"
        }
    }
}

// MARK: - Empty Request Helper

private struct EmptyRequest: Encodable {}

import Foundation
import Combine

@MainActor
final class SubscriptionManager: ObservableObject {
    static let shared = SubscriptionManager()

    @Published var subscriptionStatus: SubscriptionStatus?
    @Published var isLoading = false
    @Published var error: Error?

    private var lastFetchTime: Date?
    private let cacheDuration: TimeInterval = AppConfig.subscriptionCacheDurationSeconds

    private init() {}

    // MARK: - Public Properties

    var isPremium: Bool {
        // Check StoreKit first, then fall back to backend status
        if StoreKitManager.shared.isPremium {
            return true
        }
        return subscriptionStatus?.isPremium ?? UserDefaultsManager.shared.isPremium
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

    // MARK: - Clear

    func clear() {
        subscriptionStatus = nil
        lastFetchTime = nil
        error = nil
    }
}

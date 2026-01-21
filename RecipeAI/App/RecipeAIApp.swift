import SwiftUI
import SwiftData
import FirebaseCore

@main
struct RecipeAIApp: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    @StateObject private var authManager = AuthManager.shared
    @StateObject private var userDefaultsManager = UserDefaultsManager.shared

    var sharedModelContainer: ModelContainer = {
        let schema = Schema([
            FavoriteRecipe.self,
        ])
        let modelConfiguration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: false)

        do {
            return try ModelContainer(for: schema, configurations: [modelConfiguration])
        } catch {
            fatalError("Could not create ModelContainer: \(error)")
        }
    }()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(authManager)
                .environmentObject(userDefaultsManager)
                .modelContainer(sharedModelContainer)
                .onOpenURL { url in
                    handleDeepLink(url)
                }
                .onReceive(NotificationCenter.default.publisher(for: .userDidSignOut)) { _ in
                    clearAllLocalData()
                }
        }
    }

    private func clearAllLocalData() {
        // Clear SwiftData favorites
        let context = sharedModelContainer.mainContext
        do {
            try context.delete(model: FavoriteRecipe.self)
            try context.save()
        } catch {
            // Error clearing SwiftData
        }

        // Clear usage tracker
        RecipeUsageTracker.shared.resetAll()
    }

    private func handleDeepLink(_ url: URL) {
        // Handle deep links: recipeai://subscription/success or recipeai://subscription/cancel
        guard url.scheme == "recipeai" else { return }

        switch url.host {
        case "subscription":
            if url.path.contains("success") {
                NotificationCenter.default.post(name: .subscriptionPaymentSuccess, object: nil)
            } else if url.path.contains("cancel") {
                NotificationCenter.default.post(name: .subscriptionPaymentCancelled, object: nil)
            }
        default:
            break
        }
    }
}

extension Notification.Name {
    static let subscriptionPaymentSuccess = Notification.Name("subscriptionPaymentSuccess")
    static let subscriptionPaymentCancelled = Notification.Name("subscriptionPaymentCancelled")
    static let userDidSignOut = Notification.Name("userDidSignOut")
}

import Foundation

enum AppConfig {
    // MARK: - Environment

    enum Environment {
        case debug
        case release

        static var current: Environment {
            #if DEBUG
            return .debug
            #else
            return .release
            #endif
        }
    }

    // MARK: - API Configuration

    static var apiBaseURL: String {
        switch Environment.current {
        case .debug:
            // Use test environment for debug builds
            return "https://recipeai-nexus-test-pqr45hbz6a-uc.a.run.app"
        case .release:
            return "https://api.recipe-ai.io"
        }
    }

    // MARK: - AdMob Configuration

    static var adMobAppId: String {
        switch Environment.current {
        case .debug:
            return "ca-app-pub-3940256099942544~3347511713" // Test App ID
        case .release:
            // TODO: Replace with production App ID
            return Bundle.main.object(forInfoDictionaryKey: "GADApplicationIdentifier") as? String ?? ""
        }
    }

    static var adMobRewardedAdUnitId: String {
        switch Environment.current {
        case .debug:
            return "ca-app-pub-3940256099942544/5224354917" // Test Ad Unit ID
        case .release:
            // TODO: Replace with production Ad Unit ID
            return ""
        }
    }

    // MARK: - Stripe Configuration

    static var stripeMonthlyPriceId: String {
        // TODO: Replace with actual price IDs
        return "price_monthly"
    }

    static var stripeAnnualPriceId: String {
        // TODO: Replace with actual price IDs
        return "price_annual"
    }

    // MARK: - App Limits

    static let maxDailyRecipes = 4
    static let maxDailyButtonPresses = 2
    static let maxFreeHomeRecipeLoads = 10
    static let subscriptionCacheDurationSeconds: TimeInterval = 300 // 5 minutes

    // MARK: - HTTP Configuration

    static let httpConnectTimeout: TimeInterval = 30
    static let httpReadTimeout: TimeInterval = 30
    static let httpWriteTimeout: TimeInterval = 30

    // MARK: - URLs

    static let termsURL = URL(string: "https://recipe-ai.io/terms")!
    static let privacyURL = URL(string: "https://recipe-ai.io/privacy")!

    // MARK: - Deep Links

    static let subscriptionSuccessURL = "recipeai://subscription/success"
    static let subscriptionCancelURL = "recipeai://subscription/cancel"

    // MARK: - Currencies

    static let supportedCurrencies = [
        "USD", "EUR", "GBP", "CAD", "AUD", "JPY", "CNY", "INR",
        "BRL", "MXN", "KRW", "SGD", "HKD", "CHF", "SEK", "NOK",
        "DKK", "NZD", "ZAR", "RUB"
    ]
}

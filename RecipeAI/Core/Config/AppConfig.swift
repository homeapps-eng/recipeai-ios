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
            return Bundle.main.object(forInfoDictionaryKey: "GADApplicationIdentifier") as? String ?? ""
        }
    }

    static var adMobRewardedAdUnitId: String {
        switch Environment.current {
        case .debug:
            return "ca-app-pub-3940256099942544/5224354917" // Test Ad Unit ID
        case .release:
            return "ca-app-pub-5036694200430445/9151047657"
        }
    }

    // MARK: - Stripe Configuration (Legacy - using StoreKit for iOS)

    static var stripeMonthlyPriceId: String {
        return "price_monthly"
    }

    static var stripeAnnualPriceId: String {
        return "price_annual"
    }

    // MARK: - App Limits

    static let maxDailyRecipes = 6
    static let maxDailyButtonPresses = 2
    static let maxDailyCalories = 3
    static let maxFreeHomeRecipeLoads = 10
    static let subscriptionCacheDurationSeconds: TimeInterval = 300 // 5 minutes

    // MARK: - HTTP Configuration

    static let httpConnectTimeout: TimeInterval = 60
    static let httpReadTimeout: TimeInterval = 60
    static let httpWriteTimeout: TimeInterval = 60

    // MARK: - URLs

    static let termsURL = URL(string: "https://recipe-ai.io/terms.html")!
    static let privacyURL = URL(string: "https://recipe-ai.io/privacy.html")!

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

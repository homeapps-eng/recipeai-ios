import Foundation

enum APIEndpoint {
    // MARK: - Base URL

    static var baseURL: URL {
        URL(string: AppConfig.apiBaseURL)!
    }

    // MARK: - Auth

    case signUp
    case signIn
    case googleSignIn
    case appleSignIn
    case verifyToken

    // MARK: - Recipe

    case generateRecipes
    case generateSingleRecipe
    case calculateCalories

    // MARK: - User Profile

    case getProfile(userId: String)
    case updateProfile(userId: String)
    case uploadAvatar(userId: String)

    // MARK: - Favorites

    case getFavorites(userId: String)
    case addFavorite(userId: String)
    case removeFavorite(userId: String, recipeId: String)
    case getFavoritesByDate(userId: String, date: String)

    // MARK: - User Preferences

    case getPreferences(userId: String)
    case updatePreferences(userId: String)

    // MARK: - Settings

    case getSettings(userId: String)
    case updateSettings(userId: String)

    // MARK: - Subscription

    case getPricingPlans(currency: String)
    case createCheckoutSession
    case getSubscriptionStatus(userId: String)
    case cancelSubscription(userId: String)
    case getCustomerPortal(userId: String)

    // MARK: - Support

    case submitSupport

    // MARK: - URL Components

    var path: String {
        switch self {
        // Auth
        case .signUp:
            return "/api/v1/auth/signup"
        case .signIn:
            return "/api/v1/auth/signin"
        case .googleSignIn:
            return "/api/v1/auth/google"
        case .appleSignIn:
            return "/api/v1/auth/apple"
        case .verifyToken:
            return "/api/v1/auth/verify"

        // Recipe
        case .generateRecipes:
            return "/api/v1/recipe/generateMultiple"
        case .generateSingleRecipe:
            return "/api/v1/recipe/generateSingle"
        case .calculateCalories:
            return "/api/v1/recipe/calculateCalories"

        // Profile
        case .getProfile(let userId), .updateProfile(let userId):
            return "/api/v1/users/\(userId)/profile"
        case .uploadAvatar(let userId):
            return "/api/v1/users/\(userId)/avatar"

        // Favorites
        case .getFavorites(let userId), .addFavorite(let userId):
            return "/api/v1/users/\(userId)/favorites"
        case .removeFavorite(let userId, let recipeId):
            return "/api/v1/users/\(userId)/favorites/\(recipeId)"
        case .getFavoritesByDate(let userId, let date):
            return "/api/v1/users/\(userId)/favorites/date/\(date)"

        // Preferences
        case .getPreferences(let userId), .updatePreferences(let userId):
            return "/api/v1/users/\(userId)/preferences"

        // Settings
        case .getSettings(let userId), .updateSettings(let userId):
            return "/api/v1/users/\(userId)/settings"

        // Subscription
        case .getPricingPlans:
            return "/api/v1/subscriptions/pricing-plans"
        case .createCheckoutSession:
            return "/api/v1/subscriptions/create-checkout-session"
        case .getSubscriptionStatus(let userId):
            return "/api/v1/subscriptions/\(userId)/status"
        case .cancelSubscription(let userId):
            return "/api/v1/subscriptions/\(userId)/cancel"
        case .getCustomerPortal(let userId):
            return "/api/v1/subscriptions/\(userId)/portal"

        // Support
        case .submitSupport:
            return "/api/v1/support"
        }
    }

    var method: String {
        switch self {
        // POST methods
        case .signUp, .signIn, .googleSignIn, .appleSignIn, .verifyToken,
             .generateRecipes, .generateSingleRecipe, .calculateCalories,
             .uploadAvatar, .addFavorite, .createCheckoutSession,
             .cancelSubscription, .submitSupport:
            return "POST"

        // PUT methods
        case .updateProfile, .updatePreferences, .updateSettings:
            return "PUT"

        // DELETE methods
        case .removeFavorite:
            return "DELETE"

        // GET methods
        default:
            return "GET"
        }
    }

    var queryItems: [URLQueryItem]? {
        switch self {
        case .getPricingPlans(let currency):
            return [URLQueryItem(name: "currency", value: currency)]
        default:
            return nil
        }
    }

    var url: URL {
        var components = URLComponents(url: APIEndpoint.baseURL.appendingPathComponent(path), resolvingAgainstBaseURL: true)!
        components.queryItems = queryItems
        return components.url!
    }

    func urlRequest(authToken: String? = nil) -> URLRequest {
        var request = URLRequest(url: url)
        request.httpMethod = method
        request.timeoutInterval = AppConfig.httpConnectTimeout

        // Add common headers
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("application/json", forHTTPHeaderField: "Accept")

        // Add auth header if token is available
        if let token = authToken {
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }

        return request
    }
}

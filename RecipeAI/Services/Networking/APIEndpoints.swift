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
    case guestRegister
    case guestConvert

    // MARK: - Recipe

    case generateRecipes
    case generateSingleRecipe
    case generateByText
    case calculateCalories

    // MARK: - User Profile

    case getProfile(userId: String)
    case updateProfile(userId: String)
    case uploadAvatar(userId: String)
    case deleteUser(userId: String)

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

    case getSubscriptionStatus(userId: String)
    case verifyAppleSubscription

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
        case .guestRegister:
            return "/api/v1/auth/guest/register"
        case .guestConvert:
            return "/api/v1/auth/guest/convert"

        // Recipe
        case .generateRecipes:
            return "/api/v1/recipe/generateMultiple"
        case .generateSingleRecipe:
            return "/api/v1/recipe/generateSingle"
        case .generateByText:
            return "/api/v1/recipe/generateByText"
        case .calculateCalories:
            return "/api/v1/recipe/calculateCalories"

        // Profile
        case .getProfile(let userId), .updateProfile(let userId):
            return "/api/v1/users/\(userId)/profile"
        case .uploadAvatar(let userId):
            return "/api/v1/users/\(userId)/avatar"
        case .deleteUser(let userId):
            return "/api/v1/users/\(userId)/complete"

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
        case .getSubscriptionStatus(let userId):
            return "/api/v1/subscriptions/\(userId)/status"
        case .verifyAppleSubscription:
            return "/api/v1/subscriptions/apple/verify"

        // Support
        case .submitSupport:
            return "/api/v1/support"
        }
    }

    var method: String {
        switch self {
        // POST methods
        case .signUp, .signIn, .googleSignIn, .appleSignIn, .verifyToken,
             .guestRegister, .guestConvert,
             .generateRecipes, .generateSingleRecipe, .generateByText, .calculateCalories,
             .uploadAvatar, .addFavorite, .verifyAppleSubscription, .submitSupport:
            return "POST"

        // PUT methods
        case .updateProfile, .updatePreferences, .updateSettings:
            return "PUT"

        // DELETE methods
        case .removeFavorite, .deleteUser:
            return "DELETE"

        // GET methods
        default:
            return "GET"
        }
    }

    var queryItems: [URLQueryItem]? {
        return nil
    }

    var url: URL {
        let baseURLString = AppConfig.apiBaseURL.trimmingCharacters(in: CharacterSet(charactersIn: "/"))
        let pathString = path.hasPrefix("/") ? path : "/\(path)"
        let fullURLString = baseURLString + pathString

        var components = URLComponents(string: fullURLString)!
        if let items = queryItems, !items.isEmpty {
            components.queryItems = items
        }
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

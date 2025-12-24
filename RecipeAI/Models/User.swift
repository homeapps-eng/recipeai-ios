import Foundation

// MARK: - User Profile

struct UserProfile: Codable {
    let userId: String
    let username: String
    let avatarUrl: String?
    let email: String?
}

// MARK: - Profile Response

struct ProfileResponse: Codable {
    let userId: String
    let username: String
    let avatarUrl: String?
    let email: String?
}

// MARK: - Update Profile Request

struct UpdateProfileRequest: Codable {
    let username: String
    let avatarUrl: String?
}

// MARK: - Avatar Upload Response

struct AvatarUploadResponse: Codable {
    let success: Bool
    let avatarUrl: String?
    let message: String?
}

// MARK: - User Settings

struct UserSettings: Codable {
    let userId: String
    var pushNotifications: Bool
    var recipeSuggestions: Bool
    var measurementUnits: String

    init(userId: String, pushNotifications: Bool = true, recipeSuggestions: Bool = true, measurementUnits: String = "Metric") {
        self.userId = userId
        self.pushNotifications = pushNotifications
        self.recipeSuggestions = recipeSuggestions
        self.measurementUnits = measurementUnits
    }
}

// MARK: - Update Settings Request

struct UpdateSettingsRequest: Codable {
    let pushNotifications: Bool
    let recipeSuggestions: Bool
    let measurementUnits: String
}

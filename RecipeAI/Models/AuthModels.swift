import Foundation

// MARK: - Auth Response

struct AuthResponse: Codable {
    let token: String
    let userId: String
    let email: String
    let name: String
    let provider: String
    let profilePicture: String?
}

// MARK: - Sign Up Request

struct SignUpRequest: Codable {
    let email: String
    let password: String
    let username: String
}

// MARK: - Sign In Request

struct SignInRequest: Codable {
    let email: String
    let password: String
}

// MARK: - Google Sign-In Request

struct GoogleSignInRequest: Codable {
    let idToken: String
}

// MARK: - Apple Sign-In Request

struct AppleSignInRequest: Codable {
    let identityToken: String
    let authorizationCode: String
}

// MARK: - Token Verify Request

struct VerifyTokenRequest: Codable {
    let token: String
}

// MARK: - Token Verify Response

struct TokenVerifyResponse: Codable {
    let valid: Bool
    let userId: String?
}

// MARK: - Guest Auth Models

struct GuestRegisterRequest: Codable {
    let deviceId: String
    let platform: String
}

struct GuestAuthResponse: Codable {
    let guestToken: String
    let userId: String
    let expiresAt: Int64
}

struct GuestConvertRequest: Codable {
    let guestDeviceId: String
    let email: String
    let password: String
    let username: String
}

struct GuestUser: Codable, Equatable {
    let id: String
    let deviceId: String
    let createdAt: Date

    init(id: String, deviceId: String, createdAt: Date = Date()) {
        self.id = id
        self.deviceId = deviceId
        self.createdAt = createdAt
    }
}

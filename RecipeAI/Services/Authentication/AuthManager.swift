import Foundation
import FirebaseAuth
import AuthenticationServices
import GoogleSignIn
import FirebaseCore
import Combine
import CryptoKit

@MainActor
final class AuthManager: ObservableObject {
    static let shared = AuthManager()

    @Published var currentUser: User?
    @Published var isAuthenticated = false
    @Published var isLoading = true
    @Published var error: AuthError?

    private var authStateListener: AuthStateDidChangeListenerHandle?
    private var currentNonce: String?

    private init() {
        setupAuthStateListener()
    }

    deinit {
        if let listener = authStateListener {
            Auth.auth().removeStateDidChangeListener(listener)
        }
    }

    // MARK: - Auth State Listener

    private func setupAuthStateListener() {
        authStateListener = Auth.auth().addStateDidChangeListener { [weak self] _, user in
            Task { @MainActor in
                self?.currentUser = user
                self?.isAuthenticated = user != nil
                self?.isLoading = false

                if let user = user {
                    // Refresh token and save user info on auth state change
                    try? await self?.refreshAndSaveToken(user: user)
                }
            }
        }
    }

    // MARK: - Email/Password Authentication

    func signIn(email: String, password: String) async throws {
        isLoading = true
        error = nil

        do {
            let result = try await Auth.auth().signIn(withEmail: email, password: password)
            try await refreshAndSaveToken(user: result.user)
            isLoading = false
        } catch {
            isLoading = false
            self.error = AuthError.from(error)
            throw self.error!
        }
    }

    func signUp(email: String, password: String, username: String) async throws {
        isLoading = true
        error = nil

        do {
            let result = try await Auth.auth().createUser(withEmail: email, password: password)

            // Update display name
            let changeRequest = result.user.createProfileChangeRequest()
            changeRequest.displayName = username
            try await changeRequest.commitChanges()

            // Send email verification
            try await result.user.sendEmailVerification()

            try await refreshAndSaveToken(user: result.user)
            isLoading = false
        } catch {
            isLoading = false
            self.error = AuthError.from(error)
            throw self.error!
        }
    }

    // MARK: - Google Sign-In

    func signInWithGoogle() async throws {
        guard let clientID = FirebaseApp.app()?.options.clientID else {
            throw AuthError.configurationError
        }

        guard let windowScene = await UIApplication.shared.connectedScenes.first as? UIWindowScene,
              let rootViewController = await windowScene.windows.first?.rootViewController else {
            throw AuthError.presentationError
        }

        isLoading = true
        error = nil

        do {
            let config = GIDConfiguration(clientID: clientID)
            GIDSignIn.sharedInstance.configuration = config

            let result = try await GIDSignIn.sharedInstance.signIn(withPresenting: rootViewController)

            guard let idToken = result.user.idToken?.tokenString else {
                throw AuthError.missingToken
            }

            // Check if email already exists with a different provider
            if let email = result.user.profile?.email {
                let providers = try await Auth.auth().fetchSignInMethods(forEmail: email)
                if !providers.isEmpty && !providers.contains("google.com") {
                    throw AuthError.accountExistsWithDifferentProvider(providers: providers)
                }
            }

            // Send ID token to backend
            let authResponse: AuthResponse = try await NetworkManager.shared.post(
                endpoint: .googleSignIn,
                body: GoogleSignInRequest(idToken: idToken)
            )

            // Sign in with custom token from backend
            let authResult = try await Auth.auth().signIn(withCustomToken: authResponse.token)

            // Save token
            let token = try await authResult.user.getIDToken()
            KeychainManager.shared.saveToken(token)

            // Save user info from backend response
            UserDefaultsManager.shared.saveUserInfo(
                userId: authResponse.userId,
                username: authResponse.name,
                email: authResponse.email,
                avatarUrl: authResponse.profilePicture
            )

            isLoading = false
        } catch let error as AuthError {
            isLoading = false
            self.error = error
            throw error
        } catch {
            isLoading = false
            self.error = AuthError.from(error)
            throw self.error!
        }
    }

    // MARK: - Apple Sign-In

    /// Generates a nonce for Apple Sign-In and returns the SHA256 hash
    func prepareAppleSignIn() -> String {
        let nonce = randomNonceString()
        currentNonce = nonce
        return sha256(nonce)
    }

    func handleAppleSignIn(credential: ASAuthorizationAppleIDCredential) async throws {
        guard let identityToken = credential.identityToken,
              let tokenString = String(data: identityToken, encoding: .utf8) else {
            throw AuthError.missingToken
        }

        guard let nonce = currentNonce else {
            throw AuthError.missingNonce
        }

        let authCode = credential.authorizationCode.flatMap { String(data: $0, encoding: .utf8) } ?? ""

        // Get email from credential (only available on first sign-in)
        let appleEmail = credential.email

        isLoading = true
        error = nil

        do {
            // Check if email already exists with a different provider
            if let email = appleEmail {
                let providers = try await Auth.auth().fetchSignInMethods(forEmail: email)
                if !providers.isEmpty && !providers.contains("apple.com") {
                    // Account exists with different provider - inform user
                    throw AuthError.accountExistsWithDifferentProvider(providers: providers)
                }
            }

            // Create Firebase credential with nonce
            let oAuthCredential = OAuthProvider.credential(
                providerID: AuthProviderID.apple,
                idToken: tokenString,
                rawNonce: nonce
            )

            // Sign in with Firebase
            let authResult = try await Auth.auth().signIn(with: oAuthCredential)

            // Send to backend for user creation/verification
            let authResponse: AuthResponse = try await NetworkManager.shared.post(
                endpoint: .appleSignIn,
                body: AppleSignInRequest(identityToken: tokenString, authorizationCode: authCode)
            )

            // Save token
            let token = try await authResult.user.getIDToken()
            KeychainManager.shared.saveToken(token)

            // Save user info from backend response
            UserDefaultsManager.shared.saveUserInfo(
                userId: authResponse.userId,
                username: authResponse.name,
                email: authResponse.email,
                avatarUrl: authResponse.profilePicture
            )

            currentNonce = nil
            isLoading = false
        } catch let error as AuthError {
            currentNonce = nil
            isLoading = false
            self.error = error
            throw error
        } catch {
            currentNonce = nil
            isLoading = false
            self.error = AuthError.from(error)
            throw self.error!
        }
    }

    // MARK: - Nonce Helpers

    private func randomNonceString(length: Int = 32) -> String {
        precondition(length > 0)
        var randomBytes = [UInt8](repeating: 0, count: length)
        let errorCode = SecRandomCopyBytes(kSecRandomDefault, randomBytes.count, &randomBytes)
        if errorCode != errSecSuccess {
            fatalError("Unable to generate nonce. SecRandomCopyBytes failed with OSStatus \(errorCode)")
        }

        let charset: [Character] = Array("0123456789ABCDEFGHIJKLMNOPQRSTUVXYZabcdefghijklmnopqrstuvwxyz-._")
        return String(randomBytes.map { charset[Int($0) % charset.count] })
    }

    private func sha256(_ input: String) -> String {
        let inputData = Data(input.utf8)
        let hashedData = SHA256.hash(data: inputData)
        return hashedData.compactMap { String(format: "%02x", $0) }.joined()
    }

    // MARK: - Password Reset

    func resetPassword(email: String) async throws {
        isLoading = true
        error = nil

        do {
            try await Auth.auth().sendPasswordReset(withEmail: email)
            isLoading = false
        } catch {
            isLoading = false
            self.error = AuthError.from(error)
            throw self.error!
        }
    }

    // MARK: - Sign Out

    func signOut() throws {
        do {
            try Auth.auth().signOut()
            GIDSignIn.sharedInstance.signOut()
            KeychainManager.shared.clearToken()
            UserDefaultsManager.shared.clearAll()
        } catch {
            self.error = AuthError.from(error)
            throw self.error!
        }
    }

    // MARK: - Delete Account

    func deleteAccount() async throws {
        guard let user = Auth.auth().currentUser else {
            throw AuthError.notAuthenticated
        }

        isLoading = true
        error = nil

        do {
            try await user.delete()
            KeychainManager.shared.clearToken()
            UserDefaultsManager.shared.clearAll()
            isLoading = false
        } catch {
            isLoading = false
            self.error = AuthError.from(error)
            throw self.error!
        }
    }

    // MARK: - Token Management

    private func refreshAndSaveToken(user: User) async throws {
        try await refreshToken(user: user)

        // Save user info
        let defaults = UserDefaultsManager.shared
        defaults.saveUserInfo(
            userId: user.uid,
            username: user.displayName ?? "User",
            email: user.email ?? "",
            avatarUrl: user.photoURL?.absoluteString
        )
    }

    private func refreshToken(user: User) async throws {
        let token = try await user.getIDToken()
        KeychainManager.shared.saveToken(token)
    }

    func forceRefreshToken() async throws {
        guard let user = Auth.auth().currentUser else {
            throw AuthError.notAuthenticated
        }
        let token = try await user.getIDToken(forcingRefresh: true)
        KeychainManager.shared.saveToken(token)
    }
}

// MARK: - Auth Error

enum AuthError: LocalizedError {
    case configurationError
    case presentationError
    case missingToken
    case missingNonce
    case notAuthenticated
    case invalidEmail
    case wrongPassword
    case emailAlreadyInUse
    case weakPassword
    case networkError
    case accountExistsWithDifferentProvider(providers: [String])
    case unknown(String)

    var errorDescription: String? {
        switch self {
        case .configurationError:
            return "Configuration error. Please try again."
        case .presentationError:
            return "Unable to present sign-in screen."
        case .missingToken:
            return "Authentication failed. Please try again."
        case .missingNonce:
            return "Authentication failed. Please try again."
        case .notAuthenticated:
            return "You are not signed in."
        case .invalidEmail:
            return "Invalid email address."
        case .wrongPassword:
            return "Incorrect password."
        case .emailAlreadyInUse:
            return "An account with this email already exists."
        case .weakPassword:
            return "Password is too weak. Please use at least 6 characters."
        case .networkError:
            return "Network error. Please check your connection."
        case .accountExistsWithDifferentProvider(let providers):
            let providerName = providers.first.map { formatProviderName($0) } ?? "another method"
            return "An account already exists with this email. Please sign in with \(providerName)."
        case .unknown(let message):
            return message
        }
    }

    private func formatProviderName(_ provider: String) -> String {
        switch provider {
        case "google.com": return "Google"
        case "apple.com": return "Apple"
        case "password": return "email and password"
        default: return provider
        }
    }

    static func from(_ error: Error) -> AuthError {
        if let authError = error as? AuthError {
            return authError
        }

        let nsError = error as NSError

        // Firebase Auth errors
        if nsError.domain == AuthErrorDomain {
            switch nsError.code {
            case AuthErrorCode.invalidEmail.rawValue:
                return .invalidEmail
            case AuthErrorCode.wrongPassword.rawValue:
                return .wrongPassword
            case AuthErrorCode.emailAlreadyInUse.rawValue:
                return .emailAlreadyInUse
            case AuthErrorCode.weakPassword.rawValue:
                return .weakPassword
            case AuthErrorCode.networkError.rawValue:
                return .networkError
            case AuthErrorCode.accountExistsWithDifferentCredential.rawValue:
                // Extract existing providers if available
                if let providers = nsError.userInfo[AuthErrorUserInfoNameKey] as? [String] {
                    return .accountExistsWithDifferentProvider(providers: providers)
                }
                return .accountExistsWithDifferentProvider(providers: [])
            default:
                return .unknown(error.localizedDescription)
            }
        }

        return .unknown(error.localizedDescription)
    }
}

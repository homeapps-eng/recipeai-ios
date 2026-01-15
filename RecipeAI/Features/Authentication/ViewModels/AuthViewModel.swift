import Foundation
import AuthenticationServices
import Combine

// MARK: - Sign In ViewModel

@MainActor
final class SignInViewModel: ObservableObject {
    @Published var email = ""
    @Published var password = ""
    @Published var isLoading = false
    @Published var showError = false
    @Published var errorMessage = ""
    @Published var showSignUp = false
    @Published var showForgotPassword = false

    var isFormValid: Bool {
        !email.isEmpty && !password.isEmpty && email.contains("@")
    }

    func signIn() async {
        isLoading = true

        do {
            try await AuthManager.shared.signIn(email: email, password: password)
            isLoading = false
        } catch {
            isLoading = false
            errorMessage = error.localizedDescription
            showError = true
        }
    }

    func signInWithGoogle() async {
        isLoading = true

        do {
            try await AuthManager.shared.signInWithGoogle()
            isLoading = false
        } catch {
            isLoading = false
            errorMessage = error.localizedDescription
            showError = true
        }
    }

    func handleAppleSignIn(result: Result<ASAuthorization, Error>) async {
        switch result {
        case .success(let authorization):
            if let appleCredential = authorization.credential as? ASAuthorizationAppleIDCredential {
                isLoading = true
                do {
                    try await AuthManager.shared.handleAppleSignIn(credential: appleCredential)
                    isLoading = false
                } catch {
                    isLoading = false
                    errorMessage = error.localizedDescription
                    showError = true
                }
            }
        case .failure(let error):
            // Ignore cancellation
            if (error as NSError).code != ASAuthorizationError.canceled.rawValue {
                errorMessage = error.localizedDescription
                showError = true
            }
        }
    }
}

// MARK: - Sign Up ViewModel

@MainActor
final class SignUpViewModel: ObservableObject {
    @Published var email = ""
    @Published var password = ""
    @Published var confirmPassword = ""
    @Published var username = ""
    @Published var isLoading = false
    @Published var showError = false
    @Published var errorMessage = ""

    var isFormValid: Bool {
        !email.isEmpty &&
        !password.isEmpty &&
        !username.isEmpty &&
        email.contains("@") &&
        password.count >= 6 &&
        password == confirmPassword
    }

    var passwordsMatch: Bool {
        password == confirmPassword || confirmPassword.isEmpty
    }

    var passwordStrengthMessage: String? {
        guard !password.isEmpty else { return nil }
        if password.count < 6 {
            return "Password must be at least 6 characters"
        }
        return nil
    }

    func signUp() async {
        isLoading = true

        do {
            try await AuthManager.shared.signUp(email: email, password: password, username: username)
            isLoading = false
        } catch {
            isLoading = false
            errorMessage = error.localizedDescription
            showError = true
        }
    }
}

// MARK: - Forgot Password ViewModel

@MainActor
final class ForgotPasswordViewModel: ObservableObject {
    @Published var email = ""
    @Published var isLoading = false
    @Published var showError = false
    @Published var errorMessage = ""
    @Published var showSuccess = false

    var isFormValid: Bool {
        !email.isEmpty && email.contains("@")
    }

    func resetPassword() async {
        isLoading = true

        do {
            try await AuthManager.shared.resetPassword(email: email)
            isLoading = false
            showSuccess = true
        } catch {
            isLoading = false
            errorMessage = error.localizedDescription
            showError = true
        }
    }
}

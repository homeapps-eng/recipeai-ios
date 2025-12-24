import SwiftUI
import AuthenticationServices

struct SignInView: View {
    @EnvironmentObject var authManager: AuthManager
    @StateObject private var viewModel = SignInViewModel()

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 24) {
                    // Logo
                    logoSection

                    // Email/Password Form
                    emailPasswordForm

                    // Sign In Button
                    signInButton

                    // Forgot Password
                    forgotPasswordLink

                    // Divider
                    dividerSection

                    // Social Sign In
                    socialSignInButtons

                    // Sign Up Link
                    signUpLink
                }
                .padding(.horizontal, 24)
                .padding(.vertical, 32)
            }
            .navigationDestination(isPresented: $viewModel.showSignUp) {
                SignUpView()
            }
            .navigationDestination(isPresented: $viewModel.showForgotPassword) {
                ForgotPasswordView()
            }
            .alert("Error", isPresented: $viewModel.showError) {
                Button("OK") {}
            } message: {
                Text(viewModel.errorMessage)
            }
            .loadingOverlay(isLoading: viewModel.isLoading)
        }
    }

    // MARK: - Logo Section

    private var logoSection: some View {
        VStack(spacing: 16) {
            Image(systemName: "fork.knife.circle.fill")
                .font(.system(size: 80))
                .foregroundColor(.brandGreen)

            Text("RecipeAI")
                .font(.appLargeTitle)
                .foregroundColor(.textPrimary)

            Text("Discover recipes from your photos")
                .font(.appSubheadline)
                .foregroundColor(.textSecondary)
        }
        .padding(.top, 40)
        .padding(.bottom, 20)
    }

    // MARK: - Email/Password Form

    private var emailPasswordForm: some View {
        VStack(spacing: 16) {
            TextField("Email", text: $viewModel.email)
                .textFieldStyle()
                .textContentType(.emailAddress)
                .keyboardType(.emailAddress)
                .autocapitalization(.none)
                .autocorrectionDisabled()

            SecureField("Password", text: $viewModel.password)
                .textFieldStyle()
                .textContentType(.password)
        }
    }

    // MARK: - Sign In Button

    private var signInButton: some View {
        Button {
            Task {
                await viewModel.signIn()
            }
        } label: {
            Text("Sign In")
        }
        .buttonStyle(.primary)
        .disabled(!viewModel.isFormValid)
        .opacity(viewModel.isFormValid ? 1 : 0.6)
    }

    // MARK: - Forgot Password

    private var forgotPasswordLink: some View {
        Button {
            viewModel.showForgotPassword = true
        } label: {
            Text("Forgot Password?")
                .font(.appSubheadline)
                .foregroundColor(.brandGreen)
        }
    }

    // MARK: - Divider

    private var dividerSection: some View {
        HStack {
            Rectangle()
                .frame(height: 1)
                .foregroundColor(.gray.opacity(0.3))

            Text("or")
                .font(.appFootnote)
                .foregroundColor(.textSecondary)
                .padding(.horizontal, 16)

            Rectangle()
                .frame(height: 1)
                .foregroundColor(.gray.opacity(0.3))
        }
    }

    // MARK: - Social Sign In

    private var socialSignInButtons: some View {
        VStack(spacing: 12) {
            // Google Sign In
            Button {
                Task {
                    await viewModel.signInWithGoogle()
                }
            } label: {
                HStack(spacing: 12) {
                    Image(systemName: "g.circle.fill")
                        .font(.title2)
                    Text("Continue with Google")
                }
            }
            .buttonStyle(.outline)

            // Apple Sign In
            SignInWithAppleButton(.signIn) { request in
                request.requestedScopes = [.email, .fullName]
            } onCompletion: { result in
                Task {
                    await viewModel.handleAppleSignIn(result: result)
                }
            }
            .signInWithAppleButtonStyle(.black)
            .frame(height: 50)
            .cornerRadius(12)
        }
    }

    // MARK: - Sign Up Link

    private var signUpLink: some View {
        HStack(spacing: 4) {
            Text("Don't have an account?")
                .font(.appSubheadline)
                .foregroundColor(.textSecondary)

            Button {
                viewModel.showSignUp = true
            } label: {
                Text("Sign Up")
                    .font(.poppinsSemiBold(size: 15))
                    .foregroundColor(.brandGreen)
            }
        }
        .padding(.top, 8)
    }
}

#Preview {
    SignInView()
        .environmentObject(AuthManager.shared)
}

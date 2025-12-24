import SwiftUI

struct SignUpView: View {
    @Environment(\.dismiss) private var dismiss
    @StateObject private var viewModel = SignUpViewModel()

    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                // Header
                headerSection

                // Form
                formSection

                // Sign Up Button
                signUpButton

                // Terms
                termsSection
            }
            .padding(.horizontal, 24)
            .padding(.vertical, 32)
        }
        .navigationTitle("Create Account")
        .navigationBarTitleDisplayMode(.inline)
        .alert("Error", isPresented: $viewModel.showError) {
            Button("OK") {}
        } message: {
            Text(viewModel.errorMessage)
        }
        .loadingOverlay(isLoading: viewModel.isLoading)
    }

    // MARK: - Header

    private var headerSection: some View {
        VStack(spacing: 8) {
            Text("Join RecipeAI")
                .font(.appTitle1)
                .foregroundColor(.textPrimary)

            Text("Create an account to save your favorite recipes")
                .font(.appSubheadline)
                .foregroundColor(.textSecondary)
                .multilineTextAlignment(.center)
        }
        .padding(.bottom, 16)
    }

    // MARK: - Form

    private var formSection: some View {
        VStack(spacing: 16) {
            TextField("Username", text: $viewModel.username)
                .textFieldStyle()
                .textContentType(.username)
                .autocapitalization(.none)
                .autocorrectionDisabled()

            TextField("Email", text: $viewModel.email)
                .textFieldStyle()
                .textContentType(.emailAddress)
                .keyboardType(.emailAddress)
                .autocapitalization(.none)
                .autocorrectionDisabled()

            VStack(alignment: .leading, spacing: 4) {
                SecureField("Password", text: $viewModel.password)
                    .textFieldStyle()
                    .textContentType(.newPassword)

                if let message = viewModel.passwordStrengthMessage {
                    Text(message)
                        .font(.appCaption1)
                        .foregroundColor(.statusOrange)
                }
            }

            VStack(alignment: .leading, spacing: 4) {
                SecureField("Confirm Password", text: $viewModel.confirmPassword)
                    .textFieldStyle()
                    .textContentType(.newPassword)

                if !viewModel.passwordsMatch {
                    Text("Passwords do not match")
                        .font(.appCaption1)
                        .foregroundColor(.statusRed)
                }
            }
        }
    }

    // MARK: - Sign Up Button

    private var signUpButton: some View {
        Button {
            Task {
                await viewModel.signUp()
            }
        } label: {
            Text("Create Account")
        }
        .buttonStyle(.primary)
        .disabled(!viewModel.isFormValid)
        .opacity(viewModel.isFormValid ? 1 : 0.6)
    }

    // MARK: - Terms

    private var termsSection: some View {
        VStack(spacing: 8) {
            Text("By creating an account, you agree to our")
                .font(.appCaption1)
                .foregroundColor(.textSecondary)

            HStack(spacing: 4) {
                Link("Terms of Service", destination: AppConfig.termsURL)
                    .font(.appCaption1)
                    .foregroundColor(.brandGreen)

                Text("and")
                    .font(.appCaption1)
                    .foregroundColor(.textSecondary)

                Link("Privacy Policy", destination: AppConfig.privacyURL)
                    .font(.appCaption1)
                    .foregroundColor(.brandGreen)
            }
        }
        .multilineTextAlignment(.center)
        .padding(.top, 8)
    }
}

#Preview {
    NavigationStack {
        SignUpView()
    }
}

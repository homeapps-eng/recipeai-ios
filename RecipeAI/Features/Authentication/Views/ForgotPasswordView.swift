import SwiftUI

struct ForgotPasswordView: View {
    @Environment(\.dismiss) private var dismiss
    @StateObject private var viewModel = ForgotPasswordViewModel()

    var body: some View {
        VStack(spacing: 24) {
            // Header
            headerSection

            // Email Field
            emailField

            // Reset Button
            resetButton

            Spacer()
        }
        .padding(.horizontal, 24)
        .padding(.top, 32)
        .navigationTitle("Reset Password")
        .navigationBarTitleDisplayMode(.inline)
        .alert("Error", isPresented: $viewModel.showError) {
            Button("OK") {}
        } message: {
            Text(viewModel.errorMessage)
        }
        .alert("Email Sent", isPresented: $viewModel.showSuccess) {
            Button("OK") {
                dismiss()
            }
        } message: {
            Text("Check your email for a link to reset your password.")
        }
        .loadingOverlay(isLoading: viewModel.isLoading)
    }

    // MARK: - Header

    private var headerSection: some View {
        VStack(spacing: 12) {
            Image(systemName: "envelope.circle.fill")
                .font(.system(size: 60))
                .foregroundColor(.brandGreen)

            Text("Forgot your password?")
                .font(.appTitle2)
                .foregroundColor(.textPrimary)

            Text("Enter your email address and we'll send you a link to reset your password.")
                .font(.appSubheadline)
                .foregroundColor(.textSecondary)
                .multilineTextAlignment(.center)
        }
        .padding(.bottom, 16)
    }

    // MARK: - Email Field

    private var emailField: some View {
        TextField("Email", text: $viewModel.email)
            .textFieldStyle()
            .textContentType(.emailAddress)
            .keyboardType(.emailAddress)
            .autocapitalization(.none)
            .autocorrectionDisabled()
    }

    // MARK: - Reset Button

    private var resetButton: some View {
        Button {
            Task {
                await viewModel.resetPassword()
            }
        } label: {
            Text("Send Reset Link")
        }
        .buttonStyle(.primary)
        .disabled(!viewModel.isFormValid)
        .opacity(viewModel.isFormValid ? 1 : 0.6)
    }
}

#Preview {
    NavigationStack {
        ForgotPasswordView()
    }
}

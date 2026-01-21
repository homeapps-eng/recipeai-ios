import SwiftUI
import AuthenticationServices
import Combine

struct GuestConversionView: View {
    @Environment(\.dismiss) private var dismiss
    @StateObject private var viewModel = GuestConversionViewModel()

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 24) {
                    // Header
                    headerSection

                    // Benefits
                    benefitsSection

                    // Email/Password Form
                    emailPasswordForm

                    // Create Account Button
                    createAccountButton

                    // Divider
                    dividerSection

                    // Social Sign In
                    socialSignInButtons
                }
                .padding(.horizontal, 24)
                .padding(.vertical, 32)
            }
            .navigationTitle("Create Account")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
            }
            .alert("Error", isPresented: $viewModel.showError) {
                Button("OK") {}
            } message: {
                Text(viewModel.errorMessage)
            }
            .loadingOverlay(isLoading: viewModel.isLoading)
            .onChange(of: viewModel.conversionSuccessful) { _, success in
                if success {
                    // Small delay to ensure auth state has propagated
                    Task {
                        try? await Task.sleep(nanoseconds: 300_000_000) // 0.3 seconds
                        dismiss()
                    }
                }
            }
        }
    }

    // MARK: - Header Section

    private var headerSection: some View {
        VStack(spacing: 8) {
            Image(systemName: "person.badge.plus")
                .font(.system(size: 60))
                .foregroundColor(.brandGreen)

            Text("Create Your Account")
                .font(.appTitle2)
                .foregroundColor(.textPrimary)

            Text("Save your recipes and sync across devices")
                .font(.appSubheadline)
                .foregroundColor(.textSecondary)
                .multilineTextAlignment(.center)
        }
        .padding(.top, 20)
    }

    // MARK: - Benefits Section

    private var benefitsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            benefitRow(icon: "heart.fill", text: "Save favorites to the cloud")
            benefitRow(icon: "arrow.triangle.2.circlepath", text: "Sync across all your devices")
            benefitRow(icon: "fork.knife", text: "Keep your food preferences")
            benefitRow(icon: "crown.fill", text: "Upgrade to Premium anytime")
        }
        .padding()
        .background(Color.backgroundSecondary)
        .cornerRadius(12)
    }

    private func benefitRow(icon: String, text: String) -> some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .foregroundColor(.brandGreen)
                .frame(width: 24)

            Text(text)
                .font(.appSubheadline)
                .foregroundColor(.textPrimary)
        }
    }

    // MARK: - Email/Password Form

    private var emailPasswordForm: some View {
        VStack(spacing: 16) {
            TextField("Username", text: $viewModel.username)
                .textFieldStyle()
                .textContentType(.username)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()

            TextField("Email", text: $viewModel.email)
                .textFieldStyle()
                .textContentType(.emailAddress)
                .keyboardType(.emailAddress)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()

            SecureField("Password", text: $viewModel.password)
                .textFieldStyle()
                .textContentType(.newPassword)

            SecureField("Confirm Password", text: $viewModel.confirmPassword)
                .textFieldStyle()
                .textContentType(.newPassword)

            if let error = viewModel.validationError {
                Text(error)
                    .font(.appCaption1)
                    .foregroundColor(.red)
            }
        }
    }

    // MARK: - Create Account Button

    private var createAccountButton: some View {
        Button {
            Task {
                await viewModel.createAccount()
            }
        } label: {
            Text("Create Account")
        }
        .buttonStyle(PrimaryButtonStyle())
        .disabled(!viewModel.isFormValid)
        .opacity(viewModel.isFormValid ? 1 : 0.6)
    }

    // MARK: - Divider

    private var dividerSection: some View {
        HStack {
            Rectangle()
                .frame(height: 1)
                .foregroundColor(.gray.opacity(0.3))

            Text("or continue with")
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
                    GoogleLogoView()
                        .frame(width: 20, height: 20)
                    Text("Continue with Google")
                }
            }
            .buttonStyle(OutlineButtonStyle())

            // Apple Sign In - Custom styled to match Google button
            Button {
                viewModel.triggerAppleSignIn()
            } label: {
                HStack(spacing: 12) {
                    Image(systemName: "apple.logo")
                        .font(.system(size: 20, weight: .medium))
                        .foregroundColor(.primary)
                    Text("Continue with Apple")
                }
            }
            .buttonStyle(OutlineButtonStyle())
        }
    }
}

// MARK: - Google Logo (duplicated from SignInView for accessibility)

private struct GoogleLogoView: View {
    var body: some View {
        GeometryReader { geometry in
            let size = min(geometry.size.width, geometry.size.height)

            Canvas { context, canvasSize in
                let center = CGPoint(x: canvasSize.width / 2, y: canvasSize.height / 2)
                let outerRadius = size / 2
                let innerRadius = outerRadius * 0.55
                let strokeWidth = outerRadius - innerRadius
                let midRadius = (outerRadius + innerRadius) / 2

                let blue = Color(red: 66/255, green: 133/255, blue: 244/255)
                let red = Color(red: 234/255, green: 67/255, blue: 53/255)
                let yellow = Color(red: 251/255, green: 188/255, blue: 5/255)
                let green = Color(red: 52/255, green: 168/255, blue: 83/255)

                var bluePath = Path()
                bluePath.addArc(center: center, radius: midRadius,
                               startAngle: .degrees(0), endAngle: .degrees(90),
                               clockwise: false)
                context.stroke(bluePath, with: .color(blue), style: StrokeStyle(lineWidth: strokeWidth, lineCap: .butt))

                var greenPath = Path()
                greenPath.addArc(center: center, radius: midRadius,
                                startAngle: .degrees(90), endAngle: .degrees(180),
                                clockwise: false)
                context.stroke(greenPath, with: .color(green), style: StrokeStyle(lineWidth: strokeWidth, lineCap: .butt))

                var yellowPath = Path()
                yellowPath.addArc(center: center, radius: midRadius,
                                 startAngle: .degrees(180), endAngle: .degrees(270),
                                 clockwise: false)
                context.stroke(yellowPath, with: .color(yellow), style: StrokeStyle(lineWidth: strokeWidth, lineCap: .butt))

                var redPath = Path()
                redPath.addArc(center: center, radius: midRadius,
                              startAngle: .degrees(270), endAngle: .degrees(315),
                              clockwise: false)
                context.stroke(redPath, with: .color(red), style: StrokeStyle(lineWidth: strokeWidth, lineCap: .butt))

                let barHeight = strokeWidth
                var barPath = Path()
                barPath.addRect(CGRect(
                    x: center.x,
                    y: center.y - barHeight/2,
                    width: outerRadius,
                    height: barHeight
                ))
                context.fill(barPath, with: .color(blue))
            }
        }
    }
}

// MARK: - ViewModel

@MainActor
final class GuestConversionViewModel: ObservableObject {
    @Published var username = ""
    @Published var email = ""
    @Published var password = ""
    @Published var confirmPassword = ""
    @Published var isLoading = false
    @Published var showError = false
    @Published var errorMessage = ""
    @Published var conversionSuccessful = false

    var isFormValid: Bool {
        !username.isEmpty &&
        !email.isEmpty &&
        !password.isEmpty &&
        email.contains("@") &&
        password.count >= 6 &&
        password == confirmPassword
    }

    var validationError: String? {
        if !password.isEmpty && password.count < 6 {
            return "Password must be at least 6 characters"
        }
        if !confirmPassword.isEmpty && password != confirmPassword {
            return "Passwords don't match"
        }
        return nil
    }

    func createAccount() async {
        isLoading = true

        do {
            try await AuthManager.shared.convertGuestToUser(
                email: email,
                password: password,
                username: username
            )
            isLoading = false
            conversionSuccessful = true
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
            conversionSuccessful = true
        } catch {
            isLoading = false
            errorMessage = error.localizedDescription
            showError = true
        }
    }

    func triggerAppleSignIn() {
        let request = ASAuthorizationAppleIDProvider().createRequest()
        request.requestedScopes = [.email, .fullName]
        request.nonce = AuthManager.shared.prepareAppleSignIn()

        let controller = ASAuthorizationController(authorizationRequests: [request])
        controller.delegate = AppleSignInDelegate.shared
        controller.presentationContextProvider = AppleSignInDelegate.shared

        // Set callback
        AppleSignInDelegate.shared.onComplete = { [weak self] result in
            Task { @MainActor in
                await self?.handleAppleSignIn(result: result)
            }
        }

        controller.performRequests()
    }

    func handleAppleSignIn(result: Result<ASAuthorization, Error>) async {
        switch result {
        case .success(let authorization):
            if let appleCredential = authorization.credential as? ASAuthorizationAppleIDCredential {
                isLoading = true
                do {
                    try await AuthManager.shared.handleAppleSignIn(credential: appleCredential)
                    isLoading = false
                    conversionSuccessful = true
                } catch {
                    isLoading = false
                    errorMessage = error.localizedDescription
                    showError = true
                }
            } else {
                errorMessage = "Invalid Apple credential"
                showError = true
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

#Preview {
    GuestConversionView()
}

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

                    // Terms
                    termsSection
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
                    GoogleLogo()
                        .frame(width: 20, height: 20)
                    Text("Continue with Google")
                }
            }
            .buttonStyle(.outline)

            // Apple Sign In
            SignInWithAppleButton(.signIn) { request in
                request.requestedScopes = [.email, .fullName]
                request.nonce = AuthManager.shared.prepareAppleSignIn()
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

    // MARK: - Terms

    private var termsSection: some View {
        VStack(spacing: 4) {
            Text("By continuing, you agree to our")
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
        .padding(.top, 16)
    }
}

// MARK: - Google Logo

struct GoogleLogo: View {
    var body: some View {
        GeometryReader { geometry in
            let size = min(geometry.size.width, geometry.size.height)

            Canvas { context, canvasSize in
                let center = CGPoint(x: canvasSize.width / 2, y: canvasSize.height / 2)
                let outerRadius = size / 2
                let innerRadius = outerRadius * 0.55
                let strokeWidth = outerRadius - innerRadius
                let midRadius = (outerRadius + innerRadius) / 2

                // Google brand colors
                let blue = Color(red: 66/255, green: 133/255, blue: 244/255)
                let red = Color(red: 234/255, green: 67/255, blue: 53/255)
                let yellow = Color(red: 251/255, green: 188/255, blue: 5/255)
                let green = Color(red: 52/255, green: 168/255, blue: 83/255)

                // Blue arc - bottom right (0° to 90°, where 0° is 3 o'clock)
                var bluePath = Path()
                bluePath.addArc(center: center, radius: midRadius,
                               startAngle: .degrees(0), endAngle: .degrees(90),
                               clockwise: false)
                context.stroke(bluePath, with: .color(blue), style: StrokeStyle(lineWidth: strokeWidth, lineCap: .butt))

                // Green arc - bottom left (90° to 180°)
                var greenPath = Path()
                greenPath.addArc(center: center, radius: midRadius,
                                startAngle: .degrees(90), endAngle: .degrees(180),
                                clockwise: false)
                context.stroke(greenPath, with: .color(green), style: StrokeStyle(lineWidth: strokeWidth, lineCap: .butt))

                // Yellow arc - top left (180° to 270°)
                var yellowPath = Path()
                yellowPath.addArc(center: center, radius: midRadius,
                                 startAngle: .degrees(180), endAngle: .degrees(270),
                                 clockwise: false)
                context.stroke(yellowPath, with: .color(yellow), style: StrokeStyle(lineWidth: strokeWidth, lineCap: .butt))

                // Red arc - top right, partial (270° to 315° - leaves gap for G opening)
                var redPath = Path()
                redPath.addArc(center: center, radius: midRadius,
                              startAngle: .degrees(270), endAngle: .degrees(315),
                              clockwise: false)
                context.stroke(redPath, with: .color(red), style: StrokeStyle(lineWidth: strokeWidth, lineCap: .butt))

                // Blue horizontal bar (the stem of the G)
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

#Preview {
    SignInView()
        .environmentObject(AuthManager.shared)
}

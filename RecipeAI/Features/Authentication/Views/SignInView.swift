import SwiftUI
import AuthenticationServices

struct SignInView: View {
    @EnvironmentObject var authManager: AuthManager
    @StateObject private var viewModel = SignInViewModel()
    @State private var showEmailSignIn = false

    var body: some View {
        NavigationStack {
            GeometryReader { geometry in
                VStack(spacing: 0) {
                    Spacer()
                        .frame(height: geometry.size.height * 0.08)

                    // Logo Section
                    logoSection

                    Spacer()
                        .frame(height: geometry.size.height * 0.06)

                    // Main Content
                    VStack(spacing: 16) {
                        // Social Sign In Buttons
                        socialSignInButtons

                        // Email Sign In Option
                        emailSignInButton

                        // Divider with Guest option
                        guestDivider

                        // Guest Mode Link
                        guestModeButton
                    }
                    .padding(.horizontal, 24)

                    Spacer()

                    // Bottom Section
                    VStack(spacing: 16) {
                        signUpLink
                        termsSection
                    }
                    .padding(.horizontal, 24)
                    .padding(.bottom, geometry.safeAreaInsets.bottom > 0 ? 8 : 24)
                }
            }
            .navigationDestination(isPresented: $viewModel.showSignUp) {
                SignUpView()
            }
            .navigationDestination(isPresented: $viewModel.showForgotPassword) {
                ForgotPasswordView()
            }
            .sheet(isPresented: $showEmailSignIn) {
                EmailSignInSheet(viewModel: viewModel)
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
        VStack(spacing: 12) {
            Image("logo")
                .resizable()
                .aspectRatio(contentMode: .fit)
                .frame(width: 100, height: 100)

            Text("RecipeAI")
                .font(.appLargeTitle)
                .foregroundColor(.textPrimary)

            Text("Discover recipes from your photos")
                .font(.appSubheadline)
                .foregroundColor(.textSecondary)
        }
    }

    // MARK: - Social Sign In Buttons

    private var socialSignInButtons: some View {
        VStack(spacing: 12) {
            // Apple Sign In
            Button {
                viewModel.triggerAppleSignIn()
            } label: {
                HStack(spacing: 12) {
                    Image(systemName: "apple.logo")
                        .font(.system(size: 20, weight: .semibold))
                    Text("Continue with Apple")
                        .font(.appHeadline)
                }
                .frame(maxWidth: .infinity)
                .frame(height: 52)
                .background(Color.primary)
                .foregroundColor(Color(UIColor.systemBackground))
                .cornerRadius(12)
            }

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
                        .font(.appHeadline)
                        .foregroundColor(.textPrimary)
                }
                .frame(maxWidth: .infinity)
                .frame(height: 52)
                .background(Color.backgroundSecondary)
                .cornerRadius(12)
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(Color.gray.opacity(0.3), lineWidth: 1)
                )
            }
        }
    }

    // MARK: - Email Sign In Button

    private var emailSignInButton: some View {
        Button {
            showEmailSignIn = true
        } label: {
            HStack(spacing: 12) {
                Image(systemName: "envelope.fill")
                    .font(.system(size: 18))
                Text("Continue with Email")
                    .font(.appHeadline)
            }
            .foregroundColor(.textPrimary)
            .frame(maxWidth: .infinity)
            .frame(height: 52)
            .background(Color.backgroundSecondary)
            .cornerRadius(12)
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(Color.gray.opacity(0.3), lineWidth: 1)
            )
        }
    }

    // MARK: - Guest Divider

    private var guestDivider: some View {
        HStack(spacing: 16) {
            Rectangle()
                .frame(height: 1)
                .foregroundColor(.gray.opacity(0.3))

            Text("or")
                .font(.appFootnote)
                .foregroundColor(.textSecondary)

            Rectangle()
                .frame(height: 1)
                .foregroundColor(.gray.opacity(0.3))
        }
        .padding(.vertical, 8)
    }

    // MARK: - Guest Mode Button

    private var guestModeButton: some View {
        Button {
            Task {
                await viewModel.continueAsGuest()
            }
        } label: {
            HStack(spacing: 8) {
                Image(systemName: "person.crop.circle.badge.clock")
                    .font(.system(size: 16))
                Text("Try without an account")
                    .font(.appSubheadline)
            }
            .foregroundColor(.textSecondary)
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
    }

    // MARK: - Terms

    private var termsSection: some View {
        VStack(spacing: 2) {
            Text("By continuing, you agree to our")
                .font(.appCaption1)
                .foregroundColor(.textTertiary)

            HStack(spacing: 4) {
                Link("Terms", destination: AppConfig.termsURL)
                    .font(.appCaption1)
                    .foregroundColor(.brandGreen)

                Text("and")
                    .font(.appCaption1)
                    .foregroundColor(.textTertiary)

                Link("Privacy Policy", destination: AppConfig.privacyURL)
                    .font(.appCaption1)
                    .foregroundColor(.brandGreen)
            }
        }
        .multilineTextAlignment(.center)
    }
}

// MARK: - Email Sign In Sheet

struct EmailSignInSheet: View {
    @Environment(\.dismiss) private var dismiss
    @ObservedObject var viewModel: SignInViewModel
    @FocusState private var focusedField: Field?

    enum Field {
        case email, password
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 24) {
                // Header
                VStack(spacing: 8) {
                    Image(systemName: "envelope.circle.fill")
                        .font(.system(size: 50))
                        .foregroundColor(.brandGreen)

                    Text("Sign in with Email")
                        .font(.appTitle2)
                        .foregroundColor(.textPrimary)
                }
                .padding(.top, 8)

                // Form
                VStack(spacing: 16) {
                    TextField("Email", text: $viewModel.email)
                        .textFieldStyle()
                        .textContentType(.emailAddress)
                        .keyboardType(.emailAddress)
                        .autocapitalization(.none)
                        .autocorrectionDisabled()
                        .focused($focusedField, equals: .email)

                    SecureField("Password", text: $viewModel.password)
                        .textFieldStyle()
                        .textContentType(.password)
                        .focused($focusedField, equals: .password)
                }

                // Sign In Button
                Button {
                    Task {
                        await viewModel.signIn()
                        if !viewModel.showError {
                            dismiss()
                        }
                    }
                } label: {
                    Text("Sign In")
                }
                .buttonStyle(.primary)
                .disabled(!viewModel.isFormValid)
                .opacity(viewModel.isFormValid ? 1 : 0.6)

                // Forgot Password
                Button {
                    dismiss()
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                        viewModel.showForgotPassword = true
                    }
                } label: {
                    Text("Forgot Password?")
                        .font(.appSubheadline)
                        .foregroundColor(.brandGreen)
                }

                Spacer()
            }
            .padding(.horizontal, 24)
            .padding(.top, 16)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button {
                        dismiss()
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 24))
                            .foregroundColor(.gray.opacity(0.6))
                    }
                }
            }
            .onAppear {
                focusedField = .email
            }
        }
        .presentationDetents([.medium])
        .presentationDragIndicator(.visible)
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

                // Blue arc
                var bluePath = Path()
                bluePath.addArc(center: center, radius: midRadius,
                               startAngle: .degrees(0), endAngle: .degrees(90),
                               clockwise: false)
                context.stroke(bluePath, with: .color(blue), style: StrokeStyle(lineWidth: strokeWidth, lineCap: .butt))

                // Green arc
                var greenPath = Path()
                greenPath.addArc(center: center, radius: midRadius,
                                startAngle: .degrees(90), endAngle: .degrees(180),
                                clockwise: false)
                context.stroke(greenPath, with: .color(green), style: StrokeStyle(lineWidth: strokeWidth, lineCap: .butt))

                // Yellow arc
                var yellowPath = Path()
                yellowPath.addArc(center: center, radius: midRadius,
                                 startAngle: .degrees(180), endAngle: .degrees(270),
                                 clockwise: false)
                context.stroke(yellowPath, with: .color(yellow), style: StrokeStyle(lineWidth: strokeWidth, lineCap: .butt))

                // Red arc
                var redPath = Path()
                redPath.addArc(center: center, radius: midRadius,
                              startAngle: .degrees(270), endAngle: .degrees(315),
                              clockwise: false)
                context.stroke(redPath, with: .color(red), style: StrokeStyle(lineWidth: strokeWidth, lineCap: .butt))

                // Blue horizontal bar
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

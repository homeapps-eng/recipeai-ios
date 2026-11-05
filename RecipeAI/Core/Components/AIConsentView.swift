import SwiftUI

/// Asks permission before photos, requests and food preferences go to the AI
/// service (App Review guideline 5.1.2(i)). See `AIConsent`.
struct AIConsentView: View {
    let onAllow: () -> Void
    let onDecline: () -> Void

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    Image(systemName: "sparkles")
                        .font(.system(size: 44))
                        .foregroundColor(.brandGreen)
                        .frame(maxWidth: .infinity)

                    Text("Before you use AI features")
                        .font(.appTitle2)
                        .frame(maxWidth: .infinity)
                        .multilineTextAlignment(.center)

                    Text("To create recipes and estimate calories, RecipeAI sends this to \(AIConsent.providerName), Google's AI service:")
                        .font(.appBody)

                    VStack(alignment: .leading, spacing: 12) {
                        point("camera.fill", "Photos you take or choose")
                        point("text.bubble.fill", "What you type or say, as text")
                        point("leaf.fill", "Your food preferences, including diets and allergies")
                    }

                    Text("Google processes it to create your results. You can turn this off anytime in Settings.")
                        .font(.appSubheadline)
                        .foregroundColor(.textSecondary)

                    Link("Read our Privacy Policy", destination: AppConfig.privacyURL)
                        .font(.appSubheadline)
                }
                .padding(24)
            }
            .safeAreaInset(edge: .bottom) {
                VStack(spacing: 12) {
                    Button("Allow") { onAllow() }
                        .primaryButtonStyle()
                    Button("Not now") { onDecline() }
                        .font(.appButton)
                        .foregroundColor(.textSecondary)
                }
                .padding(24)
                .background(Color.backgroundPrimary)
            }
        }
        .interactiveDismissDisabled()
    }

    private func point(_ symbol: String, _ text: String) -> some View {
        Label {
            Text(text).font(.appBody)
        } icon: {
            Image(systemName: symbol).foregroundColor(.brandGreen)
        }
    }
}

#Preview {
    AIConsentView(onAllow: {}, onDecline: {})
}

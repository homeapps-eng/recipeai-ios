import SwiftUI

struct SupportView: View {
    @EnvironmentObject var userDefaults: UserDefaultsManager
    @State private var message = ""
    @State private var isLoading = false
    @State private var showSuccess = false
    @State private var showError = false
    @State private var errorMessage = ""

    var isValid: Bool {
        message.trimmingCharacters(in: .whitespacesAndNewlines).count >= 10
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                // Header
                headerSection

                // Contact Form
                formSection

                // Send Button
                sendButton

                // FAQ Section
                faqSection
            }
            .padding()
        }
        .navigationTitle("Help & Support")
        .navigationBarTitleDisplayMode(.inline)
        .alert("Message Sent", isPresented: $showSuccess) {
            Button("OK") {
                message = ""
            }
        } message: {
            Text("We've received your message and will get back to you soon.")
        }
        .alert("Error", isPresented: $showError) {
            Button("OK") {}
        } message: {
            Text(errorMessage)
        }
        .loadingOverlay(isLoading: isLoading)
    }

    // MARK: - Header Section

    private var headerSection: some View {
        VStack(spacing: 12) {
            Image(systemName: "questionmark.circle.fill")
                .font(.system(size: 50))
                .foregroundColor(.brandGreen)

            Text("How can we help?")
                .font(.appTitle2)
                .foregroundColor(.textPrimary)

            Text("Send us a message and we'll get back to you as soon as possible.")
                .font(.appSubheadline)
                .foregroundColor(.textSecondary)
                .multilineTextAlignment(.center)
        }
    }

    // MARK: - Form Section

    private var formSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Your Email")
                .font(.appSubheadline)
                .foregroundColor(.textSecondary)

            Text(userDefaults.userEmail ?? "")
                .font(.appBody)
                .foregroundColor(.textPrimary)
                .padding()
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Color.backgroundSecondary)
                .cornerRadius(12)

            Text("Message")
                .font(.appSubheadline)
                .foregroundColor(.textSecondary)
                .padding(.top, 8)

            TextEditor(text: $message)
                .font(.appBody)
                .frame(minHeight: 150)
                .padding(8)
                .background(Color.backgroundSecondary)
                .cornerRadius(12)
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(Color.gray.opacity(0.3), lineWidth: 1)
                )

            Text("\(message.count)/500 characters")
                .font(.appCaption1)
                .foregroundColor(.textSecondary)
                .frame(maxWidth: .infinity, alignment: .trailing)
        }
    }

    // MARK: - Send Button

    private var sendButton: some View {
        Button {
            sendMessage()
        } label: {
            Text("Send Message")
        }
        .buttonStyle(.primary)
        .disabled(!isValid || isLoading)
        .opacity(isValid ? 1 : 0.6)
    }

    // MARK: - FAQ Section

    private var faqSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Frequently Asked Questions")
                .font(.appTitle3)
                .foregroundColor(.textPrimary)

            faqItem(
                question: "How does recipe generation work?",
                answer: "Take a photo of your ingredients, and our AI will analyze the image and generate recipe suggestions based on what it detects."
            )

            faqItem(
                question: "How accurate is calorie calculation?",
                answer: "Our AI provides estimates based on visual analysis. For precise nutritional information, we recommend consulting a nutrition label or professional."
            )

            faqItem(
                question: "How do I cancel my subscription?",
                answer: "Go to Profile > Subscription > Manage Subscription. You can cancel anytime and retain access until the end of your billing period."
            )

            faqItem(
                question: "Can I use the app offline?",
                answer: "Recipe generation and calorie calculation require an internet connection. However, your saved favorites are available offline."
            )
        }
        .padding(.top, 16)
    }

    private func faqItem(question: String, answer: String) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(question)
                .font(.appHeadline)
                .foregroundColor(.textPrimary)

            Text(answer)
                .font(.appSubheadline)
                .foregroundColor(.textSecondary)
        }
        .padding()
        .background(Color.backgroundSecondary)
        .cornerRadius(12)
    }

    // MARK: - Actions

    private func sendMessage() {
        guard let email = userDefaults.userEmail else { return }

        isLoading = true

        Task {
            do {
                let request = SupportRequest(email: email, message: message)
                let _: SupportResponse = try await NetworkManager.shared.post(
                    endpoint: .submitSupport,
                    body: request
                )
                isLoading = false
                showSuccess = true
            } catch {
                isLoading = false
                errorMessage = error.localizedDescription
                showError = true
            }
        }
    }
}

#Preview {
    NavigationStack {
        SupportView()
            .environmentObject(UserDefaultsManager.shared)
    }
}

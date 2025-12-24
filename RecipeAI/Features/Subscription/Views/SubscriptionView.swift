import SwiftUI
import SafariServices

struct SubscriptionView: View {
    @EnvironmentObject var userDefaults: UserDefaultsManager
    @StateObject private var subscriptionManager = SubscriptionManager.shared
    @State private var selectedPlan: PricingPlan?
    @State private var showSafari = false
    @State private var safariURL: URL?
    @State private var showCancelConfirmation = false
    @State private var showError = false
    @State private var errorMessage = ""

    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                // Header
                headerSection

                // Status (if premium)
                if subscriptionManager.isPremium {
                    statusSection
                } else {
                    // Features
                    featuresSection

                    // Plans
                    plansSection

                    // Subscribe Button
                    subscribeButton
                }

                // Manage Subscription
                if subscriptionManager.isPremium {
                    manageSection
                }
            }
            .padding()
        }
        .navigationTitle("Subscription")
        .navigationBarTitleDisplayMode(.inline)
        .task {
            await subscriptionManager.fetchPricingPlans()
            if let userId = userDefaults.userId {
                await subscriptionManager.fetchStatus(userId: userId, forceRefresh: true)
            }
        }
        .sheet(isPresented: $showSafari) {
            if let url = safariURL {
                SafariView(url: url)
            }
        }
        .alert("Error", isPresented: $showError) {
            Button("OK") {}
        } message: {
            Text(errorMessage)
        }
        .alert("Cancel Subscription", isPresented: $showCancelConfirmation) {
            Button("Keep Subscription", role: .cancel) {}
            Button("Cancel Subscription", role: .destructive) {
                cancelSubscription()
            }
        } message: {
            Text("Your subscription will remain active until the end of your billing period.")
        }
        .loadingOverlay(isLoading: subscriptionManager.isLoading)
    }

    // MARK: - Header Section

    private var headerSection: some View {
        VStack(spacing: 12) {
            Image(systemName: "crown.fill")
                .font(.system(size: 50))
                .foregroundColor(.yellow)

            if subscriptionManager.isPremium {
                Text("Premium Member")
                    .font(.appTitle1)
                    .foregroundColor(.textPrimary)
            } else {
                Text("Go Premium")
                    .font(.appTitle1)
                    .foregroundColor(.textPrimary)

                Text("Unlock unlimited recipes and features")
                    .font(.appSubheadline)
                    .foregroundColor(.textSecondary)
            }
        }
        .padding(.top, 16)
    }

    // MARK: - Status Section

    private var statusSection: some View {
        VStack(spacing: 16) {
            if let status = subscriptionManager.subscriptionStatus {
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Plan")
                            .font(.appCaption1)
                            .foregroundColor(.textSecondary)
                        Text(status.planName ?? "Premium")
                            .font(.appHeadline)
                    }

                    Spacer()

                    VStack(alignment: .trailing, spacing: 4) {
                        Text("Status")
                            .font(.appCaption1)
                            .foregroundColor(.textSecondary)
                        Text(status.statusType.displayName)
                            .font(.appHeadline)
                            .foregroundColor(Color(hex: status.statusType.color))
                    }
                }

                if let endDate = status.periodEndDate {
                    HStack {
                        Text(status.cancelAtPeriodEnd == true ? "Expires on" : "Renews on")
                            .font(.appSubheadline)
                            .foregroundColor(.textSecondary)

                        Spacer()

                        Text(endDate, style: .date)
                            .font(.appSubheadline)
                    }
                }
            }
        }
        .padding()
        .background(Color.backgroundSecondary)
        .cornerRadius(12)
    }

    // MARK: - Features Section

    private var featuresSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            featureRow(icon: "infinity", text: "Unlimited recipe generation")
            featureRow(icon: "photo.on.rectangle", text: "Unlimited photo analysis")
            featureRow(icon: "heart.fill", text: "Unlimited favorites")
            featureRow(icon: "xmark.circle", text: "No ads")
            featureRow(icon: "sparkles", text: "Priority support")
        }
        .padding()
        .background(Color.backgroundSecondary)
        .cornerRadius(12)
    }

    private func featureRow(icon: String, text: String) -> some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.body)
                .foregroundColor(.brandGreen)
                .frame(width: 24)

            Text(text)
                .font(.appBody)
                .foregroundColor(.textPrimary)

            Spacer()
        }
    }

    // MARK: - Plans Section

    private var plansSection: some View {
        VStack(spacing: 12) {
            ForEach(subscriptionManager.pricingPlans) { plan in
                planCard(plan)
            }
        }
    }

    private func planCard(_ plan: PricingPlan) -> some View {
        let isSelected = selectedPlan?.priceId == plan.priceId

        return Button {
            selectedPlan = plan
        } label: {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        Text(plan.name)
                            .font(.appHeadline)
                            .foregroundColor(.textPrimary)

                        if plan.isAnnual {
                            Text("Best Value")
                                .font(.appCaption2)
                                .foregroundColor(.white)
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(Color.brandGreen)
                                .cornerRadius(4)
                        }
                    }

                    Text(plan.interval == "month" ? "Billed monthly" : "Billed annually")
                        .font(.appCaption1)
                        .foregroundColor(.textSecondary)
                }

                Spacer()

                Text(plan.displayPrice)
                    .font(.appTitle3)
                    .foregroundColor(isSelected ? .brandGreen : .textPrimary)
            }
            .padding()
            .background(isSelected ? Color.brandGreenLight : Color.backgroundSecondary)
            .cornerRadius(12)
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(isSelected ? Color.brandGreen : Color.clear, lineWidth: 2)
            )
        }
        .buttonStyle(.plain)
    }

    // MARK: - Subscribe Button

    private var subscribeButton: some View {
        Button {
            subscribe()
        } label: {
            Text("Subscribe Now")
        }
        .buttonStyle(.primary)
        .disabled(selectedPlan == nil)
        .opacity(selectedPlan == nil ? 0.6 : 1)
    }

    // MARK: - Manage Section

    private var manageSection: some View {
        VStack(spacing: 12) {
            Button {
                openCustomerPortal()
            } label: {
                Text("Manage Subscription")
            }
            .buttonStyle(.secondary)

            if subscriptionManager.subscriptionStatus?.cancelAtPeriodEnd != true {
                Button {
                    showCancelConfirmation = true
                } label: {
                    Text("Cancel Subscription")
                        .foregroundColor(.red)
                }
            }
        }
    }

    // MARK: - Actions

    private func subscribe() {
        guard let plan = selectedPlan,
              let userId = userDefaults.userId else { return }

        Task {
            do {
                let url = try await subscriptionManager.createCheckoutSession(
                    userId: userId,
                    priceId: plan.priceId
                )
                safariURL = url
                showSafari = true
            } catch {
                errorMessage = error.localizedDescription
                showError = true
            }
        }
    }

    private func openCustomerPortal() {
        guard let userId = userDefaults.userId else { return }

        Task {
            do {
                let url = try await subscriptionManager.getCustomerPortalURL(userId: userId)
                safariURL = url
                showSafari = true
            } catch {
                errorMessage = error.localizedDescription
                showError = true
            }
        }
    }

    private func cancelSubscription() {
        guard let userId = userDefaults.userId else { return }

        Task {
            do {
                try await subscriptionManager.cancelSubscription(userId: userId)
            } catch {
                errorMessage = error.localizedDescription
                showError = true
            }
        }
    }
}

// MARK: - Safari View

struct SafariView: UIViewControllerRepresentable {
    let url: URL

    func makeUIViewController(context: Context) -> SFSafariViewController {
        SFSafariViewController(url: url)
    }

    func updateUIViewController(_ uiViewController: SFSafariViewController, context: Context) {}
}

#Preview {
    NavigationStack {
        SubscriptionView()
            .environmentObject(UserDefaultsManager.shared)
    }
}

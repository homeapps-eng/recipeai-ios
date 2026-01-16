import SwiftUI
import SafariServices

struct SubscriptionView: View {
    @EnvironmentObject var userDefaults: UserDefaultsManager
    @ObservedObject private var subscriptionManager = SubscriptionManager.shared
    @State private var selectedPlan: PricingPlan?
    @State private var safariURL: IdentifiableURL?
    @State private var showCancelConfirmation = false
    @State private var showError = false
    @State private var errorMessage = ""
    @State private var isRefreshingAfterPayment = false

    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                // Header
                headerSection

                // Show different content based on subscription status
                if subscriptionManager.subscriptionStatus?.isPremium == true {
                    // Premium user: show status and manage options
                    statusSection
                    manageSection
                } else {
                    // Non-premium: show features, plans, and subscribe button
                    featuresSection
                    plansSection
                    subscribeButton
                }
            }
            .padding()
        }
        .navigationTitle("Subscription")
        .navigationBarTitleDisplayMode(.inline)
        .task {
            await loadData()
        }
        .onReceive(NotificationCenter.default.publisher(for: .subscriptionPaymentSuccess)) { _ in
            safariURL = nil
            Task {
                await handlePaymentSuccess()
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: .subscriptionPaymentCancelled)) { _ in
            safariURL = nil
        }
        .sheet(item: $safariURL) { item in
            SafariView(url: item.url)
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
        .loadingOverlay(isLoading: subscriptionManager.isLoading || isRefreshingAfterPayment)
    }

    // MARK: - Load Data

    private func loadData() async {
        // Fetch pricing plans
        await subscriptionManager.fetchPricingPlans()

        // Auto-select annual plan (best value) if none selected
        if selectedPlan == nil {
            selectedPlan = subscriptionManager.pricingPlans.first { $0.isAnnual }
                ?? subscriptionManager.pricingPlans.first
        }

        // Fetch subscription status
        if let userId = userDefaults.userId {
            await subscriptionManager.fetchStatus(userId: userId, forceRefresh: true)
        }
    }

    // MARK: - Header Section

    private var headerSection: some View {
        VStack(spacing: 12) {
            Image(systemName: "crown.fill")
                .font(.system(size: 50))
                .foregroundColor(.yellow)

            if subscriptionManager.subscriptionStatus?.isPremium == true {
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

    // MARK: - Status Section (for Premium users)

    private var statusSection: some View {
        VStack(spacing: 16) {
            if let status = subscriptionManager.subscriptionStatus {
                // Plan and Status row
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Plan")
                            .font(.appCaption1)
                            .foregroundColor(.textSecondary)
                        Text(status.planName ?? "Premium")
                            .font(.appHeadline)
                            .foregroundColor(.textPrimary)
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

                // Renewal/Expiration date
                if let endDate = status.periodEndDate {
                    HStack {
                        Text(status.cancelAtPeriodEnd == true ? "Expires on" : "Renews on")
                            .font(.appSubheadline)
                            .foregroundColor(.textSecondary)

                        Spacer()

                        Text(endDate, style: .date)
                            .font(.appSubheadline)
                            .foregroundColor(.textPrimary)
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
                Button(role: .destructive) {
                    showCancelConfirmation = true
                } label: {
                    Text("Cancel Subscription")
                        .font(.appButton)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                }
                .buttonStyle(.bordered)
                .tint(.red)
            }
        }
    }

    // MARK: - Actions

    private func subscribe() {
        guard let plan = selectedPlan else {
            errorMessage = "Please select a plan"
            showError = true
            return
        }

        guard let userId = userDefaults.userId else {
            errorMessage = "Please sign in to subscribe"
            showError = true
            return
        }

        Task {
            do {
                let url = try await subscriptionManager.createCheckoutSession(
                    userId: userId,
                    priceId: plan.priceId
                )
                safariURL = IdentifiableURL(url: url)
            } catch {
                errorMessage = "Unable to start checkout. Please try again."
                showError = true
            }
        }
    }

    private func handlePaymentSuccess() async {
        guard let userId = userDefaults.userId else { return }

        isRefreshingAfterPayment = true

        // Sync subscription from Stripe with retry
        for attempt in 1...5 {
            // Wait before each attempt (webhook may need time to process)
            try? await Task.sleep(nanoseconds: UInt64(attempt) * 1_500_000_000)

            // Try to sync from Stripe
            do {
                try await subscriptionManager.syncSubscription(userId: userId)
            } catch {
                print("Sync attempt \(attempt) failed: \(error)")
                // Fallback: just fetch status
                await subscriptionManager.fetchStatus(userId: userId, forceRefresh: true)
            }

            // If premium, we're done
            if subscriptionManager.subscriptionStatus?.isPremium == true {
                isRefreshingAfterPayment = false
                return
            }
        }

        isRefreshingAfterPayment = false

        // If still not premium after retries, show message
        if subscriptionManager.subscriptionStatus?.isPremium != true {
            errorMessage = "Subscription is being processed. Please wait a moment and check again."
            showError = true
        }
    }

    private func openCustomerPortal() {
        guard let userId = userDefaults.userId else {
            errorMessage = "Unable to load subscription settings"
            showError = true
            return
        }

        Task {
            do {
                let url = try await subscriptionManager.getCustomerPortalURL(userId: userId)
                safariURL = IdentifiableURL(url: url)
            } catch {
                errorMessage = "Unable to open subscription settings"
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
                errorMessage = "Unable to cancel subscription. Please try again."
                showError = true
            }
        }
    }
}

// MARK: - Identifiable URL Wrapper

struct IdentifiableURL: Identifiable {
    let id = UUID()
    let url: URL
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

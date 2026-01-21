import SwiftUI
import StoreKit

struct SubscriptionView: View {
    @EnvironmentObject var userDefaults: UserDefaultsManager
    @ObservedObject private var storeKit = StoreKitManager.shared
    @State private var selectedProduct: Product?
    @State private var showError = false
    @State private var errorMessage = ""
    @State private var showSuccess = false

    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                // Header
                headerSection

                // Show different content based on subscription status
                if storeKit.isPremium {
                    // Premium user: show status
                    statusSection
                    manageSection
                } else {
                    // Non-premium: show features, plans, and subscribe button
                    featuresSection
                    plansSection
                    subscribeButton
                    restoreButton
                }
            }
            .padding()
        }
        .navigationTitle("Subscription")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button {
                    Task {
                        await refreshStatus()
                    }
                } label: {
                    Image(systemName: "arrow.clockwise")
                }
            }
        }
        .task {
            await refreshStatus()

            // Auto-select annual product
            if selectedProduct == nil {
                selectedProduct = storeKit.annualProduct ?? storeKit.monthlyProduct
            }
        }
        .alert("Error", isPresented: $showError) {
            Button("OK") {}
        } message: {
            Text(errorMessage)
        }
        .alert("Success", isPresented: $showSuccess) {
            Button("OK") {}
        } message: {
            Text("You are now a Premium member!")
        }
        .loadingOverlay(isLoading: storeKit.isLoading)
    }

    // MARK: - Header Section

    private var headerSection: some View {
        VStack(spacing: 12) {
            Image(systemName: "crown.fill")
                .font(.system(size: 50))
                .foregroundColor(.yellow)

            if storeKit.isPremium {
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
            // Plan and Status row
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Plan")
                        .font(.appCaption1)
                        .foregroundColor(.textSecondary)
                    Text(planDisplayName)
                        .font(.appHeadline)
                        .foregroundColor(.textPrimary)
                }

                Spacer()

                VStack(alignment: .trailing, spacing: 4) {
                    Text("Status")
                        .font(.appCaption1)
                        .foregroundColor(.textSecondary)
                    Text(statusDisplayName)
                        .font(.appHeadline)
                        .foregroundColor(statusColor)
                }
            }

            // Expiration/Renewal date
            if let date = displayDate {
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(isExpiring ? "Expires on" : "Renews on")
                            .font(.appCaption1)
                            .foregroundColor(.textSecondary)
                        Text(date, style: .date)
                            .font(.appHeadline)
                            .foregroundColor(.textPrimary)
                    }

                    Spacer()
                }
            }

            // Show message if subscription is expiring
            if isExpiring {
                HStack {
                    Image(systemName: "info.circle.fill")
                        .foregroundColor(.orange)
                    Text("Your subscription will not renew. You'll lose premium access after the expiration date.")
                        .font(.appCaption1)
                        .foregroundColor(.textSecondary)
                }
                .padding(.top, 4)
            }

            #if DEBUG
            // Debug: Show subscription info
            VStack(spacing: 4) {
                Text("DEBUG: \(storeKit.purchasedSubscriptions.count) local subscription(s)")
                    .font(.caption)
                    .foregroundColor(.gray)
                if let status = storeKit.subscriptionStatus {
                    Text("Backend: isActive=\(status.isActive), autoRenew=\(status.autoRenewStatus ?? true)")
                        .font(.caption)
                        .foregroundColor(.gray)
                }

                Button("DEBUG: Clear Local Cache") {
                    storeKit.purchasedSubscriptions = []
                    storeKit.subscriptionExpirationDate = nil
                    UserDefaultsManager.shared.isPremium = false
                }
                .font(.caption)
                .foregroundColor(.red)
            }
            .padding(.top, 8)
            #endif
        }
        .padding()
        .background(Color.backgroundSecondary)
        .cornerRadius(12)
    }

    // MARK: - Status Helpers

    private var planDisplayName: String {
        // Prefer backend status, fallback to local
        if let status = storeKit.subscriptionStatus, let planName = status.planName {
            return planName
        }
        return storeKit.purchasedSubscriptions.first?.displayName ?? "Premium"
    }

    private var isExpiring: Bool {
        // Check if user cancelled subscription
        if let status = storeKit.subscriptionStatus {
            return status.statusType == .expiring
        }
        return false
    }

    private var statusDisplayName: String {
        if let status = storeKit.subscriptionStatus {
            return status.statusType.displayName
        }
        return "Active"
    }

    private var statusColor: Color {
        if let status = storeKit.subscriptionStatus {
            switch status.statusType {
            case .active: return .green
            case .expiring: return .orange
            case .inactive: return .red
            }
        }
        return .green
    }

    private var displayDate: Date? {
        // Prefer backend date
        if let status = storeKit.subscriptionStatus, let date = status.periodEndDate {
            return date
        }
        return storeKit.subscriptionExpirationDate
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
            ForEach(storeKit.products) { product in
                planCard(product)
            }
        }
    }

    private func planCard(_ product: Product) -> some View {
        let isSelected = selectedProduct?.id == product.id
        let isAnnual = product.id.contains("annual")

        return Button {
            selectedProduct = product
        } label: {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        Text(product.displayName)
                            .font(.appHeadline)
                            .foregroundColor(.textPrimary)

                        if isAnnual {
                            Text("Best Value")
                                .font(.appCaption2)
                                .foregroundColor(.white)
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(Color.brandGreen)
                                .cornerRadius(4)
                        }
                    }

                    Text(product.description)
                        .font(.appCaption1)
                        .foregroundColor(.textSecondary)
                }

                Spacer()

                Text(product.displayPrice)
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
            purchase()
        } label: {
            Text("Subscribe Now")
        }
        .buttonStyle(.primary)
        .disabled(selectedProduct == nil)
        .opacity(selectedProduct == nil ? 0.6 : 1)
    }

    // MARK: - Restore Button

    private var restoreButton: some View {
        Button {
            Task {
                await storeKit.restorePurchases()
                if storeKit.isPremium {
                    showSuccess = true
                }
            }
        } label: {
            Text("Restore Purchases")
                .font(.appSubheadline)
                .foregroundColor(.brandGreen)
        }
    }

    // MARK: - Manage Section

    private var manageSection: some View {
        VStack(spacing: 12) {
            Button {
                openSubscriptionManagement()
            } label: {
                Text("Manage Subscription")
            }
            .buttonStyle(.secondary)
        }
    }

    // MARK: - Actions

    private func purchase() {
        guard let product = selectedProduct else {
            errorMessage = "Please select a plan"
            showError = true
            return
        }

        Task {
            do {
                if let result = try await storeKit.purchase(product) {
                    switch result {
                    case .success:
                        showSuccess = true
                    case .cancelled:
                        // User cancelled, do nothing
                        break
                    case .pending:
                        errorMessage = "Purchase is pending approval. Please check with your account holder."
                        showError = true
                    }
                }
            } catch {
                errorMessage = error.localizedDescription
                showError = true
            }
        }
    }

    private func openSubscriptionManagement() {
        if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene {
            Task {
                do {
                    try await AppStore.showManageSubscriptions(in: windowScene)
                } catch {
                    errorMessage = "Unable to open subscription management"
                    showError = true
                }
            }
        }
    }

    private func refreshStatus() async {
        await storeKit.loadProducts()
        await storeKit.updateSubscriptionStatus()
    }
}

#Preview {
    NavigationStack {
        SubscriptionView()
            .environmentObject(UserDefaultsManager.shared)
    }
}

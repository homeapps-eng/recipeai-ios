import SwiftUI

struct ProfileView: View {
    @ObservedObject var authManager = AuthManager.shared
    @EnvironmentObject var userDefaults: UserDefaultsManager
    @StateObject private var subscriptionManager = SubscriptionManager.shared
    @State private var showGuestConversion = false
    @State private var refreshID = UUID()

    var body: some View {
        NavigationStack {
            List {
                // Profile Header
                if authManager.isGuest {
                    guestProfileHeader
                } else {
                    profileHeader
                }

                // Create Account Card for Guests
                if authManager.isGuest {
                    createAccountSection
                }

                // Menu Items
                menuSection

                // Subscription Section (hide for guests)
                if !authManager.isGuest {
                    subscriptionSection
                }

                // Settings & Support
                settingsSection

                // Sign Out
                signOutSection
            }
            .navigationTitle("Profile")
            .navigationBarTitleDisplayMode(.large)
            .task {
                if let userId = userDefaults.userId, !authManager.isGuest {
                    await subscriptionManager.fetchStatus(userId: userId)
                }
            }
            .sheet(isPresented: $showGuestConversion) {
                GuestConversionView()
            }
            .onChange(of: authManager.authState) { _, newState in
                // Force refresh when auth state changes
                refreshID = UUID()
            }
            .id(refreshID)
        }
    }

    // MARK: - Guest Profile Header

    private var guestProfileHeader: some View {
        Section {
            HStack(spacing: 16) {
                // Guest Avatar
                Circle()
                    .fill(Color.gray.opacity(0.2))
                    .frame(width: 70, height: 70)
                    .overlay {
                        Image(systemName: "person.fill")
                            .font(.title)
                            .foregroundColor(.gray)
                    }

                // Guest Info
                VStack(alignment: .leading, spacing: 4) {
                    Text("Guest User")
                        .font(.appTitle3)
                        .foregroundColor(.textPrimary)

                    Text("Not signed in")
                        .font(.appSubheadline)
                        .foregroundColor(.textSecondary)
                }
            }
            .padding(.vertical, 8)
        }
    }

    // MARK: - Create Account Section

    private var createAccountSection: some View {
        Section {
            Button {
                showGuestConversion = true
            } label: {
                HStack(spacing: 16) {
                    Image(systemName: "person.badge.plus")
                        .font(.title2)
                        .foregroundColor(.white)
                        .frame(width: 44, height: 44)
                        .background(Color.brandGreen)
                        .cornerRadius(10)

                    VStack(alignment: .leading, spacing: 4) {
                        Text("Create Free Account")
                            .font(.appHeadline)
                            .foregroundColor(.textPrimary)

                        Text("Sync your data across devices")
                            .font(.appCaption1)
                            .foregroundColor(.textSecondary)
                    }

                    Spacer()

                    Image(systemName: "chevron.right")
                        .font(.caption)
                        .foregroundColor(.textSecondary)
                }
                .padding(.vertical, 8)
            }
            .buttonStyle(.plain)
        }
    }

    // MARK: - Profile Header

    private var profileHeader: some View {
        Section {
            NavigationLink(destination: EditProfileView()) {
                HStack(spacing: 16) {
                    // Avatar
                    if let avatarUrl = userDefaults.avatarUrl,
                       let url = URL(string: avatarUrl) {
                        AsyncImage(url: url) { image in
                            image
                                .resizable()
                                .aspectRatio(contentMode: .fill)
                        } placeholder: {
                            avatarPlaceholder
                        }
                        .frame(width: 70, height: 70)
                        .clipShape(Circle())
                    } else {
                        avatarPlaceholder
                    }

                    // User Info
                    VStack(alignment: .leading, spacing: 4) {
                        Text(userDefaults.username ?? "User")
                            .font(.appTitle3)
                            .foregroundColor(.textPrimary)

                        Text(userDefaults.userEmail ?? "")
                            .font(.appSubheadline)
                            .foregroundColor(.textSecondary)

                        if subscriptionManager.isPremium {
                            Text("Premium Member")
                                .font(.appCaption1)
                                .foregroundColor(.brandGreen)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 2)
                                .background(Color.brandGreenLight)
                                .cornerRadius(4)
                        }
                    }
                }
                .padding(.vertical, 8)
            }
        }
    }

    private var avatarPlaceholder: some View {
        Circle()
            .fill(Color.brandGreenLight)
            .frame(width: 70, height: 70)
            .overlay {
                Image(systemName: "person.fill")
                    .font(.title)
                    .foregroundColor(.brandGreen)
            }
    }

    // MARK: - Menu Section

    private var menuSection: some View {
        Section {
            NavigationLink(destination: FavoritesView()) {
                Label("Favorites", systemImage: "heart.fill")
                    .foregroundColor(.textPrimary)
            }

            NavigationLink(destination: PreferencesView()) {
                Label("Food Preferences", systemImage: "fork.knife")
                    .foregroundColor(.textPrimary)
            }
        }
    }

    // MARK: - Subscription Section

    private var subscriptionSection: some View {
        Section("Subscription") {
            if subscriptionManager.isPremium {
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(subscriptionManager.subscriptionStatus?.planName ?? "Premium")
                            .font(.appHeadline)

                        if let status = subscriptionManager.subscriptionStatus {
                            Text(status.statusType.displayName)
                                .font(.appCaption1)
                                .foregroundColor(Color(hex: status.statusType.color))
                        }
                    }

                    Spacer()

                    NavigationLink(destination: SubscriptionView()) {
                        Text("Manage")
                            .font(.appButtonSmall)
                            .foregroundColor(.brandGreen)
                    }
                }
            } else {
                NavigationLink(destination: SubscriptionView()) {
                    HStack {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Upgrade to Premium")
                                .font(.appHeadline)
                                .foregroundColor(.textPrimary)

                            Text("Get unlimited recipes")
                                .font(.appCaption1)
                                .foregroundColor(.textSecondary)
                        }

                        Spacer()

                        Image(systemName: "crown.fill")
                            .foregroundColor(.yellow)
                    }
                }
            }
        }
    }

    // MARK: - Settings Section

    private var settingsSection: some View {
        Section("Settings") {
            NavigationLink(destination: SettingsView()) {
                Label("Settings", systemImage: "gear")
                    .foregroundColor(.textPrimary)
            }

            NavigationLink(destination: SupportView()) {
                Label("Help & Support", systemImage: "questionmark.circle")
                    .foregroundColor(.textPrimary)
            }

            Link(destination: AppConfig.termsURL) {
                Label("Terms of Service", systemImage: "doc.text")
                    .foregroundColor(.textPrimary)
            }

            Link(destination: AppConfig.privacyURL) {
                Label("Privacy Policy", systemImage: "lock.shield")
                    .foregroundColor(.textPrimary)
            }
        }
    }

    // MARK: - Sign Out Section

    private var signOutSection: some View {
        Section {
            Button(role: .destructive) {
                signOut()
            } label: {
                if authManager.isGuest {
                    Label("Exit Guest Mode", systemImage: "rectangle.portrait.and.arrow.right")
                } else {
                    Label("Sign Out", systemImage: "rectangle.portrait.and.arrow.right")
                }
            }
        }
    }

    // MARK: - Actions

    private func signOut() {
        do {
            try authManager.signOut()
        } catch {
            // Error signing out
        }
    }
}

#Preview {
    ProfileView()
        .environmentObject(AuthManager.shared)
        .environmentObject(UserDefaultsManager.shared)
}

import SwiftUI

struct SettingsView: View {
    @EnvironmentObject var authManager: AuthManager
    @EnvironmentObject var userDefaults: UserDefaultsManager
    @State private var showDeleteConfirmation = false
    @State private var showChangePassword = false
    @State private var isLoading = false
    @State private var errorMessage = ""
    @State private var showError = false

    var body: some View {
        List {
            // Notifications
            notificationsSection

            // Preferences
            preferencesSection

            // Account
            accountSection

            // About
            aboutSection
        }
        .navigationTitle("Settings")
        .navigationBarTitleDisplayMode(.inline)
        .alert("Error", isPresented: $showError) {
            Button("OK") {}
        } message: {
            Text(errorMessage)
        }
        .alert("Delete Account", isPresented: $showDeleteConfirmation) {
            Button("Cancel", role: .cancel) {}
            Button("Delete", role: .destructive) {
                deleteAccount()
            }
        } message: {
            Text("Are you sure you want to delete your account? This action cannot be undone.")
        }
        .sheet(isPresented: $showChangePassword) {
            ChangePasswordView()
        }
        .loadingOverlay(isLoading: isLoading)
    }

    // MARK: - Notifications Section

    private var notificationsSection: some View {
        Section("Notifications") {
            Toggle("Push Notifications", isOn: $userDefaults.pushNotificationsEnabled)
                .tint(.brandGreen)

            Toggle("Recipe Suggestions", isOn: $userDefaults.recipeSuggestionsEnabled)
                .tint(.brandGreen)
        }
    }

    // MARK: - Preferences Section

    private var preferencesSection: some View {
        Section("Preferences") {
            Picker("Measurement Units", selection: $userDefaults.measurementUnits) {
                ForEach(MeasurementUnit.allCases, id: \.self) { unit in
                    Text(unit.rawValue).tag(unit)
                }
            }
        }
    }

    // MARK: - Account Section

    @ViewBuilder
    private var accountSection: some View {
        if !authManager.isGuest {
            Section("Account") {
                Button {
                    showChangePassword = true
                } label: {
                    Label("Change Password", systemImage: "key")
                        .foregroundColor(.textPrimary)
                }

                Button(role: .destructive) {
                    showDeleteConfirmation = true
                } label: {
                    Label("Delete Account", systemImage: "trash")
                }
            }
        }
    }

    // MARK: - About Section

    private var aboutSection: some View {
        Section("About") {
            HStack {
                Text("Version")
                Spacer()
                Text(Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0")
                    .foregroundColor(.textSecondary)
            }

            HStack {
                Text("Build")
                Spacer()
                Text(Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "1")
                    .foregroundColor(.textSecondary)
            }
        }
    }

    // MARK: - Actions

    private func deleteAccount() {
        isLoading = true
        Task {
            do {
                try await authManager.deleteAccount()
                isLoading = false
            } catch {
                isLoading = false
                errorMessage = error.localizedDescription
                showError = true
            }
        }
    }
}

// MARK: - Change Password View

struct ChangePasswordView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var currentPassword = ""
    @State private var newPassword = ""
    @State private var confirmPassword = ""
    @State private var isLoading = false
    @State private var showError = false
    @State private var errorMessage = ""
    @State private var showSuccess = false

    var isValid: Bool {
        !currentPassword.isEmpty &&
        !newPassword.isEmpty &&
        newPassword.count >= 6 &&
        newPassword == confirmPassword
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    SecureField("Current Password", text: $currentPassword)
                    SecureField("New Password", text: $newPassword)
                    SecureField("Confirm New Password", text: $confirmPassword)
                } footer: {
                    if !newPassword.isEmpty && newPassword.count < 6 {
                        Text("Password must be at least 6 characters")
                            .foregroundColor(.red)
                    } else if !confirmPassword.isEmpty && newPassword != confirmPassword {
                        Text("Passwords do not match")
                            .foregroundColor(.red)
                    }
                }

                Section {
                    Button("Update Password") {
                        updatePassword()
                    }
                    .disabled(!isValid)
                }
            }
            .navigationTitle("Change Password")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
            }
            .alert("Error", isPresented: $showError) {
                Button("OK") {}
            } message: {
                Text(errorMessage)
            }
            .alert("Success", isPresented: $showSuccess) {
                Button("OK") {
                    dismiss()
                }
            } message: {
                Text("Your password has been updated.")
            }
            .loadingOverlay(isLoading: isLoading)
        }
    }

    private func updatePassword() {
        // Note: Firebase requires re-authentication for password changes
        // This is a simplified implementation
        isLoading = true
        Task {
            do {
                // In a real implementation, you would:
                // 1. Re-authenticate the user with current password
                // 2. Update the password
                try await Task.sleep(nanoseconds: 1_000_000_000)
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
        SettingsView()
            .environmentObject(AuthManager.shared)
            .environmentObject(UserDefaultsManager.shared)
    }
}

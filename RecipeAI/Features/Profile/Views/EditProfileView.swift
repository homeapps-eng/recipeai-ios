import SwiftUI
import PhotosUI
import UIKit

struct EditProfileView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject var userDefaults: UserDefaultsManager

    @State private var username: String = ""
    @State private var selectedPhotoItem: PhotosPickerItem?
    @State private var selectedImage: UIImage?
    @State private var isLoading = false
    @State private var showError = false
    @State private var errorMessage = ""
    @State private var showSuccess = false

    var body: some View {
        Form {
            // Avatar Section
            Section {
                HStack {
                    Spacer()
                    avatarView
                    Spacer()
                }
                .listRowBackground(Color.clear)
            }

            // Username Section
            Section("Username") {
                TextField("Username", text: $username)
                    .textContentType(.username)
                    .autocapitalization(.none)
                    .autocorrectionDisabled()
            }

            // Email Section (read-only)
            Section("Email") {
                Text(userDefaults.userEmail ?? "")
                    .foregroundColor(.textSecondary)
            }
        }
        .navigationTitle("Edit Profile")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button("Save") {
                    saveProfile()
                }
                .disabled(isLoading || username.trimmingCharacters(in: .whitespaces).isEmpty)
            }
        }
        .onAppear {
            username = userDefaults.username ?? ""
        }
        .onChange(of: selectedPhotoItem) { _, newItem in
            Task {
                await loadSelectedPhoto(from: newItem)
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
            Text("Profile updated successfully")
        }
        .loadingOverlay(isLoading: isLoading)
    }

    // MARK: - Avatar View

    private var avatarView: some View {
        VStack(spacing: 12) {
            ZStack(alignment: .bottomTrailing) {
                if let image = selectedImage {
                    Image(uiImage: image)
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                        .frame(width: 100, height: 100)
                        .clipShape(Circle())
                } else if let avatarUrl = userDefaults.avatarUrl,
                          let url = URL(string: avatarUrl) {
                    AsyncImage(url: url) { image in
                        image
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                    } placeholder: {
                        avatarPlaceholder
                    }
                    .frame(width: 100, height: 100)
                    .clipShape(Circle())
                } else {
                    avatarPlaceholder
                }

                // Edit badge
                Circle()
                    .fill(Color.brandGreen)
                    .frame(width: 32, height: 32)
                    .overlay {
                        Image(systemName: "camera.fill")
                            .font(.caption)
                            .foregroundColor(.white)
                    }
            }

            PhotosPicker(selection: $selectedPhotoItem, matching: .images) {
                Text("Change Photo")
                    .font(.appSubheadline)
                    .foregroundColor(.brandGreen)
            }
        }
    }

    private var avatarPlaceholder: some View {
        Circle()
            .fill(Color.brandGreenLight)
            .frame(width: 100, height: 100)
            .overlay {
                Image(systemName: "person.fill")
                    .font(.largeTitle)
                    .foregroundColor(.brandGreen)
            }
    }

    // MARK: - Actions

    private func loadSelectedPhoto(from item: PhotosPickerItem?) async {
        guard let item = item else { return }

        do {
            if let data = try await item.loadTransferable(type: Data.self),
               let image = UIImage(data: data) {
                await MainActor.run {
                    selectedImage = image
                }
            }
        } catch {
            print("Error loading photo: \(error)")
        }
    }

    private func saveProfile() {
        guard let userId = userDefaults.userId else {
            errorMessage = "User not found. Please sign in again."
            showError = true
            return
        }

        let trimmedUsername = username.trimmingCharacters(in: .whitespaces)
        guard !trimmedUsername.isEmpty else {
            errorMessage = "Username cannot be empty."
            showError = true
            return
        }

        isLoading = true

        Task {
            do {
                var newAvatarUrl: String? = userDefaults.avatarUrl

                // Upload avatar if changed
                if let image = selectedImage {
                    newAvatarUrl = try await uploadAvatar(userId: userId, image: image)
                }

                // Update profile
                let request = UpdateProfileRequest(username: trimmedUsername, avatarUrl: newAvatarUrl)
                let response: ProfileResponse = try await NetworkManager.shared.put(
                    endpoint: .updateProfile(userId: userId),
                    body: request
                )

                await MainActor.run {
                    userDefaults.username = response.username
                    userDefaults.avatarUrl = response.avatarUrl
                    isLoading = false
                    showSuccess = true
                }
            } catch {
                await MainActor.run {
                    isLoading = false
                    errorMessage = "Failed to update profile. Please try again."
                    showError = true
                }
            }
        }
    }

    private func uploadAvatar(userId: String, image: UIImage) async throws -> String {
        // Resize and compress image
        let resizedImage = image.resizedForAPI(maxDimension: 256)
        guard let imageData = resizedImage.jpegData(compressionQuality: 0.8) else {
            throw ProfileError.imageProcessingFailed
        }

        let response: AvatarUploadResponse = try await NetworkManager.shared.uploadMultipart(
            endpoint: .uploadAvatar(userId: userId),
            data: imageData,
            filename: "avatar.jpg",
            mimeType: "image/jpeg",
            fieldName: "avatar"
        )

        guard let avatarUrl = response.avatarUrl else {
            throw ProfileError.imageProcessingFailed
        }

        return avatarUrl
    }
}

// MARK: - Request Models

struct UploadAvatarRequest: Encodable {
    let image: String
}

enum ProfileError: LocalizedError {
    case imageProcessingFailed

    var errorDescription: String? {
        switch self {
        case .imageProcessingFailed:
            return "Failed to process image"
        }
    }
}

#Preview {
    NavigationStack {
        EditProfileView()
            .environmentObject(UserDefaultsManager.shared)
    }
}

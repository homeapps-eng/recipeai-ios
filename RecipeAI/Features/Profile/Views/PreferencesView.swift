import SwiftUI

struct PreferencesView: View {
    @EnvironmentObject var userDefaults: UserDefaultsManager
    @State private var isLoading = false
    @State private var showAddKeyword = false
    @State private var newKeyword = ""

    var body: some View {
        List {
            // Categories
            categoriesSection

            // Cuisines
            cuisinesSection

            // Keywords
            keywordsSection

            // Dietary Restrictions
            dietarySection
        }
        .navigationTitle("Food Preferences")
        .navigationBarTitleDisplayMode(.inline)
        .onChange(of: userDefaults.likedCategories) { _, _ in
            savePreferences()
        }
        .onChange(of: userDefaults.selectedCuisines) { _, _ in
            savePreferences()
        }
        .alert("Add Keyword", isPresented: $showAddKeyword) {
            TextField("Keyword", text: $newKeyword)
            Button("Cancel", role: .cancel) {
                newKeyword = ""
            }
            Button("Add") {
                addKeyword()
            }
        } message: {
            Text("Add a keyword for recipe suggestions")
        }
    }

    // MARK: - Categories Section

    private var categoriesSection: some View {
        Section("Food Categories") {
            ForEach(FoodCategory.allCases) { category in
                Toggle(category.displayName, isOn: Binding(
                    get: { userDefaults.likedCategories.contains(category.rawValue) },
                    set: { isOn in
                        if isOn {
                            userDefaults.likedCategories.insert(category.rawValue)
                        } else {
                            userDefaults.likedCategories.remove(category.rawValue)
                        }
                    }
                ))
                .tint(.brandGreen)
            }
        }
    }

    // MARK: - Cuisines Section

    private var cuisinesSection: some View {
        Section("Cuisines") {
            ForEach(Cuisine.allCases) { cuisine in
                Toggle(cuisine.rawValue, isOn: Binding(
                    get: { userDefaults.selectedCuisines.contains(cuisine.rawValue) },
                    set: { isOn in
                        if isOn {
                            userDefaults.selectedCuisines.insert(cuisine.rawValue)
                        } else {
                            userDefaults.selectedCuisines.remove(cuisine.rawValue)
                        }
                    }
                ))
                .tint(.brandGreen)
            }
        }
    }

    // MARK: - Keywords Section

    private var keywordsSection: some View {
        Section {
            ForEach(userDefaults.keywords, id: \.self) { keyword in
                Text(keyword)
            }
            .onDelete(perform: deleteKeyword)

            Button {
                showAddKeyword = true
            } label: {
                Label("Add Keyword", systemImage: "plus")
            }
            .disabled(userDefaults.keywords.count >= 10)
        } header: {
            Text("Keywords")
        } footer: {
            Text("Add up to 10 keywords for personalized recipe suggestions")
        }
    }

    // MARK: - Dietary Section

    private var dietarySection: some View {
        Section("Dietary Restrictions") {
            ForEach(DietaryRestriction.allCases) { restriction in
                Toggle(restriction.rawValue, isOn: Binding(
                    get: { userDefaults.dietaryRestrictions.contains(restriction.rawValue) },
                    set: { isOn in
                        if isOn {
                            userDefaults.dietaryRestrictions.append(restriction.rawValue)
                        } else {
                            userDefaults.dietaryRestrictions.removeAll { $0 == restriction.rawValue }
                        }
                        savePreferences()
                    }
                ))
                .tint(.brandGreen)
            }
        }
    }

    // MARK: - Actions

    private func addKeyword() {
        let trimmed = newKeyword.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty, !userDefaults.keywords.contains(trimmed) else {
            newKeyword = ""
            return
        }

        userDefaults.keywords.append(trimmed)
        newKeyword = ""
        savePreferences()
    }

    private func deleteKeyword(at offsets: IndexSet) {
        userDefaults.keywords.remove(atOffsets: offsets)
        savePreferences()
    }

    private func savePreferences() {
        guard let userId = userDefaults.userId else { return }

        Task {
            let preferences = userDefaults.getPreferences()
            do {
                let _: UserPreferences = try await NetworkManager.shared.put(
                    endpoint: .updatePreferences(userId: userId),
                    body: preferences
                )
            } catch {
                // Error saving preferences
            }
        }
    }
}

#Preview {
    NavigationStack {
        PreferencesView()
            .environmentObject(UserDefaultsManager.shared)
    }
}

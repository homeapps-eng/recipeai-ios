import SwiftUI
import Combine

struct GuestPreferencesView: View {
    var onComplete: () -> Void
    var onSkip: () -> Void

    @StateObject private var viewModel = GuestPreferencesViewModel()
    @State private var currentPage = 0

    var body: some View {
        VStack(spacing: 0) {
            // Header with Skip
            headerWithSkip

            // Progress Indicator
            progressIndicator

            // Content
            TabView(selection: $currentPage) {
                // Page 1: Food Categories
                categoriesPage
                    .tag(0)

                // Page 2: Cuisines (optional)
                cuisinesPage
                    .tag(1)
            }
            .tabViewStyle(.page(indexDisplayMode: .never))
            .animation(.easeInOut, value: currentPage)

            // Navigation Buttons
            navigationButtons
        }
        .background(Color.backgroundPrimary)
    }

    // MARK: - Header with Skip

    private var headerWithSkip: some View {
        HStack {
            Spacer()
            Button("Skip") {
                onSkip()
            }
            .font(.appSubheadline)
            .foregroundColor(.brandGreen)
            .padding(.horizontal, 24)
            .padding(.top, 16)
        }
    }

    // MARK: - Progress Indicator

    private var progressIndicator: some View {
        HStack(spacing: 8) {
            ForEach(0..<2, id: \.self) { index in
                RoundedRectangle(cornerRadius: 2)
                    .fill(index <= currentPage ? Color.brandGreen : Color.gray.opacity(0.3))
                    .frame(height: 4)
            }
        }
        .padding(.horizontal, 24)
        .padding(.top, 8)
    }

    // MARK: - Categories Page

    private var categoriesPage: some View {
        VStack(spacing: 24) {
            // Header
            VStack(spacing: 8) {
                Text("What do you like to eat?")
                    .font(.appTitle1)
                    .foregroundColor(.textPrimary)

                Text("Help us personalize your recipes")
                    .font(.appSubheadline)
                    .foregroundColor(.textSecondary)
            }
            .padding(.top, 32)

            // Categories Grid
            ScrollView {
                LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 16) {
                    ForEach(FoodCategory.allCases) { category in
                        categoryCard(category)
                    }
                }
                .padding(.horizontal)
            }

            Spacer()
        }
    }

    private func categoryCard(_ category: FoodCategory) -> some View {
        let isSelected = viewModel.selectedCategories.contains(category.rawValue)

        return Button {
            viewModel.toggleCategory(category)
        } label: {
            VStack(spacing: 12) {
                Image(category.imageName)
                    .resizable()
                    .scaledToFill()
                    .frame(width: 50, height: 50)
                    .clipShape(Circle())

                Text(category.displayName)
                    .font(.appHeadline)
                    .foregroundColor(isSelected ? .white : .textPrimary)
            }
            .frame(maxWidth: .infinity)
            .frame(height: 120)
            .background(isSelected ? Color.brandGreen : Color.backgroundSecondary)
            .cornerRadius(16)
            .overlay(
                RoundedRectangle(cornerRadius: 16)
                    .stroke(isSelected ? Color.brandGreen : Color.clear, lineWidth: 2)
            )
        }
        .buttonStyle(.plain)
    }

    // MARK: - Cuisines Page

    private var cuisinesPage: some View {
        VStack(spacing: 24) {
            // Header
            VStack(spacing: 8) {
                Text("Favorite Cuisines")
                    .font(.appTitle1)
                    .foregroundColor(.textPrimary)

                Text("Select cuisines you enjoy (optional)")
                    .font(.appSubheadline)
                    .foregroundColor(.textSecondary)
            }
            .padding(.top, 32)

            // Cuisines
            ScrollView {
                FlowLayout(spacing: 12) {
                    ForEach(Cuisine.allCases) { cuisine in
                        cuisineChip(cuisine)
                    }
                }
                .padding(.horizontal)
            }

            Spacer()
        }
    }

    private func cuisineChip(_ cuisine: Cuisine) -> some View {
        let isSelected = viewModel.selectedCuisines.contains(cuisine.rawValue)

        return Button {
            viewModel.toggleCuisine(cuisine)
        } label: {
            Text(cuisine.rawValue)
                .font(.appSubheadline)
                .foregroundColor(isSelected ? .white : .textPrimary)
                .padding(.horizontal, 16)
                .padding(.vertical, 10)
                .background(isSelected ? Color.brandGreen : Color.backgroundSecondary)
                .cornerRadius(20)
        }
        .buttonStyle(.plain)
    }

    // MARK: - Navigation Buttons

    private var navigationButtons: some View {
        HStack(spacing: 16) {
            if currentPage > 0 {
                Button("Back") {
                    withAnimation {
                        currentPage -= 1
                    }
                }
                .buttonStyle(.outline)
            }

            Button(currentPage == 1 ? "Get Started" : "Next") {
                if currentPage == 1 {
                    saveAndComplete()
                } else {
                    withAnimation {
                        currentPage += 1
                    }
                }
            }
            .buttonStyle(.primary)
            .disabled(currentPage == 0 && viewModel.selectedCategories.isEmpty)
            .opacity(currentPage == 0 && viewModel.selectedCategories.isEmpty ? 0.6 : 1)
        }
        .padding(24)
    }

    // MARK: - Save and Complete

    private func saveAndComplete() {
        viewModel.savePreferencesLocally()
        onComplete()
    }
}

// MARK: - ViewModel

@MainActor
final class GuestPreferencesViewModel: ObservableObject {
    @Published var selectedCategories: Set<String> = []
    @Published var selectedCuisines: Set<String> = []

    func toggleCategory(_ category: FoodCategory) {
        if selectedCategories.contains(category.rawValue) {
            selectedCategories.remove(category.rawValue)
        } else {
            selectedCategories.insert(category.rawValue)
        }
    }

    func toggleCuisine(_ cuisine: Cuisine) {
        if selectedCuisines.contains(cuisine.rawValue) {
            selectedCuisines.remove(cuisine.rawValue)
        } else {
            selectedCuisines.insert(cuisine.rawValue)
        }
    }

    func savePreferencesLocally() {
        let preferences = UserPreferences(
            userId: UserDefaultsManager.shared.userId,
            categories: Array(selectedCategories),
            cuisines: Array(selectedCuisines),
            keywords: nil,
            dietaryRestrictions: nil,
            allergies: nil
        )

        // Save only locally for guest users - no backend sync
        UserDefaultsManager.shared.savePreferences(preferences)
    }
}

#Preview {
    GuestPreferencesView(onComplete: {}, onSkip: {})
}

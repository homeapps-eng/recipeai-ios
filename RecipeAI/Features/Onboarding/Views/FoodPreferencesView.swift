import SwiftUI
import Combine

struct FoodPreferencesView: View {
    var onComplete: () -> Void

    @StateObject private var viewModel = FoodPreferencesViewModel()
    @State private var currentPage = 0

    var body: some View {
        VStack(spacing: 0) {
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
        .padding(.top, 16)
    }

    // MARK: - Categories Page

    private var categoriesPage: some View {
        VStack(spacing: 24) {
            // Header
            VStack(spacing: 8) {
                Text("What do you like to eat?")
                    .font(.appTitle1)
                    .foregroundColor(.textPrimary)

                Text("Select your favorite food categories")
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
        Task {
            await viewModel.savePreferences()
            onComplete()
        }
    }
}

// MARK: - Flow Layout

struct FlowLayout: Layout {
    var spacing: CGFloat = 8

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let result = FlowResult(in: proposal.width ?? 0, subviews: subviews, spacing: spacing)
        return CGSize(width: proposal.width ?? 0, height: result.height)
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        let result = FlowResult(in: bounds.width, subviews: subviews, spacing: spacing)
        for (index, subview) in subviews.enumerated() {
            subview.place(at: CGPoint(x: bounds.minX + result.positions[index].x,
                                     y: bounds.minY + result.positions[index].y),
                         proposal: .unspecified)
        }
    }

    struct FlowResult {
        var positions: [CGPoint] = []
        var height: CGFloat = 0

        init(in maxWidth: CGFloat, subviews: Subviews, spacing: CGFloat) {
            var x: CGFloat = 0
            var y: CGFloat = 0
            var rowHeight: CGFloat = 0

            for subview in subviews {
                let size = subview.sizeThatFits(.unspecified)

                if x + size.width > maxWidth && x > 0 {
                    x = 0
                    y += rowHeight + spacing
                    rowHeight = 0
                }

                positions.append(CGPoint(x: x, y: y))
                x += size.width + spacing
                rowHeight = max(rowHeight, size.height)
            }

            height = y + rowHeight
        }
    }
}

// MARK: - ViewModel

@MainActor
final class FoodPreferencesViewModel: ObservableObject {
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

    func savePreferences() async {
        let preferences = UserPreferences(
            userId: UserDefaultsManager.shared.userId,
            categories: Array(selectedCategories),
            cuisines: Array(selectedCuisines),
            keywords: nil,
            dietaryRestrictions: nil,
            allergies: nil
        )

        // Save locally
        UserDefaultsManager.shared.savePreferences(preferences)

        // Sync with backend
        if let userId = UserDefaultsManager.shared.userId {
            do {
                let _: UserPreferences = try await NetworkManager.shared.put(
                    endpoint: .updatePreferences(userId: userId),
                    body: preferences
                )
            } catch {
                print("Error syncing preferences: \(error)")
            }
        }
    }
}

#Preview {
    FoodPreferencesView(onComplete: {})
}

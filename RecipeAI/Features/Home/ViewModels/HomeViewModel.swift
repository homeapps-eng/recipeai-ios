import Foundation

@MainActor
final class HomeViewModel: ObservableObject {
    @Published var dailyRecipe: Recipe?
    @Published var isLoading = false
    @Published var error: Error?

    private let usageTracker = RecipeUsageTracker.shared

    func loadDailyRecipe() async {
        guard !isLoading else { return }

        // Check if user can load home recipe
        guard usageTracker.canLoadHomeRecipe else {
            // Show upgrade prompt or ad
            return
        }

        isLoading = true
        error = nil

        do {
            // Get user preferences for personalized recipe
            let preferences = UserDefaultsManager.shared.getPreferences()

            // Build form data for request
            var formData: [String: String] = [:]
            if let categories = preferences.categories, !categories.isEmpty {
                formData["categories"] = categories.joined(separator: ",")
            }
            if let cuisines = preferences.cuisines, !cuisines.isEmpty {
                formData["cuisine"] = cuisines.randomElement() ?? ""
            }

            let response: SingleRecipeResponse = try await NetworkManager.shared.requestFormEncoded(
                endpoint: .generateSingleRecipe,
                formData: formData
            )

            if response.success, let recipe = response.recipe {
                dailyRecipe = recipe
                usageTracker.incrementHomeRecipeLoads()
            } else {
                error = RecipeError.generationFailed(response.message ?? "Unknown error")
            }

            isLoading = false
        } catch {
            self.error = error
            isLoading = false
        }
    }

    func refreshRecipe() async {
        dailyRecipe = nil
        await loadDailyRecipe()
    }
}

enum RecipeError: LocalizedError {
    case generationFailed(String)
    case noRecipesGenerated
    case caloriesCalculationFailed(String)

    var errorDescription: String? {
        switch self {
        case .generationFailed(let message):
            return "Failed to generate recipe: \(message)"
        case .noRecipesGenerated:
            return "No recipes were generated"
        case .caloriesCalculationFailed(let message):
            return "Failed to calculate calories: \(message)"
        }
    }
}

import Foundation
import Combine

@MainActor
final class HomeViewModel: ObservableObject {
    @Published var dailyRecipe: Recipe?
    @Published var isLoading = false
    @Published var error: Error?
    @Published var showAdPrompt = false

    private let usageTracker = RecipeUsageTracker.shared
    private let adManager = AdManager.shared
    @Published private(set) var isRefreshing = false
    private var pendingForceRefresh = false

    func loadDailyRecipe(forceRefresh: Bool = false) async {
        print("DEBUG: loadDailyRecipe called, forceRefresh=\(forceRefresh), isLoading=\(isLoading)")

        // Don't reload if we already have a recipe (unless forcing refresh)
        guard dailyRecipe == nil || forceRefresh else {
            print("DEBUG: Skipping - recipe exists and not forcing refresh")
            return
        }

        // Prevent duplicate loads (but allow if forcing refresh)
        guard !isLoading || forceRefresh else {
            print("DEBUG: Skipping - already loading")
            return
        }

        // Check if user can load home recipe
        guard usageTracker.canLoadHomeRecipe else {
            print("DEBUG: Usage limit reached - showing ad prompt")
            pendingForceRefresh = forceRefresh
            showAdPrompt = true
            return
        }

        print("DEBUG: Starting recipe load...")
        isLoading = true
        error = nil

        do {
            // Get user preferences for personalized recipe
            let preferences = UserDefaultsManager.shared.getPreferences()
            print("DEBUG: Got preferences")

            // Build form data for request
            var formData: [String: String] = [:]
            if let categories = preferences.categories, !categories.isEmpty {
                formData["categories"] = categories.joined(separator: ",")
            }
            if let cuisines = preferences.cuisines, !cuisines.isEmpty {
                formData["cuisine"] = cuisines.randomElement() ?? ""
            }
            print("DEBUG: Form data built: \(formData)")
            print("DEBUG: About to call API...")

            let response: SingleRecipeResponse = try await NetworkManager.shared.requestFormEncoded(
                endpoint: .generateSingleRecipe,
                formData: formData
            )
            print("DEBUG: API response received")

            if response.success, let recipe = response.recipe {
                dailyRecipe = recipe
                usageTracker.incrementHomeRecipeLoads()
                error = nil
            } else {
                let errorMsg = response.message ?? "Unable to generate recipe"
                error = RecipeError.generationFailed(errorMsg)
            }

            isLoading = false
        } catch {
            isLoading = false

            // Ignore cancelled requests (NSURLErrorCancelled = -999)
            let nsError = error as NSError
            if nsError.domain == NSURLErrorDomain && nsError.code == NSURLErrorCancelled {
                return
            }

            // Check if wrapped in NetworkError
            if let networkError = error as? NetworkError,
               case .networkError(let underlying) = networkError {
                let underlyingNSError = underlying as NSError
                if underlyingNSError.domain == NSURLErrorDomain && underlyingNSError.code == NSURLErrorCancelled {
                    return
                }
            }

            self.error = error
            print("HomeViewModel error: \(error)")
        }
    }

    func refreshRecipe() async {
        print("DEBUG: refreshRecipe called, isRefreshing=\(isRefreshing)")

        // Prevent duplicate refresh calls
        guard !isRefreshing else {
            print("DEBUG: Skipping - already refreshing")
            return
        }

        isRefreshing = true
        error = nil
        await loadDailyRecipe(forceRefresh: true)
        isRefreshing = false
    }

    // MARK: - Ad Handling

    func watchAdAndContinue() {
        guard let viewController = adManager.getRootViewController() else {
            error = RecipeError.generationFailed("Unable to show ad. Please try again.")
            return
        }

        adManager.showRewardedAd(from: viewController) { [weak self] in
            guard let self = self else { return }
            // Grant extra load after watching ad
            self.usageTracker.grantExtraHomeRecipeLoad()
            // Continue loading recipe
            Task {
                await self.loadDailyRecipe(forceRefresh: self.pendingForceRefresh)
            }
        }
    }

    func dismissAdPrompt() {
        showAdPrompt = false
        error = RecipeError.generationFailed("Daily limit reached. Upgrade to Premium for unlimited recipes!")
    }
}

enum RecipeError: LocalizedError {
    case generationFailed(String)
    case noRecipesGenerated
    case caloriesCalculationFailed(String)

    var errorDescription: String? {
        switch self {
        case .generationFailed(let message):
            return message
        case .noRecipesGenerated:
            return "No recipes were generated"
        case .caloriesCalculationFailed(let message):
            return message
        }
    }
}

import Foundation
import Combine

@MainActor
final class HomeViewModel: ObservableObject {
    @Published var dailyRecipe: Recipe?
    @Published var isLoading = false
    @Published var error: Error?
    @Published var showAdPrompt = false
    @Published var showAdError = false
    @Published var adErrorMessage = ""

    private let usageTracker = RecipeUsageTracker.shared
    private let adManager = AdManager.shared
    @Published private(set) var isRefreshing = false
    private var pendingForceRefresh = false

    func loadDailyRecipe(forceRefresh: Bool = false) async {
        // Don't reload if we already have a recipe (unless forcing refresh)
        guard dailyRecipe == nil || forceRefresh else { return }

        // Prevent duplicate loads (but allow if forcing refresh)
        guard !isLoading || forceRefresh else { return }

        // Pre-load ad in background for when user needs it
        Task {
            await adManager.loadRewardedAd()
        }

        // Check if user can load home recipe
        guard usageTracker.canLoadHomeRecipe else {
            pendingForceRefresh = forceRefresh
            showAdPrompt = true
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
        }
    }

    func refreshRecipe() async {
        // Prevent duplicate refresh calls
        guard !isRefreshing else { return }

        isRefreshing = true
        error = nil
        await loadDailyRecipe(forceRefresh: true)
        isRefreshing = false
    }

    // MARK: - Ad Handling

    func watchAdAndContinue() {
        // Dismiss the prompt immediately
        showAdPrompt = false
        let shouldForceRefresh = pendingForceRefresh

        // Use retry logic to wait for alert to dismiss
        adManager.showRewardedAdWhenReady(
            onReward: { [weak self] in
                guard let self = self else { return }
                Task { @MainActor in
                    // Grant extra load after watching ad (must be on main thread)
                    self.usageTracker.grantExtraHomeRecipeLoad()
                    // Continue loading recipe
                    await self.loadDailyRecipe(forceRefresh: shouldForceRefresh)
                }
            },
            onError: { [weak self] errorMessage in
                Task { @MainActor in
                    self?.adErrorMessage = errorMessage
                    self?.showAdError = true
                }
            }
        )
    }

    func dismissAdPrompt() {
        showAdPrompt = false
        pendingForceRefresh = false
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

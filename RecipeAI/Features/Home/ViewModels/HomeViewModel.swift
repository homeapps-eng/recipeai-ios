import Foundation
import Combine

/// The home feed: recipes from the catalog, loaded a page at a time as the
/// user scrolls. Nothing here calls the AI.
@MainActor
final class HomeViewModel: ObservableObject {
    /// Recipes per request. Six cards fill a phone screen: three rows of two.
    static let pageSize = 6

    @Published private(set) var recipes: [Recipe] = []
    @Published private(set) var isLoading = false
    @Published private(set) var isLoadingMore = false
    @Published private(set) var loadMoreFailed = false
    @Published private(set) var error: Error?
    @Published var showRefreshError = false

    /// What the recipes on screen were chosen for. Nil until a page has loaded.
    private var loadedFilters: RecipeFeedFilters?
    /// What the latest reload asked for. Differs from `loadedFilters` only
    /// while that reload is on its way.
    private var requestedFilters: RecipeFeedFilters?
    /// The server picks a seed for each new selection. Sending it back with an
    /// offset returns the next page of that same selection.
    private var seed = 0
    private var nextOffset = 0
    private var hasMore = false
    /// Counts reloads, so that only the latest one updates the screen.
    private var reloads = 0

    /// True when the catalog has nothing that fits the user's preferences.
    var hasNoMatches: Bool {
        loadedFilters != nil && recipes.isEmpty && !isLoading
    }

    var errorMessage: String {
        guard let error, error.isNetworkUnavailable || error.isTimeoutError else {
            return "We couldn't load recipes. Please try again."
        }
        return error.userFriendlyMessage
    }

    /// Loads the feed when there is none yet, or when the language or the
    /// food preferences have changed since it was loaded.
    func loadIfNeeded() async {
        guard requestedFilters != .current else { return }
        await reload()
    }

    /// Replaces the feed with a new selection.
    func refresh() async {
        // Not in the caller's task: SwiftUI can cancel a pull-to-refresh
        // action when the view updates, and the request would go with it.
        await Task { await reload() }.value
    }

    /// Called as each card appears. Asks for the next page as soon as a card
    /// of the last one comes into view, so a page is always waiting below.
    func loadMoreIfNeeded(after recipe: Recipe) async {
        guard !loadMoreFailed, recipes.suffix(Self.pageSize).contains(recipe) else { return }
        await loadMore()
    }

    func loadMore() async {
        guard hasMore, !isLoadingMore, let filters = loadedFilters else { return }
        let (seed, offset) = (seed, nextOffset)

        isLoadingMore = true
        loadMoreFailed = false
        do {
            let page = try await fetchPage(filters, seed: seed, offset: offset)
            // A reload replaced the selection while this page was loading.
            guard seed == self.seed, offset == nextOffset else { return }

            let shown = Set(recipes.map(\.id))
            recipes += (page.recipes ?? []).filter { !shown.contains($0.id) }
            nextOffset = page.nextOffset
            hasMore = page.hasMore
        } catch {
            guard seed == self.seed, offset == nextOffset else { return }
            loadMoreFailed = true
        }
        isLoadingMore = false
    }

    private func reload() async {
        let filters = RecipeFeedFilters.current
        requestedFilters = filters
        reloads += 1
        let reload = reloads

        isLoading = true
        error = nil
        do {
            let page = try await fetchPage(filters, seed: 0, offset: 0)
            guard reload == reloads else { return }

            recipes = page.recipes ?? []
            seed = page.seed
            nextOffset = page.nextOffset
            hasMore = page.hasMore
            loadedFilters = filters
            isLoadingMore = false
            loadMoreFailed = false
        } catch {
            guard reload == reloads else { return }
            // The recipes already on screen stay there.
            requestedFilters = loadedFilters
            self.error = error
            showRefreshError = !recipes.isEmpty
        }
        isLoading = false
    }

    private func fetchPage(_ filters: RecipeFeedFilters, seed: Int, offset: Int) async throws -> RecipeFeedResponse {
        try await NetworkManager.shared.get(
            endpoint: .getRecipeFeed(filters: filters, seed: seed, offset: offset, limit: Self.pageSize)
        )
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

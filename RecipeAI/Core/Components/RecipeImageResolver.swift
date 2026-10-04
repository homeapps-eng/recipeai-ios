import Foundation
import Combine

/// Resolves AI image URLs for recipes whose image was still being generated
/// when the recipe was returned.
///
/// All views waiting on an image share one polling loop, which asks
/// `/api/v1/recipe/images` for every pending id in a single request. Resolved
/// URLs are kept for the app session (GCS image URLs are stable), so a view
/// recreated by navigation shows its image immediately instead of polling again.
@MainActor
final class RecipeImageResolver: ObservableObject {
    static let shared = RecipeImageResolver()

    /// Resolved image URLs, keyed by recipe id.
    @Published private(set) var urls: [String: String] = [:]
    /// Recipes whose image did not arrive before polling gave up.
    @Published private(set) var unresolved: Set<String> = []

    /// Seconds to wait before each check. An image already cached for the dish
    /// lands within a second or two; a freshly generated one can take much
    /// longer, so back off and keep checking for about a minute.
    private static let delays: [Double] = [1, 2, 3, 5, 5, 8, 8, 10, 10, 10]

    /// Checks made so far for each recipe still waiting on its image.
    private var pending: [String: Int] = [:]
    private var pollTask: Task<Void, Never>?

    private init() {}

    /// Starts (or joins) polling for a recipe's image.
    func resolve(_ recipeId: String) {
        guard urls[recipeId] == nil, pending[recipeId] == nil else { return }

        pending[recipeId] = 0
        unresolved.remove(recipeId)
        if pollTask == nil {
            pollTask = Task { await poll() }
        }
    }

    private func poll() async {
        while let checks = pending.values.min() {
            try? await Task.sleep(for: .seconds(Self.delays[checks]))

            let ids = Array(pending.keys)
            let response: RecipeImagesResponse? = try? await NetworkManager.shared.get(
                endpoint: .getRecipeImages(ids: ids)
            )

            for id in ids {
                if let url = response?.images?.first(where: { $0.id == id })?.imageUrl, !url.isEmpty {
                    urls[id] = url
                    pending[id] = nil
                } else if let checks = pending[id] {
                    if checks + 1 < Self.delays.count {
                        pending[id] = checks + 1
                    } else {
                        pending[id] = nil
                        unresolved.insert(id)
                    }
                }
            }
        }
        pollTask = nil
    }
}

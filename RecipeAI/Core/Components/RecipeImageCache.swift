import Foundation

/// In-memory cache of resolved AI image URLs, keyed by recipe id.
///
/// This solves the navigation churn that would otherwise restart the polling
/// loop every time a `RecipeImageView` is recreated (e.g. swiping into a
/// detail view and back, or list cells being re-rendered). Once any view
/// resolves the URL for a recipe, every other view sees it immediately on
/// next appearance — no extra network call, no placeholder re-flash.
///
/// The cache lives for the app session; GCS image URLs are stable so there
/// is no need for invalidation while the app is running.
@MainActor
final class RecipeImageCache {
    static let shared = RecipeImageCache()

    private var urls: [String: String] = [:]

    private init() {}

    func url(for recipeId: String) -> String? {
        urls[recipeId]
    }

    func store(_ url: String, for recipeId: String) {
        guard !url.isEmpty else { return }
        urls[recipeId] = url
    }
}

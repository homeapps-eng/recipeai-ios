import SwiftUI

/// Unified recipe image view used by Home / Recipes list / Recipe detail.
///
/// While `initialImageUrl` is empty/nil, shows the cool-mint placeholder
/// gradient with the `CookingSteamLoaderView` animation overlay, and polls
/// `/api/v1/recipe/images?ids=<id>` every 5s (up to 4 attempts) to pick up
/// the AI image as soon as the backend writes it.
///
/// When an image URL is available (either initially or via polling), loads
/// it through `AsyncImage`.
struct RecipeImageView: View {
    let recipeId: String
    let initialImageUrl: String?
    let cornerRadius: CGFloat

    @State private var resolvedImageUrl: String?

    private var displayUrl: String? {
        if let resolved = resolvedImageUrl, !resolved.isEmpty { return resolved }
        if let initial = initialImageUrl, !initial.isEmpty { return initial }
        return nil
    }

    var body: some View {
        ZStack {
            // Mint gradient base — always present so transitions to a real
            // image are seamless.
            LinearGradient(
                colors: [Color.placeholderBgTop, Color.placeholderBgBottom],
                startPoint: .top,
                endPoint: .bottom
            )

            if let urlStr = displayUrl, let url = URL(string: urlStr) {
                AsyncImage(url: url) { phase in
                    switch phase {
                    case .success(let image):
                        image
                            .resizable()
                            .scaledToFill()
                    default:
                        CookingSteamLoaderView()
                    }
                }
            } else {
                CookingSteamLoaderView()
            }
        }
        .clipped()
        .clipShape(RoundedRectangle(cornerRadius: cornerRadius))
        .task(id: recipeId + (initialImageUrl ?? "")) {
            await pollIfNeeded()
        }
    }

    // MARK: - Polling

    private func pollIfNeeded() async {
        // Already have an image — nothing to do.
        if let url = initialImageUrl, !url.isEmpty {
            resolvedImageUrl = url
            return
        }
        // Reset any stale resolved URL from a previous recipe.
        resolvedImageUrl = nil

        let maxAttempts = 4
        let intervalNs: UInt64 = 5_000_000_000
        for _ in 0..<maxAttempts {
            try? await Task.sleep(nanoseconds: intervalNs)
            if Task.isCancelled { return }

            do {
                let response: RecipeImagesResponse = try await NetworkManager.shared.get(
                    endpoint: .getRecipeImages(ids: [recipeId])
                )
                if let match = response.images?.first(where: { $0.id == recipeId }),
                   let url = match.imageUrl,
                   !url.isEmpty {
                    resolvedImageUrl = url
                    return
                }
            } catch {
                // Silent retry on next iteration. The placeholder + animation
                // continue showing meanwhile.
            }
        }
    }
}

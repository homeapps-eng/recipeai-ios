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

    /// Pre-fill from the session cache on init so the view doesn't flash the
    /// placeholder on appearance if another view has already resolved this id.
    init(recipeId: String, initialImageUrl: String?, cornerRadius: CGFloat) {
        self.recipeId = recipeId
        self.initialImageUrl = initialImageUrl
        self.cornerRadius = cornerRadius
        let preloaded = (initialImageUrl?.isEmpty == false ? initialImageUrl : nil)
            ?? RecipeImageCache.shared.url(for: recipeId)
        _resolvedImageUrl = State(initialValue: preloaded)
    }

    var body: some View {
        // `AsyncImage` measures itself by its loaded photo's intrinsic pixel
        // size. Even with explicit `.frame()` modifiers, that intrinsic size
        // can leak upward and break sibling layout the moment a real image
        // arrives. The fix is the `Color.clear` + `.background(AsyncImage)`
        // idiom: a transparent layout-driving view holds the slot at the
        // caller-imposed frame, the photo renders behind it, and `.clipped()`
        // crops anything that overflows.
        Color.clear
            .overlay {
                LinearGradient(
                    colors: [Color.placeholderBgTop, Color.placeholderBgBottom],
                    startPoint: .top,
                    endPoint: .bottom
                )
            }
            .overlay {
                if let urlStr = displayUrl, let url = URL(string: urlStr) {
                    AsyncImage(url: url) { phase in
                        switch phase {
                        case .success(let image):
                            image
                                .resizable()
                                .aspectRatio(contentMode: .fill)
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
        // The recipe came pre-resolved — record it so other views skip polling.
        if let url = initialImageUrl, !url.isEmpty {
            RecipeImageCache.shared.store(url, for: recipeId)
            resolvedImageUrl = url
            return
        }

        // Another view resolved this id during the session — use it immediately.
        if let cached = RecipeImageCache.shared.url(for: recipeId), !cached.isEmpty {
            resolvedImageUrl = cached
            return
        }

        // No URL yet — show the placeholder + animation and poll for it.
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
                    RecipeImageCache.shared.store(url, for: recipeId)
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

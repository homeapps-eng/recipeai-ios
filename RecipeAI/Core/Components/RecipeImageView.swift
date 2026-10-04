import SwiftUI

/// Unified recipe image view used by Home / Recipes list / Recipe detail.
///
/// While the recipe has no image URL yet, shows the cool-mint placeholder
/// gradient with the `CookingSteamLoaderView` animation overlay and asks
/// `RecipeImageResolver` to pick up the AI image as soon as the backend
/// writes it.
///
/// When an image URL is available (either initially or via the resolver),
/// loads it through `RemoteImage`. If the image never arrives or fails to
/// download, the animation is replaced by a static placeholder.
struct RecipeImageView: View {
    let recipeId: String
    let initialImageUrl: String?
    let cornerRadius: CGFloat

    @ObservedObject private var resolver = RecipeImageResolver.shared

    private var displayUrl: String? {
        if let initial = initialImageUrl, !initial.isEmpty { return initial }
        return resolver.urls[recipeId]
    }

    var body: some View {
        // The image must never drive layout: a transparent view holds the slot
        // at the caller-imposed frame, the photo renders on top of it, and
        // `.clipped()` crops anything that overflows.
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
                    RemoteImage(url: url) { phase in
                        switch phase {
                        case .success(let image):
                            image
                                .resizable()
                                .aspectRatio(contentMode: .fill)
                        case .failure:
                            unavailablePlaceholder
                        default:
                            CookingSteamLoaderView()
                        }
                    }
                } else if resolver.unresolved.contains(recipeId) {
                    unavailablePlaceholder
                } else {
                    CookingSteamLoaderView()
                }
            }
            .clipped()
            .clipShape(RoundedRectangle(cornerRadius: cornerRadius))
            .task(id: recipeId + (initialImageUrl ?? "")) {
                if displayUrl == nil {
                    resolver.resolve(recipeId)
                }
            }
    }

    private var unavailablePlaceholder: some View {
        Image(systemName: "fork.knife")
            .font(.title2)
            .foregroundColor(.brandGreen)
    }
}

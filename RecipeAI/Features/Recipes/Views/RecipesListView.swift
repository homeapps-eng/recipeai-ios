import SwiftUI

struct RecipesListView: View {
    let recipes: [Recipe]
    @State private var selectedRecipe: Recipe?

    var body: some View {
        ScrollView {
            LazyVStack(spacing: 16) {
                ForEach(recipes) { recipe in
                    NavigationLink(destination: RecipeDetailView(recipe: recipe)) {
                        RecipeCardView(recipe: recipe)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding()
        }
        .navigationTitle("Recipes")
        .navigationBarTitleDisplayMode(.large)
    }
}

struct RecipeCardView: View {
    let recipe: Recipe

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Recipe Image
            recipeImage

            // Recipe Info
            VStack(alignment: .leading, spacing: 8) {
                Text(recipe.name)
                    .font(.appHeadline)
                    .foregroundColor(.textPrimary)
                    .lineLimit(2)

                Text(recipe.shortDescription)
                    .font(.appSubheadline)
                    .foregroundColor(.textSecondary)
                    .lineLimit(2)

                HStack(spacing: 16) {
                    Label(recipe.cookingTime, systemImage: "clock")
                    Label(recipe.difficulty, systemImage: "chart.bar")
                }
                .font(.appCaption1)
                .foregroundColor(.textSecondary)
            }
            .padding(.horizontal, 4)
        }
        .cardStyle()
    }

    private var recipeImage: some View {
        // Unified placeholder + bubble animation + auto-polling for the
        // AI-generated image. Same treatment as Home / Detail.
        RecipeImageView(
            recipeId: recipe.id,
            initialImageUrl: recipe.imageUrl,
            cornerRadius: 8
        )
        .frame(height: 150)
    }
}

#Preview {
    NavigationStack {
        RecipesListView(recipes: [Recipe.sample])
    }
}

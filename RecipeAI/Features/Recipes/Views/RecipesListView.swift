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
        // Match Android `item_recipe.xml`: 80×80 thumbnail on the left, name /
        // description / meta row on the right.
        HStack(alignment: .top, spacing: 16) {
            RecipeImageView(
                recipeId: recipe.id,
                initialImageUrl: recipe.imageUrl,
                cornerRadius: 8
            )
            .frame(width: 80, height: 80)

            VStack(alignment: .leading, spacing: 4) {
                Text(recipe.name)
                    .font(.appHeadline)
                    .foregroundColor(.textPrimary)
                    .lineLimit(2)

                Text(recipe.shortDescription)
                    .font(.appSubheadline)
                    .foregroundColor(.textSecondary)
                    .lineLimit(2)

                HStack(spacing: 12) {
                    Label(recipe.cookingTime, systemImage: "clock")
                        .lineLimit(1)
                        .minimumScaleFactor(0.8)
                    Label(recipe.difficulty, systemImage: "chart.bar")
                        .lineLimit(1)
                        .minimumScaleFactor(0.8)
                }
                .font(.appCaption1)
                .foregroundColor(.brandGreen)
                .padding(.top, 4)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .cardStyle()
    }
}

#Preview {
    NavigationStack {
        RecipesListView(recipes: [Recipe.sample])
    }
}

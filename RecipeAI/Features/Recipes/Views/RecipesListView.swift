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
        Group {
            if let imageUrl = recipe.imageUrl, let url = URL(string: imageUrl) {
                AsyncImage(url: url) { image in
                    image
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                } placeholder: {
                    placeholderImage
                }
            } else if let path = recipe.capturedImagePath,
                      let uiImage = UIImage(contentsOfFile: path) {
                Image(uiImage: uiImage)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
            } else {
                placeholderImage
            }
        }
        .frame(height: 150)
        .clipped()
        .cornerRadius(8)
    }

    private var placeholderImage: some View {
        Rectangle()
            .fill(Color.brandGreenLight)
            .overlay {
                Image(systemName: "fork.knife")
                    .font(.title)
                    .foregroundColor(.brandGreen)
            }
    }
}

#Preview {
    NavigationStack {
        RecipesListView(recipes: [Recipe.sample])
    }
}

import SwiftUI
import SwiftData

struct RecipeDetailView: View {
    let recipe: Recipe

    @Environment(\.modelContext) private var modelContext
    @State private var isFavorite = false
    @State private var showShareSheet = false

    private var favoritesRepo: FavoritesRepository {
        FavoritesRepository(modelContext: modelContext)
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                // Recipe Image
                recipeImage

                // Recipe Info
                recipeInfo

                // Meta Info
                metaInfo

                // Ingredients
                if let ingredients = recipe.ingredients, !ingredients.isEmpty {
                    ingredientsSection(ingredients)
                }

                // Instructions
                if let instructions = recipe.instructions, !instructions.isEmpty {
                    instructionsSection(instructions)
                }
            }
            .padding(.bottom, 20)
        }
        .scrollIndicators(.hidden)
        .navigationTitle(recipe.name)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItemGroup(placement: .topBarTrailing) {
                Button {
                    toggleFavorite()
                } label: {
                    Image(systemName: isFavorite ? "heart.fill" : "heart")
                        .foregroundColor(isFavorite ? .red : .textPrimary)
                }

                Button {
                    shareRecipe()
                } label: {
                    Image(systemName: "square.and.arrow.up")
                }
            }
        }
        .sheet(isPresented: $showShareSheet) {
            ShareSheet(items: [createShareText()])
        }
        .onAppear {
            isFavorite = favoritesRepo.isFavorite(recipeId: recipe.id)
        }
    }

    // MARK: - Recipe Image

    private var recipeImage: some View {
        // Unified placeholder + bubble animation + auto-polling.
        RecipeImageView(
            recipeId: recipe.id,
            initialImageUrl: recipe.imageUrl,
            cornerRadius: 0
        )
        .frame(height: 250)
    }

    // MARK: - Recipe Info

    private var recipeInfo: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(recipe.name)
                .font(.appTitle2)
                .foregroundColor(.textPrimary)

            Text(recipe.fullDescription)
                .font(.appBody)
                .foregroundColor(.textSecondary)
        }
        .padding(.horizontal)
    }

    // MARK: - Meta Info

    private var metaInfo: some View {
        HStack(spacing: 16) {
            metaItem(icon: "clock", title: "Time", value: recipe.cookingTime)
            metaItem(icon: "person.2", title: "Servings", value: recipe.servings)
            metaItem(icon: "chart.bar", title: "Difficulty", value: recipe.difficulty)
        }
        .padding()
        .frame(maxWidth: .infinity)
        .background(Color.backgroundSecondary)
    }

    private func metaItem(icon: String, title: String, value: String) -> some View {
        VStack(spacing: 4) {
            Image(systemName: icon)
                .font(.title3)
                .foregroundColor(.brandGreen)

            Text(title)
                .font(.appCaption1)
                .foregroundColor(.textSecondary)

            Text(value)
                .font(.poppinsSemiBold(size: 14))
                .foregroundColor(.textPrimary)
                .lineLimit(2)
                .minimumScaleFactor(0.8)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
    }

    // MARK: - Ingredients Section

    private func ingredientsSection(_ ingredients: [String]) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Ingredients")
                .font(.appTitle3)
                .foregroundColor(.textPrimary)
                .padding(.horizontal)

            VStack(alignment: .leading, spacing: 8) {
                ForEach(ingredients, id: \.self) { ingredient in
                    HStack(alignment: .top, spacing: 12) {
                        Circle()
                            .fill(Color.brandGreen)
                            .frame(width: 8, height: 8)
                            .offset(y: 6)

                        Text(convertMeasurement(ingredient))
                            .font(.appBody)
                            .foregroundColor(.textPrimary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
            }
            .padding()
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Color.backgroundSecondary)
            .cornerRadius(12)
            .padding(.horizontal)
        }
    }

    // MARK: - Instructions Section

    private func instructionsSection(_ instructions: [String]) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Instructions")
                .font(.appTitle3)
                .foregroundColor(.textPrimary)
                .padding(.horizontal)

            VStack(alignment: .leading, spacing: 16) {
                ForEach(Array(instructions.enumerated()), id: \.offset) { index, instruction in
                    HStack(alignment: .top, spacing: 12) {
                        Text("\(index + 1)")
                            .font(.poppinsSemiBold(size: 14))
                            .foregroundColor(.white)
                            .frame(width: 28, height: 28)
                            .background(Color.brandGreen)
                            .clipShape(Circle())

                        Text(convertMeasurement(instruction))
                            .font(.appBody)
                            .foregroundColor(.textPrimary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
            }
            .padding()
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Color.backgroundSecondary)
            .cornerRadius(12)
            .padding(.horizontal)
        }
        .padding(.bottom, 32)
    }

    // MARK: - Actions

    private func toggleFavorite() {
        isFavorite.toggle()
        favoritesRepo.toggleFavorite(recipe)

        // Sync with backend
        if let userId = UserDefaultsManager.shared.userId {
            Task {
                if isFavorite {
                    await favoritesRepo.addFavoriteToBackend(recipe, userId: userId)
                } else {
                    await favoritesRepo.removeFavoriteFromBackend(recipeId: recipe.id, userId: userId)
                }
            }
        }
    }

    private func shareRecipe() {
        showShareSheet = true
    }

    private func createShareText() -> String {
        var text = "\(recipe.name)\n\n"
        text += "\(recipe.fullDescription)\n\n"
        text += "Cooking Time: \(recipe.cookingTime)\n"
        text += "Servings: \(recipe.servings)\n"
        text += "Difficulty: \(recipe.difficulty)\n\n"

        if let ingredients = recipe.ingredients {
            text += "Ingredients:\n"
            ingredients.forEach { text += "• \(convertMeasurement($0))\n" }
            text += "\n"
        }

        if let instructions = recipe.instructions {
            text += "Instructions:\n"
            instructions.enumerated().forEach { index, instruction in
                text += "\(index + 1). \(convertMeasurement(instruction))\n"
            }
        }

        text += "\n\nGenerated with RecipeAI"
        return text
    }

    private func convertMeasurement(_ text: String) -> String {
        let measurementUnit = UserDefaultsManager.shared.measurementUnits
        if measurementUnit == .imperial {
            return MeasurementConverter.convertToImperial(text)
        }
        return text
    }
}

// MARK: - Share Sheet

struct ShareSheet: UIViewControllerRepresentable {
    let items: [Any]

    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: items, applicationActivities: nil)
    }

    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}

// MARK: - Measurement Converter

enum MeasurementConverter {
    static func convertToImperial(_ text: String) -> String {
        var result = text

        // Convert grams to ounces
        let gramPattern = #"(\d+(?:\.\d+)?)\s*g(?:rams?)?\b"#
        if let regex = try? NSRegularExpression(pattern: gramPattern, options: .caseInsensitive) {
            let range = NSRange(result.startIndex..., in: result)
            result = regex.stringByReplacingMatches(in: result, options: [], range: range, withTemplate: { match in
                if let grams = Double(match) {
                    let ounces = grams / 28.35
                    return String(format: "%.1f oz", ounces)
                }
                return match
            })
        }

        // Convert ml to fl oz
        let mlPattern = #"(\d+(?:\.\d+)?)\s*ml\b"#
        if let regex = try? NSRegularExpression(pattern: mlPattern, options: .caseInsensitive) {
            let range = NSRange(result.startIndex..., in: result)
            result = regex.stringByReplacingMatches(in: result, options: [], range: range, withTemplate: { match in
                if let ml = Double(match) {
                    let flOz = ml / 29.574
                    return String(format: "%.1f fl oz", flOz)
                }
                return match
            })
        }

        // Convert celsius to fahrenheit
        let celsiusPattern = #"(\d+(?:\.\d+)?)\s*°?C\b"#
        if let regex = try? NSRegularExpression(pattern: celsiusPattern, options: .caseInsensitive) {
            let range = NSRange(result.startIndex..., in: result)
            result = regex.stringByReplacingMatches(in: result, options: [], range: range, withTemplate: { match in
                if let celsius = Double(match) {
                    let fahrenheit = celsius * 9/5 + 32
                    return String(format: "%.0f°F", fahrenheit)
                }
                return match
            })
        }

        return result
    }
}

extension NSRegularExpression {
    func stringByReplacingMatches(
        in string: String,
        options: MatchingOptions,
        range: NSRange,
        withTemplate template: (String) -> String
    ) -> String {
        var result = string
        let matches = self.matches(in: string, options: options, range: range).reversed()

        for match in matches {
            guard let range = Range(match.range(at: 1), in: result) else { continue }
            let matchString = String(result[range])
            let replacement = template(matchString)

            if let fullRange = Range(match.range, in: result) {
                result.replaceSubrange(fullRange, with: replacement)
            }
        }

        return result
    }
}

#Preview {
    NavigationStack {
        RecipeDetailView(recipe: Recipe.sample)
    }
}

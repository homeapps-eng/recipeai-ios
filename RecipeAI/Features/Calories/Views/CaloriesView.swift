import SwiftUI

struct CaloriesView: View {
    let caloriesResponse: CaloriesResponse
    @State private var showShareSheet = false

    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                // Header Card
                headerCard

                // Ingredients List
                if let ingredients = caloriesResponse.ingredients, !ingredients.isEmpty {
                    ingredientsList(ingredients)
                }
            }
            .padding()
        }
        .navigationTitle("Calorie Analysis")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    showShareSheet = true
                } label: {
                    Image(systemName: "square.and.arrow.up")
                }
            }
        }
        .sheet(isPresented: $showShareSheet) {
            ShareSheet(items: [createShareText()])
        }
    }

    // MARK: - Header Card

    private var headerCard: some View {
        VStack(spacing: 16) {
            // Meal Name
            if let mealName = caloriesResponse.mealName {
                Text(mealName)
                    .font(.appTitle2)
                    .foregroundColor(.textPrimary)
                    .multilineTextAlignment(.center)
            }

            // Total Calories
            VStack(spacing: 4) {
                Text("\(caloriesResponse.totalCalories)")
                    .font(.system(size: 48, weight: .bold, design: .rounded))
                    .foregroundColor(.brandGreen)

                Text("Total Calories")
                    .font(.appSubheadline)
                    .foregroundColor(.textSecondary)
            }

            // Divider
            Divider()

            // Ingredients Count
            if let ingredients = caloriesResponse.ingredients {
                HStack {
                    Image(systemName: "list.bullet")
                        .foregroundColor(.brandGreen)

                    Text("\(ingredients.count) ingredients detected")
                        .font(.appSubheadline)
                        .foregroundColor(.textSecondary)
                }
            }
        }
        .padding(24)
        .background(Color.cardBackground)
        .cornerRadius(16)
        .shadow(color: .black.opacity(0.1), radius: 8, x: 0, y: 4)
    }

    // MARK: - Ingredients List

    private func ingredientsList(_ ingredients: [CalorieIngredient]) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Breakdown")
                .font(.appTitle3)
                .foregroundColor(.textPrimary)

            ForEach(ingredients) { ingredient in
                ingredientRow(ingredient)
            }
        }
    }

    private func ingredientRow(_ ingredient: CalorieIngredient) -> some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text(ingredient.name)
                    .font(.appHeadline)
                    .foregroundColor(.textPrimary)

                Text(ingredient.amount)
                    .font(.appCaption1)
                    .foregroundColor(.textSecondary)
            }

            Spacer()

            Text("\(ingredient.calories) cal")
                .font(.poppinsSemiBold(size: 16))
                .foregroundColor(.brandGreen)
        }
        .padding()
        .background(Color.backgroundSecondary)
        .cornerRadius(12)
    }

    // MARK: - Share

    private func createShareText() -> String {
        var text = "Calorie Analysis\n\n"

        if let mealName = caloriesResponse.mealName {
            text += "Meal: \(mealName)\n"
        }

        text += "Total Calories: \(caloriesResponse.totalCalories)\n\n"

        if let ingredients = caloriesResponse.ingredients {
            text += "Breakdown:\n"
            for ingredient in ingredients {
                text += "• \(ingredient.name) (\(ingredient.amount)): \(ingredient.calories) cal\n"
            }
        }

        text += "\nCalculated with RecipeAI"
        return text
    }
}

#Preview {
    NavigationStack {
        CaloriesView(caloriesResponse: CaloriesResponse(
            success: true,
            message: nil,
            totalCalories: 450,
            ingredients: [
                CalorieIngredient(name: "Chicken Breast", calories: 165, amount: "100g"),
                CalorieIngredient(name: "Brown Rice", calories: 215, amount: "1 cup"),
                CalorieIngredient(name: "Broccoli", calories: 55, amount: "1 cup"),
                CalorieIngredient(name: "Olive Oil", calories: 15, amount: "1 tsp")
            ],
            mealName: "Grilled Chicken with Rice"
        ))
    }
}

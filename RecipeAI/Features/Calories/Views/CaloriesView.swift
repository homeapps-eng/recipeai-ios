import SwiftUI

struct CaloriesView: View {
    let caloriesResponse: CaloriesResponse
    @State private var showShareSheet = false

    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                // Header Card
                headerCard

                // Macronutrient Summary
                if let nutrition = caloriesResponse.totalNutrition {
                    macronutrientCard(nutrition)
                }

                // Health Insight
                if let insight = caloriesResponse.healthInsight, !insight.isEmpty {
                    healthInsightCard(insight)
                }

                // Nutrition Highlights
                if let nutrition = caloriesResponse.totalNutrition {
                    nutritionHighlightsCard(nutrition)
                }

                // Ingredients List
                if let ingredients = caloriesResponse.ingredients, !ingredients.isEmpty {
                    ingredientsList(ingredients)
                }
            }
            .padding()
        }
        .navigationTitle("Nutrition Analysis")
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
        }
        .padding(24)
        .frame(maxWidth: .infinity)
        .background(Color.cardBackground)
        .cornerRadius(16)
        .shadow(color: .black.opacity(0.1), radius: 8, x: 0, y: 4)
    }

    // MARK: - Macronutrient Card

    private func macronutrientCard(_ nutrition: NutritionInfo) -> some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Macronutrients")
                .font(.appTitle3)
                .foregroundColor(.textPrimary)

            HStack(spacing: 12) {
                macroItem(
                    name: "Protein",
                    value: nutrition.protein,
                    unit: "g",
                    color: .blue,
                    icon: "figure.strengthtraining.traditional"
                )

                macroItem(
                    name: "Carbs",
                    value: nutrition.carbs,
                    unit: "g",
                    color: .orange,
                    icon: "bolt.fill"
                )

                macroItem(
                    name: "Fat",
                    value: nutrition.fat,
                    unit: "g",
                    color: .yellow,
                    icon: "drop.fill"
                )
            }
        }
        .padding()
        .background(Color.cardBackground)
        .cornerRadius(16)
        .shadow(color: .black.opacity(0.05), radius: 4, x: 0, y: 2)
    }

    private func macroItem(name: String, value: Double, unit: String, color: Color, icon: String) -> some View {
        VStack(spacing: 8) {
            ZStack {
                Circle()
                    .fill(color.opacity(0.15))
                    .frame(width: 50, height: 50)

                Image(systemName: icon)
                    .font(.title3)
                    .foregroundColor(color)
            }

            Text(String(format: "%.1f%@", value, unit))
                .font(.poppinsSemiBold(size: 16))
                .foregroundColor(.textPrimary)

            Text(name)
                .font(.appCaption1)
                .foregroundColor(.textSecondary)
        }
        .frame(maxWidth: .infinity)
    }

    // MARK: - Health Insight Card

    private func healthInsightCard(_ insight: String) -> some View {
        HStack(spacing: 12) {
            Image(systemName: "lightbulb.fill")
                .font(.title2)
                .foregroundColor(.yellow)

            Text(insight)
                .font(.appBody)
                .foregroundColor(.textPrimary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.yellow.opacity(0.1))
        .cornerRadius(12)
    }

    // MARK: - Nutrition Highlights Card

    private func nutritionHighlightsCard(_ nutrition: NutritionInfo) -> some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Nutrition Highlights")
                .font(.appTitle3)
                .foregroundColor(.textPrimary)

            VStack(spacing: 12) {
                nutritionRow(
                    icon: "leaf.fill",
                    name: "Fiber",
                    value: String(format: "%.1fg", nutrition.fiber),
                    color: .green
                )

                nutritionRow(
                    icon: "cube.fill",
                    name: "Sugar",
                    value: String(format: "%.1fg", nutrition.sugar),
                    color: .pink
                )

                nutritionRow(
                    icon: "drop.triangle.fill",
                    name: "Sodium",
                    value: String(format: "%.0fmg", nutrition.sodium),
                    color: .purple
                )
            }
        }
        .padding()
        .background(Color.cardBackground)
        .cornerRadius(16)
        .shadow(color: .black.opacity(0.05), radius: 4, x: 0, y: 2)
    }

    private func nutritionRow(icon: String, name: String, value: String, color: Color) -> some View {
        HStack {
            Image(systemName: icon)
                .font(.body)
                .foregroundColor(color)
                .frame(width: 24)

            Text(name)
                .font(.appBody)
                .foregroundColor(.textPrimary)

            Spacer()

            Text(value)
                .font(.poppinsSemiBold(size: 15))
                .foregroundColor(.textPrimary)
        }
    }

    // MARK: - Ingredients List

    private func ingredientsList(_ ingredients: [CalorieIngredient]) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Ingredients Breakdown")
                    .font(.appTitle3)
                    .foregroundColor(.textPrimary)

                Spacer()

                Text("\(ingredients.count) items")
                    .font(.appCaption1)
                    .foregroundColor(.textSecondary)
            }

            ForEach(ingredients) { ingredient in
                ingredientRow(ingredient)
            }
        }
    }

    private func ingredientRow(_ ingredient: CalorieIngredient) -> some View {
        VStack(spacing: 8) {
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

            // Ingredient macros (compact view)
            if let nutrition = ingredient.nutrition {
                HStack(spacing: 16) {
                    compactMacro(label: "P", value: nutrition.protein, color: .blue)
                    compactMacro(label: "C", value: nutrition.carbs, color: .orange)
                    compactMacro(label: "F", value: nutrition.fat, color: .yellow)
                    Spacer()
                }
            }
        }
        .padding()
        .background(Color.backgroundSecondary)
        .cornerRadius(12)
    }

    private func compactMacro(label: String, value: Double, color: Color) -> some View {
        HStack(spacing: 4) {
            Text(label)
                .font(.appCaption2)
                .foregroundColor(color)
                .fontWeight(.bold)

            Text(String(format: "%.1fg", value))
                .font(.appCaption1)
                .foregroundColor(.textSecondary)
        }
    }

    // MARK: - Share

    private func createShareText() -> String {
        var text = "Nutrition Analysis\n\n"

        if let mealName = caloriesResponse.mealName {
            text += "\(mealName)\n"
        }

        text += "Total Calories: \(caloriesResponse.totalCalories)\n\n"

        if let nutrition = caloriesResponse.totalNutrition {
            text += "Macronutrients:\n"
            text += "• Protein: \(String(format: "%.1f", nutrition.protein))g\n"
            text += "• Carbs: \(String(format: "%.1f", nutrition.carbs))g\n"
            text += "• Fat: \(String(format: "%.1f", nutrition.fat))g\n"
            text += "• Fiber: \(String(format: "%.1f", nutrition.fiber))g\n"
            text += "• Sugar: \(String(format: "%.1f", nutrition.sugar))g\n"
            text += "• Sodium: \(String(format: "%.0f", nutrition.sodium))mg\n\n"
        }

        if let insight = caloriesResponse.healthInsight {
            text += "💡 \(insight)\n\n"
        }

        if let ingredients = caloriesResponse.ingredients {
            text += "Ingredients Breakdown:\n"
            for ingredient in ingredients {
                text += "• \(ingredient.name) (\(ingredient.amount)): \(ingredient.calories) cal\n"
            }
        }

        text += "\nAnalyzed with RecipeAI"
        return text
    }
}

#Preview {
    NavigationStack {
        CaloriesView(caloriesResponse: CaloriesResponse(
            success: true,
            message: nil,
            mealName: "Grilled Chicken with Rice",
            totalCalories: 650,
            totalNutrition: NutritionInfo(
                protein: 45.0,
                carbs: 55.0,
                fat: 18.0,
                fiber: 6.5,
                sugar: 4.0,
                sodium: 720.0
            ),
            ingredients: [
                CalorieIngredient(
                    name: "Grilled Chicken Breast",
                    calories: 280,
                    amount: "200g",
                    nutrition: NutritionInfo(protein: 42.0, carbs: 0, fat: 6.0, fiber: 0, sugar: 0, sodium: 150)
                ),
                CalorieIngredient(
                    name: "Brown Rice",
                    calories: 280,
                    amount: "1 cup cooked",
                    nutrition: NutritionInfo(protein: 5.0, carbs: 52.0, fat: 2.0, fiber: 3.5, sugar: 0.5, sodium: 10)
                ),
                CalorieIngredient(
                    name: "Steamed Broccoli",
                    calories: 55,
                    amount: "1 cup",
                    nutrition: NutritionInfo(protein: 3.7, carbs: 11.0, fat: 0.6, fiber: 5.0, sugar: 2.0, sodium: 64)
                ),
                CalorieIngredient(
                    name: "Olive Oil",
                    calories: 40,
                    amount: "1 tsp",
                    nutrition: NutritionInfo(protein: 0, carbs: 0, fat: 4.5, fiber: 0, sugar: 0, sodium: 0)
                )
            ],
            healthInsight: "High protein meal with good fiber content - excellent for muscle recovery and sustained energy."
        ))
    }
}

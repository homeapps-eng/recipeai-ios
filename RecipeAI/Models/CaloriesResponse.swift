import Foundation

// MARK: - Nutrition Info

struct NutritionInfo: Codable {
    let protein: Double  // grams
    let carbs: Double    // grams
    let fat: Double      // grams
    let fiber: Double    // grams
    let sugar: Double    // grams
    let sodium: Double   // milligrams

    static let zero = NutritionInfo(protein: 0, carbs: 0, fat: 0, fiber: 0, sugar: 0, sodium: 0)
}

// MARK: - Calories Response

struct CaloriesResponse: Codable {
    let success: Bool
    let message: String?
    let mealName: String?
    let totalCalories: Int
    let totalNutrition: NutritionInfo?
    let ingredients: [CalorieIngredient]?
    let healthInsight: String?
}

// MARK: - Calorie Ingredient

struct CalorieIngredient: Codable, Identifiable {
    let name: String
    let calories: Int
    let amount: String
    let nutrition: NutritionInfo?

    var id: String { name }
}

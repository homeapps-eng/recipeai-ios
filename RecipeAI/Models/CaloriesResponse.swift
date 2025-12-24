import Foundation

// MARK: - Calories Response

struct CaloriesResponse: Codable {
    let success: Bool
    let message: String?
    let totalCalories: Int
    let ingredients: [CalorieIngredient]?
    let mealName: String?
}

// MARK: - Calorie Ingredient

struct CalorieIngredient: Codable, Identifiable {
    let name: String
    let calories: Int
    let amount: String

    var id: String { name }
}

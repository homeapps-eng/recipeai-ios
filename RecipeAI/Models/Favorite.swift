import Foundation
import SwiftData

// MARK: - Favorite (API Model)

struct Favorite: Codable, Identifiable {
    let id: String
    let userId: String
    let recipeId: String
    let recipe: Recipe?
    let dateSaved: String
    let capturedImagePath: String?
}

// MARK: - Add Favorite Request

struct AddFavoriteRequest: Codable {
    let recipeId: String
    let recipe: Recipe?
    let capturedImagePath: String?
}

// MARK: - Favorites Response

struct FavoritesResponse: Codable {
    let favorites: [Favorite]
    let success: Bool
    let message: String?
}

// MARK: - SwiftData Favorite Recipe Model

@Model
final class FavoriteRecipe {
    @Attribute(.unique) var recipeId: String
    var name: String
    var shortDescription: String
    var fullDescription: String
    var imageUrl: String?
    var cookingTime: String
    var servings: String
    var difficulty: String
    var ingredients: [String]
    var instructions: [String]
    var capturedImagePath: String?
    var dateSaved: Date

    init(from recipe: Recipe) {
        self.recipeId = recipe.id
        self.name = recipe.name
        self.shortDescription = recipe.shortDescription
        self.fullDescription = recipe.fullDescription
        self.imageUrl = recipe.imageUrl
        self.cookingTime = recipe.cookingTime
        self.servings = recipe.servings
        self.difficulty = recipe.difficulty
        self.ingredients = recipe.ingredients ?? []
        self.instructions = recipe.instructions ?? []
        self.capturedImagePath = recipe.capturedImagePath
        self.dateSaved = Date()
    }

    func toRecipe() -> Recipe {
        Recipe(
            id: recipeId,
            name: name,
            shortDescription: shortDescription,
            fullDescription: fullDescription,
            imageUrl: imageUrl,
            cookingTime: cookingTime,
            servings: servings,
            difficulty: difficulty,
            ingredients: ingredients,
            instructions: instructions,
            capturedImagePath: capturedImagePath
        )
    }
}

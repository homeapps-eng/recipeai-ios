import Foundation

// MARK: - Recipe

struct Recipe: Codable, Identifiable, Hashable {
    let id: String
    let name: String
    let shortDescription: String
    let fullDescription: String
    let imageUrl: String?
    let cookingTime: String
    let servings: String
    let difficulty: String
    let ingredients: [String]?
    let instructions: [String]?
    var capturedImagePath: String?

    enum CodingKeys: String, CodingKey {
        case id, name, shortDescription, fullDescription
        case imageUrl, cookingTime, servings, difficulty
        case ingredients, instructions, capturedImagePath
    }

    init(
        id: String,
        name: String,
        shortDescription: String,
        fullDescription: String,
        imageUrl: String?,
        cookingTime: String,
        servings: String,
        difficulty: String,
        ingredients: [String]?,
        instructions: [String]?,
        capturedImagePath: String? = nil
    ) {
        self.id = id
        self.name = name
        self.shortDescription = shortDescription
        self.fullDescription = fullDescription
        self.imageUrl = imageUrl
        self.cookingTime = cookingTime
        self.servings = servings
        self.difficulty = difficulty
        self.ingredients = ingredients
        self.instructions = instructions
        self.capturedImagePath = capturedImagePath
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)

        id = try container.decode(String.self, forKey: .id)
        name = try container.decode(String.self, forKey: .name)
        shortDescription = try container.decodeIfPresent(String.self, forKey: .shortDescription) ?? ""
        fullDescription = try container.decodeIfPresent(String.self, forKey: .fullDescription) ?? ""
        imageUrl = try container.decodeIfPresent(String.self, forKey: .imageUrl)
        cookingTime = try container.decodeIfPresent(String.self, forKey: .cookingTime) ?? ""
        servings = try container.decodeIfPresent(String.self, forKey: .servings) ?? ""
        difficulty = try container.decodeIfPresent(String.self, forKey: .difficulty) ?? ""
        ingredients = try container.decodeIfPresent([String].self, forKey: .ingredients)
        instructions = try container.decodeIfPresent([String].self, forKey: .instructions)
        capturedImagePath = try container.decodeIfPresent(String.self, forKey: .capturedImagePath)
    }

    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }

    static func == (lhs: Recipe, rhs: Recipe) -> Bool {
        lhs.id == rhs.id
    }
}

// MARK: - Recipe Response

struct RecipeResponse: Codable {
    let recipes: [GeneratedRecipe]?
    let success: Bool
    let message: String?
}

struct GeneratedRecipe: Codable {
    let recipe: Recipe
    let imageUrl: String?
}

// MARK: - Single Recipe Response (for daily recipe)

struct SingleRecipeResponse: Codable {
    let recipes: [GeneratedRecipe]?
    let success: Bool
    let message: String?

    // Convenience property to get first recipe
    var recipe: Recipe? {
        recipes?.first?.recipe
    }
}

// MARK: - Async Image Polling

struct RecipeImagesResponse: Codable {
    let success: Bool
    let images: [RecipeImageItem]?
}

struct RecipeImageItem: Codable {
    let id: String
    let imageUrl: String?
}

// MARK: - Recipe Difficulty

enum RecipeDifficulty: String, CaseIterable {
    case easy = "Easy"
    case medium = "Medium"
    case hard = "Hard"

    var icon: String {
        switch self {
        case .easy: return "star"
        case .medium: return "star.leadinghalf.filled"
        case .hard: return "star.fill"
        }
    }

    var color: String {
        switch self {
        case .easy: return "00A86B"
        case .medium: return "FF9800"
        case .hard: return "F44336"
        }
    }
}

// MARK: - Sample Data

extension Recipe {
    static let sample = Recipe(
        id: "sample-1",
        name: "Spaghetti Carbonara",
        shortDescription: "Classic Italian pasta dish",
        fullDescription: "A rich and creamy Italian pasta dish made with eggs, cheese, pancetta, and black pepper.",
        imageUrl: nil,
        cookingTime: "30 mins",
        servings: "4",
        difficulty: "Medium",
        ingredients: [
            "400g spaghetti",
            "200g pancetta",
            "4 egg yolks",
            "100g Parmesan cheese",
            "Black pepper",
            "Salt"
        ],
        instructions: [
            "Cook spaghetti according to package directions",
            "Fry pancetta until crispy",
            "Mix egg yolks with grated Parmesan",
            "Combine hot pasta with pancetta",
            "Add egg mixture and toss quickly",
            "Season with black pepper and serve"
        ]
    )
}

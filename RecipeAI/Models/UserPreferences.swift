import Foundation

// MARK: - User Preferences

struct UserPreferences: Codable {
    var userId: String?
    var categories: [String]?
    var cuisines: [String]?
    var keywords: [String]?
    var dietaryRestrictions: [String]?
    var allergies: [String]?

    init(
        userId: String? = nil,
        categories: [String]? = nil,
        cuisines: [String]? = nil,
        keywords: [String]? = nil,
        dietaryRestrictions: [String]? = nil,
        allergies: [String]? = nil
    ) {
        self.userId = userId
        self.categories = categories
        self.cuisines = cuisines
        self.keywords = keywords
        self.dietaryRestrictions = dietaryRestrictions
        self.allergies = allergies
    }
}

// MARK: - Food Categories

enum FoodCategory: String, CaseIterable, Identifiable {
    case meat = "meat"
    case seafood = "seafood"
    case vegetables = "vegetables"
    case coffeeTea = "coffee_tea"
    case desserts = "desserts"
    case nuts = "nuts"
    case fruits = "fruits"
    case dairy = "dairy"

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .meat: return "Meat"
        case .seafood: return "Seafood"
        case .vegetables: return "Vegetables"
        case .coffeeTea: return "Coffee & Tea"
        case .desserts: return "Desserts"
        case .nuts: return "Nuts"
        case .fruits: return "Fruits"
        case .dairy: return "Dairy"
        }
    }

    var imageName: String {
        switch self {
        case .meat: return "meat"
        case .seafood: return "seafood"
        case .vegetables: return "vegetables"
        case .coffeeTea: return "coffee_tea"
        case .desserts: return "desserts"
        case .nuts: return "nuts"
        case .fruits: return "fruits"
        case .dairy: return "dairy"
        }
    }

    var systemIcon: String {
        switch self {
        case .meat: return "fork.knife"
        case .seafood: return "fish"
        case .vegetables: return "leaf"
        case .coffeeTea: return "cup.and.saucer"
        case .desserts: return "birthday.cake"
        case .nuts: return "leaf.circle"
        case .fruits: return "apple.logo"
        case .dairy: return "drop.fill"
        }
    }
}

// MARK: - Cuisines

enum Cuisine: String, CaseIterable, Identifiable {
    case italian = "Italian"
    case mexican = "Mexican"
    case chinese = "Chinese"
    case indian = "Indian"
    case japanese = "Japanese"
    case thai = "Thai"
    case french = "French"
    case mediterranean = "Mediterranean"
    case american = "American"
    case korean = "Korean"
    case vietnamese = "Vietnamese"
    case greek = "Greek"
    case spanish = "Spanish"
    case middleEastern = "Middle Eastern"
    case caribbean = "Caribbean"

    var id: String { rawValue }
}

// MARK: - Dietary Restrictions

enum DietaryRestriction: String, CaseIterable, Identifiable {
    case vegetarian = "Vegetarian"
    case vegan = "Vegan"
    case glutenFree = "Gluten-Free"
    case dairyFree = "Dairy-Free"
    case keto = "Keto"
    case paleo = "Paleo"
    case lowCarb = "Low Carb"
    case lowFat = "Low Fat"
    case halal = "Halal"
    case kosher = "Kosher"

    var id: String { rawValue }
}

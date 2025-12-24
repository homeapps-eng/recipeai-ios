import Foundation
import Combine

final class UserDefaultsManager: ObservableObject {
    static let shared = UserDefaultsManager()

    private let defaults = UserDefaults.standard

    // MARK: - Keys

    private enum Keys {
        // User
        static let isSignedIn = "is_signed_in"
        static let userId = "user_id"
        static let username = "username"
        static let userEmail = "user_email"
        static let avatarUrl = "avatar_url"

        // Preferences
        static let preferencesCompleted = "preferences_completed"
        static let likedCategories = "liked_categories"
        static let selectedCuisines = "selected_cuisines"
        static let keywords = "keywords"
        static let dietaryRestrictions = "dietary_restrictions"
        static let allergies = "allergies"

        // Settings
        static let pushNotifications = "push_notifications"
        static let recipeSuggestions = "recipe_suggestions"
        static let measurementUnits = "measurement_units"

        // Subscription
        static let isPremium = "is_premium"
        static let subscriptionStatus = "subscription_status"
        static let subscriptionLastUpdate = "subscription_last_update"

        // Usage Tracking
        static let lastResetDate = "last_reset_date"
        static let dailyRecipeCount = "daily_recipe_count"
        static let dailyButtonPressCount = "daily_button_press_count"
        static let totalHomeRecipeLoads = "total_home_recipe_loads"
    }

    // MARK: - User Properties

    @Published var isSignedIn: Bool {
        didSet { defaults.set(isSignedIn, forKey: Keys.isSignedIn) }
    }

    @Published var userId: String? {
        didSet { defaults.set(userId, forKey: Keys.userId) }
    }

    @Published var username: String? {
        didSet { defaults.set(username, forKey: Keys.username) }
    }

    @Published var userEmail: String? {
        didSet { defaults.set(userEmail, forKey: Keys.userEmail) }
    }

    @Published var avatarUrl: String? {
        didSet { defaults.set(avatarUrl, forKey: Keys.avatarUrl) }
    }

    // MARK: - Preference Properties

    @Published var preferencesCompleted: Bool {
        didSet { defaults.set(preferencesCompleted, forKey: Keys.preferencesCompleted) }
    }

    @Published var likedCategories: Set<String> {
        didSet { defaults.set(Array(likedCategories), forKey: Keys.likedCategories) }
    }

    @Published var selectedCuisines: Set<String> {
        didSet { defaults.set(Array(selectedCuisines), forKey: Keys.selectedCuisines) }
    }

    @Published var keywords: [String] {
        didSet { defaults.set(keywords, forKey: Keys.keywords) }
    }

    @Published var dietaryRestrictions: [String] {
        didSet { defaults.set(dietaryRestrictions, forKey: Keys.dietaryRestrictions) }
    }

    @Published var allergies: [String] {
        didSet { defaults.set(allergies, forKey: Keys.allergies) }
    }

    // MARK: - Settings Properties

    @Published var pushNotificationsEnabled: Bool {
        didSet { defaults.set(pushNotificationsEnabled, forKey: Keys.pushNotifications) }
    }

    @Published var recipeSuggestionsEnabled: Bool {
        didSet { defaults.set(recipeSuggestionsEnabled, forKey: Keys.recipeSuggestions) }
    }

    @Published var measurementUnits: MeasurementUnit {
        didSet { defaults.set(measurementUnits.rawValue, forKey: Keys.measurementUnits) }
    }

    // MARK: - Subscription Properties

    @Published var isPremium: Bool {
        didSet { defaults.set(isPremium, forKey: Keys.isPremium) }
    }

    // MARK: - Initialization

    private init() {
        // User
        self.isSignedIn = defaults.bool(forKey: Keys.isSignedIn)
        self.userId = defaults.string(forKey: Keys.userId)
        self.username = defaults.string(forKey: Keys.username)
        self.userEmail = defaults.string(forKey: Keys.userEmail)
        self.avatarUrl = defaults.string(forKey: Keys.avatarUrl)

        // Preferences
        self.preferencesCompleted = defaults.bool(forKey: Keys.preferencesCompleted)
        self.likedCategories = Set(defaults.stringArray(forKey: Keys.likedCategories) ?? [])
        self.selectedCuisines = Set(defaults.stringArray(forKey: Keys.selectedCuisines) ?? [])
        self.keywords = defaults.stringArray(forKey: Keys.keywords) ?? []
        self.dietaryRestrictions = defaults.stringArray(forKey: Keys.dietaryRestrictions) ?? []
        self.allergies = defaults.stringArray(forKey: Keys.allergies) ?? []

        // Settings
        self.pushNotificationsEnabled = defaults.object(forKey: Keys.pushNotifications) as? Bool ?? true
        self.recipeSuggestionsEnabled = defaults.object(forKey: Keys.recipeSuggestions) as? Bool ?? true
        let unitString = defaults.string(forKey: Keys.measurementUnits) ?? MeasurementUnit.metric.rawValue
        self.measurementUnits = MeasurementUnit(rawValue: unitString) ?? .metric

        // Subscription
        self.isPremium = defaults.bool(forKey: Keys.isPremium)
    }

    // MARK: - Methods

    func saveUserInfo(userId: String, username: String, email: String, avatarUrl: String? = nil) {
        self.isSignedIn = true
        self.userId = userId
        self.username = username
        self.userEmail = email
        self.avatarUrl = avatarUrl
    }

    func clearAll() {
        // Clear all stored values
        let domain = Bundle.main.bundleIdentifier!
        defaults.removePersistentDomain(forName: domain)

        // Reset published properties
        isSignedIn = false
        userId = nil
        username = nil
        userEmail = nil
        avatarUrl = nil
        preferencesCompleted = false
        likedCategories = []
        selectedCuisines = []
        keywords = []
        dietaryRestrictions = []
        allergies = []
        pushNotificationsEnabled = true
        recipeSuggestionsEnabled = true
        measurementUnits = .metric
        isPremium = false
    }

    // MARK: - User Preferences

    func savePreferences(_ preferences: UserPreferences) {
        likedCategories = Set(preferences.categories ?? [])
        selectedCuisines = Set(preferences.cuisines ?? [])
        keywords = preferences.keywords ?? []
        dietaryRestrictions = preferences.dietaryRestrictions ?? []
        allergies = preferences.allergies ?? []
        preferencesCompleted = true
    }

    func getPreferences() -> UserPreferences {
        UserPreferences(
            userId: userId,
            categories: Array(likedCategories),
            cuisines: Array(selectedCuisines),
            keywords: keywords,
            dietaryRestrictions: dietaryRestrictions,
            allergies: allergies
        )
    }
}

// MARK: - Measurement Unit

enum MeasurementUnit: String, CaseIterable {
    case metric = "Metric"
    case imperial = "Imperial"
}

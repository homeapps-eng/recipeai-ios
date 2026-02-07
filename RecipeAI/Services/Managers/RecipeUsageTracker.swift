import Foundation
import Combine

@MainActor
final class RecipeUsageTracker: ObservableObject {
    static let shared = RecipeUsageTracker()

    private let defaults = UserDefaults.standard

    private enum Keys {
        static let lastResetDate = "recipe_usage_last_reset_date"
        static let dailyRecipeCount = "daily_recipe_count"
        static let dailyButtonPressCount = "daily_button_press_count"
        static let dailyCaloriesCount = "daily_calories_count"
        static let totalHomeRecipeLoads = "total_home_recipe_loads"
    }

    @Published private(set) var dailyRecipeCount: Int
    @Published private(set) var dailyButtonPressCount: Int
    @Published private(set) var dailyCaloriesCount: Int
    @Published private(set) var totalHomeRecipeLoads: Int

    private init() {
        self.dailyRecipeCount = defaults.integer(forKey: Keys.dailyRecipeCount)
        self.dailyButtonPressCount = defaults.integer(forKey: Keys.dailyButtonPressCount)
        self.dailyCaloriesCount = defaults.integer(forKey: Keys.dailyCaloriesCount)
        self.totalHomeRecipeLoads = defaults.integer(forKey: Keys.totalHomeRecipeLoads)
        checkAndResetIfNeeded()
    }

    // MARK: - Daily Limits

    var maxDailyRecipes: Int {
        AppConfig.maxDailyRecipes
    }

    var maxDailyButtonPresses: Int {
        AppConfig.maxDailyButtonPresses
    }

    var maxDailyCalories: Int {
        AppConfig.maxDailyCalories
    }

    var maxFreeHomeRecipeLoads: Int {
        AppConfig.maxFreeHomeRecipeLoads
    }

    // MARK: - Remaining Counts

    var remainingRecipes: Int {
        max(0, maxDailyRecipes - dailyRecipeCount)
    }

    var remainingButtonPresses: Int {
        max(0, maxDailyButtonPresses - dailyButtonPressCount)
    }

    var remainingCalories: Int {
        max(0, maxDailyCalories - dailyCaloriesCount)
    }

    var remainingHomeRecipeLoads: Int {
        if SubscriptionManager.shared.isPremium {
            return Int.max
        }
        return max(0, maxFreeHomeRecipeLoads - totalHomeRecipeLoads)
    }

    // MARK: - Check Availability

    var canGenerateRecipe: Bool {
        if SubscriptionManager.shared.isPremium {
            return true
        }
        return remainingRecipes > 0 && remainingButtonPresses > 0
    }

    var canCalculateCalories: Bool {
        if SubscriptionManager.shared.isPremium {
            return true
        }
        return remainingCalories > 0
    }

    var canLoadHomeRecipe: Bool {
        if SubscriptionManager.shared.isPremium {
            return true
        }
        return remainingHomeRecipeLoads > 0
    }

    // MARK: - Increment Counts

    func incrementRecipeCount(by count: Int = 1) {
        checkAndResetIfNeeded()
        dailyRecipeCount += count
        defaults.set(dailyRecipeCount, forKey: Keys.dailyRecipeCount)
    }

    func incrementButtonPressCount() {
        checkAndResetIfNeeded()
        dailyButtonPressCount += 1
        defaults.set(dailyButtonPressCount, forKey: Keys.dailyButtonPressCount)
    }

    func incrementCaloriesCount() {
        checkAndResetIfNeeded()
        dailyCaloriesCount += 1
        defaults.set(dailyCaloriesCount, forKey: Keys.dailyCaloriesCount)
    }

    func incrementHomeRecipeLoads() {
        totalHomeRecipeLoads += 1
        defaults.set(totalHomeRecipeLoads, forKey: Keys.totalHomeRecipeLoads)
    }

    /// Grant extra home recipe loads (after watching an ad) - resets counter
    func grantExtraHomeRecipeLoad() {
        totalHomeRecipeLoads = 0
        defaults.set(totalHomeRecipeLoads, forKey: Keys.totalHomeRecipeLoads)
    }

    /// Reset recipe generation limits (after watching an ad)
    func grantExtraRecipeGeneration() {
        // Reset to allow full daily limit again
        dailyRecipeCount = 0
        dailyButtonPressCount = 0
        defaults.set(dailyRecipeCount, forKey: Keys.dailyRecipeCount)
        defaults.set(dailyButtonPressCount, forKey: Keys.dailyButtonPressCount)
    }

    /// Reset calorie calculation limits (after watching an ad)
    func grantExtraCaloriesCalculation() {
        // Reset to allow full daily limit again
        dailyCaloriesCount = 0
        defaults.set(dailyCaloriesCount, forKey: Keys.dailyCaloriesCount)
    }

    // MARK: - Reset

    func resetDailyUsage() {
        dailyRecipeCount = 0
        dailyButtonPressCount = 0
        dailyCaloriesCount = 0
        defaults.set(dailyRecipeCount, forKey: Keys.dailyRecipeCount)
        defaults.set(dailyButtonPressCount, forKey: Keys.dailyButtonPressCount)
        defaults.set(dailyCaloriesCount, forKey: Keys.dailyCaloriesCount)
        defaults.set(Date(), forKey: Keys.lastResetDate)
    }

    func resetHomeRecipeLoads() {
        totalHomeRecipeLoads = 0
        defaults.set(totalHomeRecipeLoads, forKey: Keys.totalHomeRecipeLoads)
    }

    func resetAll() {
        resetDailyUsage()
        resetHomeRecipeLoads()
    }

    // MARK: - Private Methods

    private func checkAndResetIfNeeded() {
        guard let lastReset = defaults.object(forKey: Keys.lastResetDate) as? Date else {
            // First time - set the reset date
            defaults.set(Date(), forKey: Keys.lastResetDate)
            return
        }

        let calendar = Calendar.current
        if !calendar.isDateInToday(lastReset) {
            // Reset daily counts
            resetDailyUsage()
        }
    }
}

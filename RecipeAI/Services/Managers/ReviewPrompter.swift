import Foundation
import StoreKit
import UIKit

/// Asks for an App Store rating after the user has had a couple of good moments:
/// a recipe they liked enough to save, or a calorie scan that came back.
///
/// Rules: never during loading or after an error (callers only report successes),
/// only after at least two good moments in total, at most once per app version,
/// and never twice within 90 days. Apple also shows the prompt at most three times
/// a year per app, so most calls end up doing nothing.
@MainActor
enum ReviewPrompter {
    enum Win {
        case savedRecipe
        case calorieScan
    }

    private enum Keys {
        static let winCount = "review_prompt_win_count"
        static let lastPromptedVersion = "review_prompt_last_version"
        static let lastPromptDate = "review_prompt_last_date"
    }

    private static let minimumWins = 2
    private static let minimumDaysBetweenPrompts = 90
    /// Lets the result screen settle before the system sheet appears.
    private static let delay: Duration = .seconds(1.5)

    /// Call right after a good moment. Schedules the prompt if the rules allow it.
    static func record(_ win: Win) {
        let defaults = UserDefaults.standard
        let wins = defaults.integer(forKey: Keys.winCount) + 1
        defaults.set(wins, forKey: Keys.winCount)

        guard wins >= minimumWins, canPromptNow(defaults) else { return }

        defaults.set(currentVersion, forKey: Keys.lastPromptedVersion)
        defaults.set(Date(), forKey: Keys.lastPromptDate)

        Task { @MainActor in
            try? await Task.sleep(for: delay)
            guard let scene = UIApplication.shared.connectedScenes
                .compactMap({ $0 as? UIWindowScene })
                .first(where: { $0.activationState == .foregroundActive }) else { return }
            AppStore.requestReview(in: scene)
        }
    }

    // MARK: - Private

    private static var currentVersion: String {
        Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? ""
    }

    private static func canPromptNow(_ defaults: UserDefaults) -> Bool {
        if defaults.string(forKey: Keys.lastPromptedVersion) == currentVersion {
            return false
        }
        if let last = defaults.object(forKey: Keys.lastPromptDate) as? Date,
           let days = Calendar.current.dateComponents([.day], from: last, to: Date()).day,
           days < minimumDaysBetweenPrompts {
            return false
        }
        return true
    }
}

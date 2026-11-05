import Foundation
import Combine

/// The user's permission to send personal data to the AI service. App Review
/// guideline 5.1.2(i) asks apps to say where personal data goes, including to
/// third-party AI, and to get permission first, so it's asked before the first
/// AI feature (camera or voice) and can be withdrawn in Settings.
@MainActor
final class AIConsent: ObservableObject {
    static let shared = AIConsent()

    /// The AI service named in the consent text. Keep it in step with the
    /// server's AI_MODEL and the privacy policy.
    static let providerName = "Google Gemini"

    /// When the user allowed it; absent when they haven't.
    private static let grantedAtKey = "aiDataSharingGrantedAt"

    @Published private(set) var isGranted: Bool

    private init() {
        isGranted = UserDefaults.standard.object(forKey: Self.grantedAtKey) != nil
    }

    func grant() {
        UserDefaults.standard.set(Date(), forKey: Self.grantedAtKey)
        isGranted = true
    }

    func withdraw() {
        UserDefaults.standard.removeObject(forKey: Self.grantedAtKey)
        isGranted = false
    }
}

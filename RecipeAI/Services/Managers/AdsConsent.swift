import Foundation
import Combine
import UserMessagingPlatform

/// Consent for ads, through Google's User Messaging Platform. In the EEA, the
/// UK and Switzerland, Google requires a certified consent form before ads are
/// requested; elsewhere no form is shown. The form's wording is the message
/// published in AdMob › Privacy & messaging.
@MainActor
final class AdsConsent: ObservableObject {
    static let shared = AdsConsent()

    /// Whether Settings must offer "Privacy choices", so the user can change their answer.
    @Published private(set) var isPrivacyOptionsRequired = false

    private var hasGathered = false

    private init() {}

    /// True once ads may be requested: consent was given, or isn't needed where the user is.
    var canRequestAds: Bool { ConsentInformation.shared.canRequestAds }

    /// Updates the consent status, shows the form when the law requires one,
    /// and starts ads once they're allowed. Runs once per launch.
    func gatherAndStartAds() async {
        guard !hasGathered else { return }
        hasGathered = true

        // A choice made on an earlier launch lets ads start right away.
        if canRequestAds {
            AdManager.shared.configure()
        }

        do {
            try await ConsentInformation.shared.requestConsentInfoUpdate(with: RequestParameters())
            try await ConsentForm.loadAndPresentIfRequired(from: AdManager.shared.getTopmostViewController())
        } catch {
            print("Ad consent: \(error.localizedDescription)")
        }

        isPrivacyOptionsRequired = ConsentInformation.shared.privacyOptionsRequirementStatus == .required
        if canRequestAds {
            AdManager.shared.configure()
        }
    }

    /// Shows the form again so the user can change their choices (Settings › Privacy choices).
    func presentPrivacyOptions() async {
        do {
            try await ConsentForm.presentPrivacyOptionsForm(from: AdManager.shared.getTopmostViewController())
        } catch {
            print("Privacy options form: \(error.localizedDescription)")
        }
    }
}

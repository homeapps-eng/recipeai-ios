import Foundation
import GoogleMobileAds

@MainActor
final class AdManager: NSObject, ObservableObject {
    static let shared = AdManager()

    @Published var isRewardedAdReady = false
    @Published var isLoading = false
    @Published var error: Error?

    private var rewardedAd: GADRewardedAd?

    private override init() {
        super.init()
    }

    // MARK: - Initialization

    func configure() {
        GADMobileAds.sharedInstance().start { status in
            print("AdMob SDK initialized: \(status.adapterStatusesByClassName)")
        }
    }

    // MARK: - Load Rewarded Ad

    func loadRewardedAd() async {
        guard !isLoading else { return }

        isLoading = true
        error = nil

        do {
            rewardedAd = try await GADRewardedAd.load(
                withAdUnitID: AppConfig.adMobRewardedAdUnitId,
                request: GADRequest()
            )
            isRewardedAdReady = true
            isLoading = false
        } catch {
            self.error = error
            isRewardedAdReady = false
            isLoading = false
            print("Failed to load rewarded ad: \(error.localizedDescription)")
        }
    }

    // MARK: - Show Rewarded Ad

    func showRewardedAd(from viewController: UIViewController, onReward: @escaping () -> Void) {
        guard let rewardedAd = rewardedAd else {
            print("Rewarded ad not ready")
            return
        }

        rewardedAd.present(fromRootViewController: viewController) {
            // User earned reward
            let reward = rewardedAd.adReward
            print("User earned reward: \(reward.amount) \(reward.type)")
            onReward()
        }

        // Reset and preload next ad
        self.rewardedAd = nil
        isRewardedAdReady = false
        Task {
            await loadRewardedAd()
        }
    }

    // MARK: - Helper

    func getRootViewController() -> UIViewController? {
        guard let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
              let rootViewController = windowScene.windows.first?.rootViewController else {
            return nil
        }
        return rootViewController
    }
}

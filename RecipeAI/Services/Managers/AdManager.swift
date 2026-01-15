import Foundation
import UIKit
import Combine
import GoogleMobileAds

@MainActor
final class AdManager: NSObject, ObservableObject {
    static let shared = AdManager()

    @Published var isRewardedAdReady = false
    @Published var isLoading = false
    @Published var error: Error?

    private var rewardedAd: RewardedAd?
    private var rewardCallback: (() -> Void)?

    private override init() {
        super.init()
    }

    // MARK: - Initialization

    func configure() {
        MobileAds.shared.start { status in
            print("AdMob SDK initialized: \(status.adapterStatusesByClassName)")
            Task {
                await self.loadRewardedAd()
            }
        }
    }

    // MARK: - Load Rewarded Ad

    func loadRewardedAd() async {
        guard !isLoading else { return }

        isLoading = true
        error = nil

        do {
            let request = Request()
            rewardedAd = try await RewardedAd.load(
                with: AppConfig.adMobRewardedAdUnitId,
                request: request
            )
            rewardedAd?.fullScreenContentDelegate = self
            isRewardedAdReady = true
            isLoading = false
            print("Rewarded ad loaded successfully")
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
            print("Rewarded ad not ready, loading...")
            // Try to load and show
            Task {
                await loadRewardedAd()
                if self.rewardedAd != nil {
                    self.showRewardedAd(from: viewController, onReward: onReward)
                } else {
                    // Grant reward anyway if ad fails to load
                    print("Ad failed to load - granting reward")
                    onReward()
                }
            }
            return
        }

        self.rewardCallback = onReward

        rewardedAd.present(from: viewController) { [weak self] in
            let reward = rewardedAd.adReward
            print("User earned reward: \(reward.amount) \(reward.type)")
            self?.rewardCallback?()
            self?.rewardCallback = nil
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

// MARK: - FullScreenContentDelegate

extension AdManager: FullScreenContentDelegate {
    nonisolated func adDidDismissFullScreenContent(_ ad: FullScreenPresentingAd) {
        Task { @MainActor in
            print("Ad dismissed, preloading next ad")
            self.rewardedAd = nil
            self.isRewardedAdReady = false
            await self.loadRewardedAd()
        }
    }

    nonisolated func ad(_ ad: FullScreenPresentingAd, didFailToPresentFullScreenContentWithError error: Error) {
        Task { @MainActor in
            print("Ad failed to present: \(error.localizedDescription)")
            self.rewardedAd = nil
            self.isRewardedAdReady = false
            // Grant reward if ad fails to show
            self.rewardCallback?()
            self.rewardCallback = nil
            await self.loadRewardedAd()
        }
    }
}

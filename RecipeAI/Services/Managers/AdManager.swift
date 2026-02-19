import Foundation
import UIKit
import Combine
import GoogleMobileAds
import AppTrackingTransparency
import AdSupport

@MainActor
final class AdManager: NSObject, ObservableObject {
    static let shared = AdManager()

    @Published var isRewardedAdReady = false
    @Published var isLoading = false
    @Published var error: Error?

    private var rewardedAd: RewardedAd?
    private var rewardCallback: (() -> Void)?
    private var errorCallback: ((String) -> Void)?
    private var isShowingAd = false
    private var rewardEarned = false

    private override init() {
        super.init()
    }

    // MARK: - Initialization

    func configure() {
        MobileAds.shared.start { _ in
            Task {
                await self.loadRewardedAd()
            }
        }
    }

    // MARK: - App Tracking Transparency

    func requestTrackingPermission() async {
        guard ATTrackingManager.trackingAuthorizationStatus == .notDetermined else {
            return
        }

        await withCheckedContinuation { continuation in
            ATTrackingManager.requestTrackingAuthorization { _ in
                continuation.resume()
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
        } catch {
            self.error = error
            isRewardedAdReady = false
            isLoading = false
        }
    }

    // MARK: - Show Rewarded Ad

    func showRewardedAd(
        from viewController: UIViewController,
        onReward: @escaping () -> Void,
        onError: @escaping (String) -> Void
    ) {
        // Prevent multiple ads from showing
        guard !isShowingAd else { return }

        self.rewardCallback = onReward
        self.errorCallback = onError

        if let rewardedAd = rewardedAd {
            // Ad ready - show it
            presentAd(rewardedAd, from: viewController)
        } else {
            // Ad not ready - try to load it first
            Task {
                await loadRewardedAd()
                if let loadedAd = self.rewardedAd {
                    self.presentAd(loadedAd, from: viewController)
                } else {
                    // Failed to load - show error, NO reward
                    self.errorCallback?("Unable to load ad. Please check your internet connection and try again.")
                    self.errorCallback = nil
                    self.rewardCallback = nil
                }
            }
        }
    }

    private func presentAd(_ ad: RewardedAd, from viewController: UIViewController) {
        isShowingAd = true
        rewardEarned = false

        ad.present(from: viewController) { [weak self] in
            self?.rewardEarned = true
            self?.rewardCallback?()
            self?.rewardCallback = nil
            self?.errorCallback = nil
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

    /// Gets the topmost view controller that can present the ad
    func getTopmostViewController() -> UIViewController? {
        guard var topController = getRootViewController() else { return nil }

        while let presented = topController.presentedViewController {
            topController = presented
        }

        return topController
    }

    /// Shows rewarded ad with retry logic if view controller is busy.
    /// Requests ATT permission before the first ad for better UX.
    func showRewardedAdWhenReady(
        onReward: @escaping () -> Void,
        onError: @escaping (String) -> Void,
        retryCount: Int = 0
    ) {
        // Request ATT before first ad (contextual, better opt-in rate)
        if ATTrackingManager.trackingAuthorizationStatus == .notDetermined {
            Task {
                await requestTrackingPermission()
                self.showRewardedAdWhenReady(onReward: onReward, onError: onError, retryCount: retryCount)
            }
            return
        }

        let maxRetries = 5
        let retryDelay = 0.3

        guard let viewController = getTopmostViewController() else {
            onError("Unable to show ad. Please try again.")
            return
        }

        // Check if view controller can present
        if viewController.presentedViewController != nil || viewController.isBeingDismissed || viewController.isBeingPresented {
            if retryCount < maxRetries {
                // Wait and retry
                DispatchQueue.main.asyncAfter(deadline: .now() + retryDelay) { [weak self] in
                    self?.showRewardedAdWhenReady(onReward: onReward, onError: onError, retryCount: retryCount + 1)
                }
            } else {
                onError("Unable to show ad. Please try again later.")
            }
            return
        }

        showRewardedAd(from: viewController, onReward: onReward, onError: onError)
    }
}

// MARK: - FullScreenContentDelegate

extension AdManager: FullScreenContentDelegate {
    nonisolated func adDidDismissFullScreenContent(_ ad: FullScreenPresentingAd) {
        Task { @MainActor in
            self.isShowingAd = false
            self.rewardedAd = nil
            self.isRewardedAdReady = false

            // If ad was dismissed without earning reward, notify user
            if !self.rewardEarned {
                self.errorCallback?("Please watch the complete ad to continue.")
            }

            self.rewardCallback = nil
            self.errorCallback = nil
            self.rewardEarned = false

            await self.loadRewardedAd()
        }
    }

    nonisolated func ad(_ ad: FullScreenPresentingAd, didFailToPresentFullScreenContentWithError error: Error) {
        Task { @MainActor in
            self.isShowingAd = false
            self.rewardedAd = nil
            self.isRewardedAdReady = false
            // Show error - NO reward granted
            self.errorCallback?("Failed to show ad. Please try again.")
            self.errorCallback = nil
            self.rewardCallback = nil
            await self.loadRewardedAd()
        }
    }
}

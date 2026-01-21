import Foundation

// MARK: - Subscription Status

struct SubscriptionStatus: Codable {
    let userId: String
    let isActive: Bool
    let subscriptionId: String?
    let customerId: String?
    let status: String?
    let currentPeriodEnd: Int64?
    let cancelAtPeriodEnd: Bool?
    let planName: String?
    let error: String?
    let isAppleSubscription: Bool?
    let autoRenewStatus: Bool?

    var isPremium: Bool {
        isActive
    }

    var periodEndDate: Date? {
        guard let timestamp = currentPeriodEnd else { return nil }
        // Backend sends milliseconds for Apple subscriptions
        if isAppleSubscription == true {
            return Date(timeIntervalSince1970: TimeInterval(timestamp) / 1000)
        }
        return Date(timeIntervalSince1970: TimeInterval(timestamp))
    }

    var statusType: SubscriptionStatusType {
        if !isActive {
            return .inactive
        }
        // Check if user has cancelled (auto-renew off or cancelAtPeriodEnd)
        if cancelAtPeriodEnd == true || autoRenewStatus == false {
            return .expiring
        }
        return .active
    }

    var willRenew: Bool {
        // For Apple: check autoRenewStatus
        // For Stripe: check cancelAtPeriodEnd
        if isAppleSubscription == true {
            return autoRenewStatus ?? true
        }
        return !(cancelAtPeriodEnd ?? false)
    }
}

enum SubscriptionStatusType {
    case active
    case expiring
    case inactive

    var displayName: String {
        switch self {
        case .active: return "Active"
        case .expiring: return "Expiring"
        case .inactive: return "Inactive"
        }
    }

    var color: String {
        switch self {
        case .active: return "4CAF50"
        case .expiring: return "FF9800"
        case .inactive: return "F44336"
        }
    }
}

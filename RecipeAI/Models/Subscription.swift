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

    var isPremium: Bool {
        isActive
    }

    var periodEndDate: Date? {
        guard let timestamp = currentPeriodEnd else { return nil }
        return Date(timeIntervalSince1970: TimeInterval(timestamp))
    }

    var statusType: SubscriptionStatusType {
        if !isActive {
            return .inactive
        }
        if cancelAtPeriodEnd == true {
            return .expiring
        }
        return .active
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

// MARK: - Pricing Plan

struct PricingPlan: Codable, Identifiable {
    let priceId: String
    let name: String
    let interval: String
    let currency: String
    let amount: Int64
    let displayPrice: String

    var id: String { priceId }

    var isMonthly: Bool {
        interval.lowercased() == "month"
    }

    var isAnnual: Bool {
        interval.lowercased() == "year"
    }
}

// MARK: - Pricing Plans Response

struct PricingPlansResponse: Codable {
    let plans: [PricingPlan]
}

// MARK: - Create Checkout Request

struct CreateCheckoutRequest: Codable {
    let userId: String
    let priceId: String
    let successUrl: String
    let cancelUrl: String
}

// MARK: - Checkout Session Response

struct CheckoutSessionResponse: Codable {
    let sessionId: String
    let url: String
}

// MARK: - Customer Portal Response

struct CustomerPortalResponse: Codable {
    let url: String
}

// MARK: - Cancel Subscription Response

struct CancelSubscriptionResponse: Codable {
    let success: Bool
    let message: String?
}

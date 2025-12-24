import Foundation

// MARK: - Support Request

struct SupportRequest: Codable {
    let email: String
    let message: String
}

// MARK: - Support Response

struct SupportResponse: Codable {
    let success: Bool
    let message: String?
}

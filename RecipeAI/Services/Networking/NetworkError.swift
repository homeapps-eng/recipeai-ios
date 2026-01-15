import Foundation

enum NetworkError: LocalizedError {
    case invalidURL
    case invalidResponse
    case httpError(Int)
    case unauthorized
    case forbidden
    case notFound
    case serverError(String?)
    case decodingError(Error)
    case encodingError(Error)
    case networkError(Error)
    case unknown

    var errorDescription: String? {
        switch self {
        case .invalidURL:
            return "Invalid URL"
        case .invalidResponse:
            return "Invalid response from server"
        case .httpError(let code):
            return "HTTP error: \(code)"
        case .unauthorized:
            return "Unauthorized. Please sign in again."
        case .forbidden:
            return "Access forbidden"
        case .notFound:
            return "Resource not found"
        case .serverError(let message):
            return message ?? "Server error. Please try again later."
        case .decodingError(let error):
            return "Failed to decode response: \(error.localizedDescription)"
        case .encodingError(let error):
            return "Failed to encode request: \(error.localizedDescription)"
        case .networkError(let error):
            return "Network error: \(error.localizedDescription)"
        case .unknown:
            return "An unknown error occurred"
        }
    }

    var isAuthError: Bool {
        switch self {
        case .unauthorized, .forbidden:
            return true
        default:
            return false
        }
    }
}

// MARK: - API Error Response

struct APIErrorResponse: Codable {
    let error: String?
    let message: String?
    let code: Int?
}

// MARK: - Error Extension

extension Error {
    var isCancelledRequest: Bool {
        return checkNSURLErrorCode(NSURLErrorCancelled)
    }

    var isTimeoutError: Bool {
        return checkNSURLErrorCode(NSURLErrorTimedOut)
    }

    var isNetworkUnavailable: Bool {
        return checkNSURLErrorCode(NSURLErrorNotConnectedToInternet) ||
               checkNSURLErrorCode(NSURLErrorNetworkConnectionLost)
    }

    private func checkNSURLErrorCode(_ code: Int) -> Bool {
        // Check if it's a NetworkError wrapping the error
        if let networkError = self as? NetworkError {
            if case .networkError(let underlyingError) = networkError {
                let nsError = underlyingError as NSError
                return nsError.domain == NSURLErrorDomain && nsError.code == code
            }
        }

        // Check if it's a direct NSURLError
        let nsError = self as NSError
        return nsError.domain == NSURLErrorDomain && nsError.code == code
    }

    var userFriendlyMessage: String {
        if isCancelledRequest {
            return ""
        }
        if isTimeoutError {
            return "Request timed out. Please try again."
        }
        if isNetworkUnavailable {
            return "No internet connection. Please check your network."
        }
        // Use the error's own description if it's a LocalizedError
        if let localizedError = self as? LocalizedError,
           let description = localizedError.errorDescription {
            return description
        }
        return "Something went wrong. Please try again."
    }
}

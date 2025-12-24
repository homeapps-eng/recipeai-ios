import Foundation

actor NetworkManager {
    static let shared = NetworkManager()

    private let session: URLSession
    private let decoder: JSONDecoder
    private let encoder: JSONEncoder

    private init() {
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = AppConfig.httpConnectTimeout
        config.timeoutIntervalForResource = AppConfig.httpReadTimeout
        self.session = URLSession(configuration: config)

        self.decoder = JSONDecoder()
        self.decoder.keyDecodingStrategy = .useDefaultKeys

        self.encoder = JSONEncoder()
        self.encoder.keyEncodingStrategy = .useDefaultKeys
    }

    // MARK: - Public Methods

    /// Perform a request with optional body and return decoded response
    func request<T: Decodable>(
        endpoint: APIEndpoint,
        body: Encodable? = nil
    ) async throws -> T {
        var request = endpoint.urlRequest(authToken: getAuthToken())

        if let body = body {
            do {
                request.httpBody = try encoder.encode(body)
            } catch {
                throw NetworkError.encodingError(error)
            }
        }

        return try await performRequest(request)
    }

    /// Perform a request with form data (for file uploads)
    func uploadMultipart<T: Decodable>(
        endpoint: APIEndpoint,
        data: Data,
        filename: String,
        mimeType: String,
        fieldName: String = "image"
    ) async throws -> T {
        var request = endpoint.urlRequest(authToken: getAuthToken())

        let boundary = UUID().uuidString
        request.setValue("multipart/form-data; boundary=\(boundary)", forHTTPHeaderField: "Content-Type")

        var body = Data()
        body.append("--\(boundary)\r\n".data(using: .utf8)!)
        body.append("Content-Disposition: form-data; name=\"\(fieldName)\"; filename=\"\(filename)\"\r\n".data(using: .utf8)!)
        body.append("Content-Type: \(mimeType)\r\n\r\n".data(using: .utf8)!)
        body.append(data)
        body.append("\r\n--\(boundary)--\r\n".data(using: .utf8)!)

        request.httpBody = body

        return try await performRequest(request)
    }

    /// Perform a form-encoded request (used for recipe generation with base64 image)
    func requestFormEncoded<T: Decodable>(
        endpoint: APIEndpoint,
        formData: [String: String]
    ) async throws -> T {
        var request = endpoint.urlRequest(authToken: getAuthToken())
        request.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")

        let bodyString = formData.map { "\($0.key)=\($0.value.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? "")" }
            .joined(separator: "&")
        request.httpBody = bodyString.data(using: .utf8)

        return try await performRequest(request)
    }

    // MARK: - Private Methods

    private func performRequest<T: Decodable>(_ request: URLRequest) async throws -> T {
        do {
            let (data, response) = try await session.data(for: request)

            guard let httpResponse = response as? HTTPURLResponse else {
                throw NetworkError.invalidResponse
            }

            #if DEBUG
            print("[\(request.httpMethod ?? "?")] \(request.url?.absoluteString ?? "?")")
            print("Status: \(httpResponse.statusCode)")
            if let body = request.httpBody, let bodyString = String(data: body, encoding: .utf8) {
                print("Request Body: \(bodyString.prefix(500))")
            }
            if let responseString = String(data: data, encoding: .utf8) {
                print("Response: \(responseString.prefix(500))")
            }
            #endif

            switch httpResponse.statusCode {
            case 200...299:
                do {
                    return try decoder.decode(T.self, from: data)
                } catch {
                    throw NetworkError.decodingError(error)
                }
            case 401:
                throw NetworkError.unauthorized
            case 403:
                throw NetworkError.forbidden
            case 404:
                throw NetworkError.notFound
            case 500...599:
                throw NetworkError.serverError
            default:
                throw NetworkError.httpError(httpResponse.statusCode)
            }
        } catch let error as NetworkError {
            throw error
        } catch {
            throw NetworkError.networkError(error)
        }
    }

    private nonisolated func getAuthToken() -> String? {
        KeychainManager.shared.getToken()
    }
}

// MARK: - Convenience Extensions

extension NetworkManager {
    /// Perform a GET request without body
    func get<T: Decodable>(endpoint: APIEndpoint) async throws -> T {
        try await request(endpoint: endpoint, body: nil as EmptyBody?)
    }

    /// Perform a POST request with body
    func post<T: Decodable, B: Encodable>(endpoint: APIEndpoint, body: B) async throws -> T {
        try await request(endpoint: endpoint, body: body)
    }

    /// Perform a PUT request with body
    func put<T: Decodable, B: Encodable>(endpoint: APIEndpoint, body: B) async throws -> T {
        try await request(endpoint: endpoint, body: body)
    }

    /// Perform a DELETE request
    func delete<T: Decodable>(endpoint: APIEndpoint) async throws -> T {
        try await request(endpoint: endpoint, body: nil as EmptyBody?)
    }
}

// MARK: - Empty Body Helper

private struct EmptyBody: Encodable {}

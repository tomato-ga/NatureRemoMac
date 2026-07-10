import Foundation

enum NatureRemoAPIError: LocalizedError {
    case missingToken
    case invalidURL(String)
    case unauthorized
    case rateLimited(resetAt: Date?)
    case httpStatus(Int, String?)
    case emptyResponse

    var errorDescription: String? {
        switch self {
        case .missingToken:
            return "Nature Remo access token is not configured."
        case .invalidURL(let path):
            return "Invalid Nature Remo API path: \(path)"
        case .unauthorized:
            return "The Nature Remo access token was rejected. Create a new token and try again."
        case .rateLimited(let resetAt):
            if let resetAt {
                return "Nature Remo API request limit reached. Try again after \(resetAt.formatted(date: .omitted, time: .shortened))."
            }
            return "Nature Remo API request limit reached. Wait a few minutes and try again."
        case .httpStatus(let status, let message):
            guard let message, !message.isEmpty else {
                return "Nature Remo API returned HTTP \(status)."
            }
            return "Nature Remo API returned HTTP \(status): \(message)"
        case .emptyResponse:
            return "Nature Remo API returned an empty response."
        }
    }
}

struct NatureRemoClient {
    private let baseURL: URL
    private let token: String
    private let session: URLSession

    init(
        token: String,
        session: URLSession = .shared,
        baseURL: URL = URL(string: "https://api.nature.global")!
    ) {
        self.token = token
        self.session = session
        self.baseURL = baseURL
    }

    func fetchUser() async throws -> RemoUser {
        try await request(path: "/1/users/me")
    }

    func fetchDevices() async throws -> [RemoDevice] {
        try await request(path: "/1/devices")
    }

    func fetchAppliances() async throws -> [RemoAppliance] {
        try await request(path: "/1/appliances")
    }

    func sendSignal(id: String) async throws {
        try await post(path: "/1/signals/\(id)/send")
    }

    func setAircon(applianceID: String, form: [String: String]) async throws {
        try await post(path: "/1/appliances/\(applianceID)/aircon_settings", form: form)
    }

    func sendLightButton(applianceID: String, buttonName: String) async throws {
        try await post(path: "/1/appliances/\(applianceID)/light", form: ["button": buttonName])
    }

    func sendTVButton(applianceID: String, buttonName: String) async throws {
        try await post(path: "/1/appliances/\(applianceID)/tv", form: ["button": buttonName])
    }

    private func request<T: Decodable>(path: String) async throws -> T {
        let data = try await perform(path: path, method: "GET", form: nil)
        guard !data.isEmpty else {
            throw NatureRemoAPIError.emptyResponse
        }
        return try JSONDecoder().decode(T.self, from: data)
    }

    private func post(path: String, form: [String: String] = [:]) async throws {
        _ = try await perform(path: path, method: "POST", form: form)
    }

    private func perform(path: String, method: String, form: [String: String]?) async throws -> Data {
        guard var components = URLComponents(url: baseURL, resolvingAgainstBaseURL: false) else {
            throw NatureRemoAPIError.invalidURL(path)
        }
        components.path = path

        guard let url = components.url else {
            throw NatureRemoAPIError.invalidURL(path)
        }

        var request = URLRequest(url: url)
        request.httpMethod = method
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        request.setValue(AppMetadata.userAgent, forHTTPHeaderField: "User-Agent")

        if let form {
            request.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")
            request.httpBody = Self.encodeForm(form)
        }

        let (data, response) = try await session.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse else {
            return data
        }

        guard (200..<300).contains(httpResponse.statusCode) else {
            switch httpResponse.statusCode {
            case 401:
                throw NatureRemoAPIError.unauthorized
            case 429:
                throw NatureRemoAPIError.rateLimited(resetAt: Self.rateLimitResetDate(from: httpResponse))
            default:
                throw NatureRemoAPIError.httpStatus(
                    httpResponse.statusCode,
                    Self.safeErrorMessage(from: data)
                )
            }
        }

        return data
    }

    private static func encodeForm(_ values: [String: String]) -> Data {
        var components = URLComponents()
        components.queryItems = values
            .sorted { $0.key < $1.key }
            .map { URLQueryItem(name: $0.key, value: $0.value) }
        return Data((components.percentEncodedQuery ?? "").utf8)
    }

    private static func rateLimitResetDate(from response: HTTPURLResponse) -> Date? {
        guard
            let rawValue = response.value(forHTTPHeaderField: "X-Rate-Limit-Reset"),
            let epoch = TimeInterval(rawValue)
        else {
            return nil
        }

        return Date(timeIntervalSince1970: epoch)
    }

    private static func safeErrorMessage(from data: Data) -> String? {
        struct ErrorPayload: Decodable {
            let code: String?
            let message: String?
        }

        guard let payload = try? JSONDecoder().decode(ErrorPayload.self, from: data) else {
            return nil
        }

        let message = payload.message?
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .prefix(240)
        let code = payload.code?
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .prefix(80)

        switch (code, message) {
        case let (code?, message?) where !code.isEmpty && !message.isEmpty:
            return "\(code): \(message)"
        case let (_, message?) where !message.isEmpty:
            return String(message)
        case let (code?, _) where !code.isEmpty:
            return String(code)
        default:
            return nil
        }
    }
}

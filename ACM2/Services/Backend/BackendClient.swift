import Foundation

enum BackendClientError: LocalizedError {
    case invalidBaseURL(String)
    case invalidResponse
    case http(status: Int, message: String)

    var errorDescription: String? {
        switch self {
        case .invalidBaseURL(let value):
            return "Invalid backend URL: \(value)"
        case .invalidResponse:
            return "The backend returned an invalid response."
        case .http(let status, let message):
            return "Backend error \(status): \(message)"
        }
    }
}

private struct BackendErrorEnvelope: Decodable {
    let error: String
}

struct BackendClient {
    private let session: URLSession
    private let decoder: JSONDecoder
    private let encoder: JSONEncoder
    private let baseURL: URL

    init(session: URLSession = .shared) {
        self.session = session

        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        self.decoder = decoder

        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        self.encoder = encoder

        let configuredURL =
            ProcessInfo.processInfo.environment["BACKEND_BASE_URL"] ??
            (Bundle.main.object(forInfoDictionaryKey: "BACKEND_BASE_URL") as? String) ??
            "http://localhost:8080"

        guard let baseURL = URL(string: configuredURL) else {
            fatalError(BackendClientError.invalidBaseURL(configuredURL).localizedDescription)
        }

        self.baseURL = baseURL
    }

    func get<Response: Decodable>(_ path: String, queryItems: [URLQueryItem] = []) async throws -> Response {
        try await request(path: path, method: "GET", queryItems: queryItems, body: Optional<Int>.none)
    }

    func post<Request: Encodable, Response: Decodable>(_ path: String, body: Request) async throws -> Response {
        try await request(path: path, method: "POST", queryItems: [], body: body)
    }

    private func request<Request: Encodable, Response: Decodable>(
        path: String,
        method: String,
        queryItems: [URLQueryItem],
        body: Request?
    ) async throws -> Response {
        var components = URLComponents(url: baseURL.appendingPathComponent(path.trimmingCharacters(in: CharacterSet(charactersIn: "/"))), resolvingAgainstBaseURL: false)
        components?.queryItems = queryItems.isEmpty ? nil : queryItems

        guard let url = components?.url else {
            throw BackendClientError.invalidBaseURL(baseURL.absoluteString)
        }

        var request = URLRequest(url: url)
        request.httpMethod = method
        request.setValue("application/json", forHTTPHeaderField: "Accept")

        if let body {
            request.httpBody = try encoder.encode(body)
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        }

        let (data, response) = try await session.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw BackendClientError.invalidResponse
        }

        guard (200...299).contains(httpResponse.statusCode) else {
            let message = (try? decoder.decode(BackendErrorEnvelope.self, from: data).error)
                ?? String(data: data, encoding: .utf8)
                ?? "Unknown error"
            throw BackendClientError.http(status: httpResponse.statusCode, message: message)
        }

        return try decoder.decode(Response.self, from: data)
    }
}

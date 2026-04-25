import Foundation

private struct CopilotQueryRequest: Codable {
    let userId: String
    let query: String
}

struct CopilotClient {
    private let backend: BackendClient

    init(backend: BackendClient = BackendClient()) {
        self.backend = backend
    }

    func fetchDailyBrief(userId: String) async throws -> DailyBrief {
        try await backend.get("/copilot/daily-brief", queryItems: [
            URLQueryItem(name: "userId", value: userId)
        ])
    }

    func query(userId: String, query: String) async throws -> CopilotQueryResponse {
        try await backend.post("/copilot/query", body: CopilotQueryRequest(userId: userId, query: query))
    }
}

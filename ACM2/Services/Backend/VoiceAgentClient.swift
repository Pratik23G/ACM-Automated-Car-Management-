import Foundation

enum VoiceAgentContext: String, Codable {
    case fuel
    case maintenance
    case copilot
}

private struct VoiceSummaryRequest: Codable {
    let userId: String
    let context: VoiceAgentContext
    let transcript: String
}

struct VoiceAgentClient {
    private let backend: BackendClient

    init(backend: BackendClient = BackendClient()) {
        self.backend = backend
    }

    func summarize(
        userId: String,
        context: VoiceAgentContext,
        transcript: String
    ) async throws -> VoiceSummaryResponse {
        try await backend.post(
            "/voice/summary",
            body: VoiceSummaryRequest(userId: userId, context: context, transcript: transcript)
        )
    }
}

import Foundation

enum AgentActionType: String, Codable {
    case notification
    case voice
    case deepLink = "deep-link"
    case recommendation
}

enum AgentActionPriority: String, Codable {
    case low
    case medium
    case high
}

struct AgentAction: Identifiable, Codable, Equatable {
    let id: String
    let type: AgentActionType
    let title: String
    let description: String
    let priority: AgentActionPriority
    let destination: String?
}

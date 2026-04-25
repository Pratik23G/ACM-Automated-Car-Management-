import Foundation

enum CopilotCardTone: String, Codable {
    case info
    case success
    case warning
    case critical
}

enum CopilotCardType: String, Codable {
    case hero
    case metric
    case list
    case station
    case timeline
    case summary
}

struct CopilotCardItem: Codable, Equatable, Hashable {
    let label: String
    let value: String
}

struct CopilotCard: Identifiable, Codable, Equatable {
    let id: String
    let type: CopilotCardType
    let title: String
    let body: String
    let tone: CopilotCardTone
    let items: [CopilotCardItem]?
    let tags: [String]?
    let action: AgentAction?
}

struct DailyBrief: Codable, Equatable {
    let headline: String
    let cards: [CopilotCard]
    let actions: [AgentAction]
}

struct CopilotQueryResponse: Codable, Equatable {
    let answer: String
    let cards: [CopilotCard]
    let actions: [AgentAction]
}

struct VoiceSummaryResponse: Codable, Equatable {
    let summary: String
    let cards: [CopilotCard]
    let action: AgentAction?
}

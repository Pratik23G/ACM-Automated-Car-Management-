import Foundation

struct CarIssueTriage: Codable, Equatable {
    let title: String
    let urgency: String
    let likelyCauses: [String]
    let checksYouCanDo: [String]
    let nextSteps: [String]
    let safetyNotes: [String]
}


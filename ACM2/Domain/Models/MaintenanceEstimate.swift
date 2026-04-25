import Foundation

enum MaintenanceServiceKind: String, Codable, Identifiable {
    case oilChange
    case tireRotation
    case brakeInspection
    case coolant
    case airFilter

    var id: String { rawValue }

    var label: String {
        switch self {
        case .oilChange:
            return "Oil Change"
        case .tireRotation:
            return "Tire Rotation"
        case .brakeInspection:
            return "Brake Inspection"
        case .coolant:
            return "Coolant"
        case .airFilter:
            return "Air Filter"
        }
    }
}

enum MaintenanceEstimateSeverity: String, Codable {
    case ok
    case soon
    case overdue
}

struct MaintenanceEstimate: Codable, Equatable, Identifiable {
    let serviceType: MaintenanceServiceKind
    let adjustedIntervalMiles: Double
    let dueInMiles: Double
    let dueDateLabel: String
    let severity: MaintenanceEstimateSeverity
    let reason: String
    let recommendedAction: String

    var id: String { serviceType.rawValue }
}

struct MaintenanceAnalysis: Codable, Equatable {
    let estimates: [MaintenanceEstimate]
    let cards: [CopilotCard]
    let actions: [AgentAction]
}

struct MaintenanceAnalyzeRequest: Codable {
    let userId: String
    let profile: VehicleProfile
    let reminders: [MaintenanceReminder]
    let trips: [TripResult]
    let expenses: [MaintenanceExpense]
}

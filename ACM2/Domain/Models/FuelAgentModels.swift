import Foundation

enum FuelTrendDirection: String, Codable {
    case down
    case steady
    case up
}

struct FuelStationInsight: Identifiable, Equatable {
    enum Highlight: String, Equatable {
        case cheapest
        case premiumPick
        case bestPromo
    }

    let id = UUID()
    let highlight: Highlight
    let stationName: String
    let areaLabel: String
    let priceText: String
    let detail: String
}

struct FuelMarketUpdate: Identifiable, Equatable {
    let id = UUID()
    let headline: String
    let summary: String
    let direction: FuelTrendDirection
}

struct FuelSpendSnapshot: Equatable {
    let dailyAverage: Double
    let weeklyTotal: Double
    let monthlyTotal: Double
    let yearlyProjection: Double
}

struct FuelAgentCoordinationNote: Identifiable, Equatable {
    enum Source: String {
        case marketNews
        case fillHistory
        case drivingBehavior
        case agentBridge
    }

    let id = UUID()
    let source: Source
    let title: String
    let summary: String
}

enum FuelCostPeriod: String, CaseIterable, Identifiable, Codable {
    case daily = "Daily"
    case weekly = "Weekly"
    case monthly = "Monthly"
    case yearly = "Yearly"

    var id: String { rawValue }

    var historyWindow: Int {
        switch self {
        case .daily: return 7
        case .weekly: return 8
        case .monthly: return 6
        case .yearly: return 4
        }
    }
}

enum CostTrackerMode: String, CaseIterable, Identifiable {
    case fuel = "Fuel Costs"
    case maintenance = "Maintenance Costs"

    var id: String { rawValue }
}

struct FuelCostBucket: Identifiable, Equatable {
    let id = UUID()
    let label: String
    let startDate: Date
    let totalSpend: Double
    let fillUpCount: Int
    let averagePrice: Double
    let dominantStation: String?
    let summary: String
}

struct FuelCostSummary: Equatable {
    let period: FuelCostPeriod
    let headline: String
    let totalSpend: Double
    let fillUpCount: Int
    let averageFillCost: Double
    let averagePricePerUnit: Double
    let dominantStation: String?
    let dominantArea: String?
    let comparisonText: String
    let summary: String
    let insights: [String]
    let buckets: [FuelCostBucket]
    let logs: [FuelLog]
}

struct MaintenanceCostBucket: Identifiable, Equatable {
    let id = UUID()
    let label: String
    let startDate: Date
    let totalSpend: Double
    let purchaseCount: Int
    let dominantCategory: String?
    let dominantLocation: String?
    let summary: String
}

struct MaintenanceCostSummary: Equatable {
    let period: FuelCostPeriod
    let headline: String
    let totalSpend: Double
    let entryCount: Int
    let averageEntryCost: Double
    let dominantCategory: String?
    let dominantLocation: String?
    let comparisonText: String
    let summary: String
    let insights: [String]
    let buckets: [MaintenanceCostBucket]
    let expenses: [MaintenanceExpense]
}

struct FuelDashboard: Equatable {
    let stationInsights: [FuelStationInsight]
    let marketUpdates: [FuelMarketUpdate]
    let spendSnapshot: FuelSpendSnapshot
    let profileSummary: String
    let efficiencyHeadline: String
    let suggestedQuestions: [String]
    let projectionSummary: String
    let coordinationNotes: [FuelAgentCoordinationNote]
}

import Foundation

struct FuelStationSummary: Codable, Equatable {
    let name: String
    let areaLabel: String
    let price: Double
    let qualitySignal: String
    let savingsNote: String
}

struct FuelSummary: Codable, Equatable {
    let areaLabel: String
    let fuelProduct: FuelProduct
    let localAveragePrice: Double
    let cheapestStation: FuelStationSummary
    let premiumStation: FuelStationSummary?
    let weeklyCost: Double
    let monthlyCost: Double
    let yearlyCost: Double
    let estimatedSavings: Double
    let newsHeadline: String
    let cards: [CopilotCard]
    let actions: [AgentAction]
}

struct FuelSummaryRequest: Codable {
    let userId: String
    let profile: VehicleProfile
    let trips: [TripResult]
    let fuelLogs: [FuelLog]
}

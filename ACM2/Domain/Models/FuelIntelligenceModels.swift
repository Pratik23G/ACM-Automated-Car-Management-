import Foundation

struct FuelSourceResult: Identifiable, Codable, Equatable {
    let title: String
    let url: String
    let snippet: String
    let siteName: String

    var id: String { url }
}

struct FuelStationPrice: Identifiable, Codable, Equatable {
    let name: String
    let brand: String
    let address: String
    let pricePerGallon: Double
    let priceDisplay: String
    let distanceMiles: Double?
    let sourceNote: String

    var id: String {
        let cents = Int((pricePerGallon * 100).rounded())
        return "\(name)|\(address)|\(cents)"
    }
}

struct FuelCostProjection: Codable, Equatable {
    let weekly: Double
    let monthly: Double
    let yearly: Double
}

struct FuelPriceSnapshot: Identifiable, Codable, Equatable {
    var id: UUID = UUID()
    let capturedAt: Date
    let areaLabel: String
    let query: String
    let sourceURL: String
    let stations: [FuelStationPrice]
    let localAveragePrice: Double
}

struct FuelIntelligenceReport: Equatable {
    let areaLabel: String
    let query: String
    let commonRoutes: [String]
    let recentWeeklyMileage: Double
    let sourceURL: String
    let sources: [FuelSourceResult]
    let snapshot: FuelPriceSnapshot
    let cheapestStation: FuelStationPrice
    let localAveragePrice: Double
    let deltaVsPreviousSnapshot: Double?
    let priceTrendSummary: String
    let recommendation: String
    let savingsEstimate: String
    let spokenBrief: String
    let averageProjection: FuelCostProjection?
    let cheapestProjection: FuelCostProjection?
}

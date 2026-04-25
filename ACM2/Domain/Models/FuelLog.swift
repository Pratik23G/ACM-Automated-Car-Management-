import Foundation

struct FuelLog: Identifiable, Codable, Equatable {
    var id: UUID = UUID()
    var loggedAt: Date = Date()
    var stationName: String
    var areaLabel: String
    var coordinate: SerializableCoordinate?
    var fuelProduct: FuelProduct
    var pricePerUnit: Double
    var amount: Double
    var promoTitle: String?
    var totalCostOverride: Double?

    var totalCost: Double {
        totalCostOverride ?? (pricePerUnit * amount)
    }
}

import Foundation

struct TripAISummary: Codable, Equatable {
    let tripSummary: String
    let drivingBehavior: String
    let fuelInsight: String
    let roadImpact: String
    let brakeWear: String
    let overallTip: String
}


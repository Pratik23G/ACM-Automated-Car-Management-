import Foundation

// MARK: - Drive DNA AI Insights

struct DriveDNAInsights: Codable, Equatable {
    let headline:        String  // 1 punchy line describing the driver
    let topPattern:      String  // Most significant pattern found
    let timeInsight:     String  // Time-of-day behavioral insight
    let dayInsight:      String  // Day-of-week behavioral insight
    let strengthNote:    String  // Something the driver does well
    let improvementTip:  String  // Single most impactful improvement
}

// MARK: - Pre-Trip Brief AI Response

struct PreTripBrief: Codable, Equatable {
    let summary:         String    // 1-2 sentence overview
    let behaviorWarning: String    // Personal habit warning for this route/time
    let knownHazards:    [String]  // From saved route notes
    let fuelEstimate:    String    // Estimated cost & gallons
    let tip:             String    // One actionable tip for this specific trip
}

// MARK: - Fuel Coach AI Response

struct FuelCoachBrief: Codable, Equatable {
    let summary: String
    let pricingOutlook: String
    let efficiencyDiagnosis: String
    let actionPlan: [String]
}

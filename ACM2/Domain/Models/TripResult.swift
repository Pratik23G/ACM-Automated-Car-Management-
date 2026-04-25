import Foundation

struct TripResult: Identifiable, Codable, Equatable {
    var id: UUID = UUID()

    // ✅ timestamp for TripHistory / TripArchiveView
    var endedAt: Date = Date()

    // Core stats
    var durationSeconds: Int
    var distanceMiles: Double?
    var avgSpeedMph: Double?
    var maxSpeedMph: Double?

    // Events
    var hardBrakes: Int
    var sharpTurns: Int
    var aggressiveAccels: Int
    var bumpsDetected: Int

    // Fuel/cost
    var mpg: Double
    var estimatedGallons: Double?
    var estimatedFuelCost: Double?

    // AI fields
    var aiTripSummary: String?
    var aiDrivingBehavior: String?
    var aiFuelInsight: String?
    var aiRoadImpact: String?
    var aiBrakeWear: String?
    var aiOverallTip: String?

    enum CodingKeys: String, CodingKey {
        case id, endedAt,
             durationSeconds, distanceMiles, avgSpeedMph, maxSpeedMph,
             hardBrakes, sharpTurns, aggressiveAccels, bumpsDetected,
             mpg, estimatedGallons, estimatedFuelCost,
             aiTripSummary, aiDrivingBehavior, aiFuelInsight, aiRoadImpact, aiBrakeWear, aiOverallTip
    }

    // ✅ tolerant decoding so older saved trips (without endedAt) won't crash
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)

        id = try c.decodeIfPresent(UUID.self, forKey: .id) ?? UUID()
        endedAt = try c.decodeIfPresent(Date.self, forKey: .endedAt) ?? Date()

        durationSeconds = try c.decode(Int.self, forKey: .durationSeconds)
        distanceMiles = try c.decodeIfPresent(Double.self, forKey: .distanceMiles)
        avgSpeedMph = try c.decodeIfPresent(Double.self, forKey: .avgSpeedMph)
        maxSpeedMph = try c.decodeIfPresent(Double.self, forKey: .maxSpeedMph)

        hardBrakes = try c.decode(Int.self, forKey: .hardBrakes)
        sharpTurns = try c.decode(Int.self, forKey: .sharpTurns)
        aggressiveAccels = try c.decode(Int.self, forKey: .aggressiveAccels)
        bumpsDetected = try c.decodeIfPresent(Int.self, forKey: .bumpsDetected) ?? 0

        mpg = try c.decode(Double.self, forKey: .mpg)
        estimatedGallons = try c.decodeIfPresent(Double.self, forKey: .estimatedGallons)
        estimatedFuelCost = try c.decodeIfPresent(Double.self, forKey: .estimatedFuelCost)

        aiTripSummary = try c.decodeIfPresent(String.self, forKey: .aiTripSummary)
        aiDrivingBehavior = try c.decodeIfPresent(String.self, forKey: .aiDrivingBehavior)
        aiFuelInsight = try c.decodeIfPresent(String.self, forKey: .aiFuelInsight)
        aiRoadImpact = try c.decodeIfPresent(String.self, forKey: .aiRoadImpact)
        aiBrakeWear = try c.decodeIfPresent(String.self, forKey: .aiBrakeWear)
        aiOverallTip = try c.decodeIfPresent(String.self, forKey: .aiOverallTip)
    }

    // Your normal initializer (used by TripManager)
    init(
        id: UUID = UUID(),
        endedAt: Date = Date(),
        durationSeconds: Int,
        distanceMiles: Double? = nil,
        avgSpeedMph: Double? = nil,
        maxSpeedMph: Double? = nil,
        hardBrakes: Int = 0,
        sharpTurns: Int = 0,
        aggressiveAccels: Int = 0,
        bumpsDetected: Int = 0,
        mpg: Double,
        estimatedGallons: Double? = nil,
        estimatedFuelCost: Double? = nil,
        aiTripSummary: String? = nil,
        aiDrivingBehavior: String? = nil,
        aiFuelInsight: String? = nil,
        aiRoadImpact: String? = nil,
        aiBrakeWear: String? = nil,
        aiOverallTip: String? = nil
    ) {
        self.id = id
        self.endedAt = endedAt
        self.durationSeconds = durationSeconds
        self.distanceMiles = distanceMiles
        self.avgSpeedMph = avgSpeedMph
        self.maxSpeedMph = maxSpeedMph
        self.hardBrakes = hardBrakes
        self.sharpTurns = sharpTurns
        self.aggressiveAccels = aggressiveAccels
        self.bumpsDetected = bumpsDetected
        self.mpg = mpg
        self.estimatedGallons = estimatedGallons
        self.estimatedFuelCost = estimatedFuelCost
        self.aiTripSummary = aiTripSummary
        self.aiDrivingBehavior = aiDrivingBehavior
        self.aiFuelInsight = aiFuelInsight
        self.aiRoadImpact = aiRoadImpact
        self.aiBrakeWear = aiBrakeWear
        self.aiOverallTip = aiOverallTip
    }

    func copilotSummaryPrompt(vehicle: VehicleProfile?) -> String {
        var lines: [String] = []
        lines.append("Create a trip intelligence summary for this completed drive.")
        if let vehicle {
            lines.append("Vehicle: \(vehicle.displayName)")
            lines.append("Fuel type: \(vehicle.fuelType.label)")
        }
        lines.append("Trip ended at: \(endedAt.formatted(date: .abbreviated, time: .shortened))")
        lines.append("Duration: \(durationSeconds) seconds")
        if let distanceMiles {
            lines.append(String(format: "Distance: %.2f miles", distanceMiles))
        }
        if let avgSpeedMph {
            lines.append(String(format: "Average speed: %.1f mph", avgSpeedMph))
        }
        if let maxSpeedMph {
            lines.append(String(format: "Max speed: %.1f mph", maxSpeedMph))
        }
        lines.append("Hard brakes: \(hardBrakes)")
        lines.append("Sharp turns: \(sharpTurns)")
        lines.append("Aggressive accelerations: \(aggressiveAccels)")
        lines.append("Bumps detected: \(bumpsDetected)")
        lines.append(String(format: "Estimated MPG: %.1f", mpg))
        if let estimatedGallons {
            lines.append(String(format: "Estimated gallons: %.2f", estimatedGallons))
        }
        if let estimatedFuelCost {
            lines.append(String(format: "Estimated fuel cost: $%.2f", estimatedFuelCost))
        }
        lines.append("Return a short overview, what the driving behavior suggests, what it means for fuel use, road impact, brake wear, and the clearest next tip.")
        return lines.joined(separator: "\n")
    }
}

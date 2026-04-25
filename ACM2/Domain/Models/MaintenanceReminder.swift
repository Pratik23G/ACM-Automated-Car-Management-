import Foundation

struct MaintenanceReminder: Identifiable, Codable {
    var id: UUID = UUID()
    var serviceType: ServiceType
    var intervalMiles: Double
    var lastServiceOdometer: Double?
    var lastServiceDate: Date?

    // MARK: - ServiceType

    enum ServiceType: String, Codable, CaseIterable, Identifiable {
        case oilChange       = "oilChange"
        case tireRotation    = "tireRotation"
        case brakeInspection = "brakeInspection"
        case airFilter       = "airFilter"

        var id: String { rawValue }

        var label: String {
            switch self {
            case .oilChange:       return "Oil Change"
            case .tireRotation:    return "Tire Rotation"
            case .brakeInspection: return "Brake Inspection"
            case .airFilter:       return "Air Filter"
            }
        }

        var icon: String {
            switch self {
            case .oilChange:       return "drop.fill"
            case .tireRotation:    return "arrow.triangle.2.circlepath"
            case .brakeInspection: return "exclamationmark.octagon.fill"
            case .airFilter:       return "wind"
            }
        }

        var defaultIntervalMiles: Double {
            switch self {
            case .oilChange:       return 5_000
            case .tireRotation:    return 7_500
            case .brakeInspection: return 15_000
            case .airFilter:       return 15_000
            }
        }
    }

    // MARK: - Basic Odometer Helpers

    func milesSinceService(currentOdometer: Double) -> Double {
        currentOdometer - (lastServiceOdometer ?? 0)
    }

    func milesUntilDue(currentOdometer: Double, effectiveInterval: Double) -> Double {
        max(0, effectiveInterval - milesSinceService(currentOdometer: currentOdometer))
    }

    func isOverdue(currentOdometer: Double, effectiveInterval: Double) -> Bool {
        milesSinceService(currentOdometer: currentOdometer) >= effectiveInterval
    }

    func isDueSoon(currentOdometer: Double, effectiveInterval: Double) -> Bool {
        let rem = milesUntilDue(currentOdometer: currentOdometer, effectiveInterval: effectiveInterval)
        return rem > 0 && rem <= 500
    }

    // MARK: - Behavior-Adjusted Interval
    //
    // Each service type responds differently to driving aggression:
    //
    //  Brakes     — most sensitive to hard braking. Each hard brake event thermally
    //               stresses pads and rotors beyond normal wear. At avg ≥4 hard brakes/trip
    //               the interval shrinks by up to 40%.
    //
    //  Oil        — sensitive to engine heat cycles caused by aggressive acceleration and
    //               high-RPM bursts. At high aggression the interval shrinks up to 30%.
    //
    //  Tires      — worn unevenly by sharp cornering forces. At avg ≥3 sharp turns/trip
    //               the rotation interval shrinks up to 30%.
    //
    //  Air filter — driven by environment and mileage, not driving style. No adjustment.

    /// How much to reduce the base interval, expressed as a fraction (0.0 = no reduction, 0.4 = 40% shorter).
    func reductionFactor(avgHardBrakes: Double,
                          avgSharpTurns: Double,
                          avgAggression: Double,
                          tripCount: Int = 0) -> Double {

        // Confidence multiplier — small samples shouldn't move the needle much.
        // The system needs to earn trust as more trips are logged.
        //  1–4 trips  →  20% weight  (just a hint, not a real signal yet)
        //  5–9 trips  →  45% weight
        // 10–19 trips →  70% weight
        // 20–29 trips →  85% weight
        // 30+ trips   → 100% weight
        let confidence: Double = {
            switch tripCount {
            case 0..<5:  return 0.20
            case 5..<10: return 0.45
            case 10..<20: return 0.70
            case 20..<30: return 0.85
            default:      return 1.00
            }
        }()

        let rawFactor: Double
        switch serviceType {

        case .brakeInspection:
            let brakeFactor = min(avgHardBrakes / 4.0, 1.0) * 0.40
            let aggrFactor  = min(avgAggression / 15.0, 1.0) * 0.10
            rawFactor = min(brakeFactor + aggrFactor, 0.45)

        case .oilChange:
            rawFactor = min(avgAggression / 15.0, 1.0) * 0.30

        case .tireRotation:
            let turnFactor = min(avgSharpTurns / 3.0, 1.0) * 0.30
            let aggrFactor = min(avgAggression / 15.0, 1.0) * 0.05
            rawFactor = min(turnFactor + aggrFactor, 0.30)

        case .airFilter:
            return 0.0
        }

        return rawFactor * confidence
    }

    func effectiveInterval(avgHardBrakes: Double,
                            avgSharpTurns: Double,
                            avgAggression: Double,
                            tripCount: Int = 0) -> Double {
        let reduction = reductionFactor(avgHardBrakes: avgHardBrakes,
                                         avgSharpTurns: avgSharpTurns,
                                         avgAggression: avgAggression,
                                         tripCount: tripCount)
        let adjusted = intervalMiles * (1.0 - reduction)
        return (adjusted / 100).rounded() * 100
    }

    func adjustmentReason(avgHardBrakes: Double,
                           avgSharpTurns: Double,
                           avgAggression: Double,
                           tripCount: Int = 0) -> String? {
        let factor = reductionFactor(avgHardBrakes: avgHardBrakes,
                                      avgSharpTurns: avgSharpTurns,
                                      avgAggression: avgAggression,
                                      tripCount: tripCount)
        guard factor >= 0.05 else { return nil }

        let pct = Int((factor * 100).rounded())

        switch serviceType {
        case .brakeInspection:
            if avgHardBrakes >= 2 {
                return "Shortened \(pct)% — avg \(String(format: "%.1f", avgHardBrakes)) hard brakes/trip accelerates pad and rotor wear."
            }
            return "Shortened \(pct)% — aggressive driving style increases brake wear."
        case .oilChange:
            return "Shortened \(pct)% — hard acceleration and aggression increase engine heat and degrade oil faster."
        case .tireRotation:
            if avgSharpTurns >= 1.5 {
                return "Shortened \(pct)% — avg \(String(format: "%.1f", avgSharpTurns)) sharp turns/trip causes uneven tread wear."
            }
            return "Shortened \(pct)% — driving style is creating uneven tire wear."
        case .airFilter:
            return nil
        }
    }
}

import SwiftUI

// MARK: - SafetyScore Model

struct SafetyScore {
    let score: Int          // 0–100
    let grade: Grade
    let deductions: [Deduction]

    // MARK: Grade

    enum Grade: String {
        case excellent = "Excellent"
        case good      = "Good"
        case fair      = "Fair"
        case poor      = "Poor"
        case dangerous = "Dangerous"

        var letter: String {
            switch self {
            case .excellent: return "A"
            case .good:      return "B"
            case .fair:      return "C"
            case .poor:      return "D"
            case .dangerous: return "F"
            }
        }

        var color: Color {
            switch self {
            case .excellent: return .green
            case .good:      return Color(red: 0.2, green: 0.5, blue: 1.0)
            case .fair:      return Color(red: 0.9, green: 0.7, blue: 0.0)
            case .poor:      return .orange
            case .dangerous: return .red
            }
        }

        var message: String {
            switch self {
            case .excellent: return "Outstanding driving habits."
            case .good:      return "Great driving with minor issues."
            case .fair:      return "Room to improve on some habits."
            case .poor:      return "Several risky behaviors detected."
            case .dangerous: return "Significant safety concerns."
            }
        }
    }

    // MARK: Deduction

    struct Deduction: Identifiable {
        let id = UUID()
        let reason: String
        let points: Int
    }

    // MARK: Compute

    /// Compute a safety score purely from raw TripResult data.
    /// No storage needed — always derived on the fly.
    static func compute(from trip: TripResult) -> SafetyScore {
        var pts = 100
        var deductions: [Deduction] = []

        // Hard brakes: -8 each (capped at 3 events = max -24)
        let brakePenalty = min(trip.hardBrakes, 3) * 8
        if brakePenalty > 0 {
            let label = trip.hardBrakes == 1 ? "1 hard brake" : "\(trip.hardBrakes) hard brakes"
            deductions.append(.init(reason: label, points: brakePenalty))
            pts -= brakePenalty
        }

        // Sharp turns: -5 each (capped at 4 events = max -20)
        let turnPenalty = min(trip.sharpTurns, 4) * 5
        if turnPenalty > 0 {
            let label = trip.sharpTurns == 1 ? "1 sharp turn" : "\(trip.sharpTurns) sharp turns"
            deductions.append(.init(reason: label, points: turnPenalty))
            pts -= turnPenalty
        }

        // Aggressive accels: -6 each (capped at 3 events = max -18)
        let accelPenalty = min(trip.aggressiveAccels, 3) * 6
        if accelPenalty > 0 {
            let label = trip.aggressiveAccels == 1 ? "1 aggressive accel" : "\(trip.aggressiveAccels) aggressive accels"
            deductions.append(.init(reason: label, points: accelPenalty))
            pts -= accelPenalty
        }

        // High average speed
        if let avg = trip.avgSpeedMph, avg > 70 {
            deductions.append(.init(reason: "High avg speed (\(Int(avg)) mph)", points: 10))
            pts -= 10
        }

        // Excessive max speed
        if let max = trip.maxSpeedMph, max > 90 {
            deductions.append(.init(reason: "Excessive max speed (\(Int(max)) mph)", points: 10))
            pts -= 10
        }

        let clamped = max(0, min(100, pts))

        let grade: Grade = {
            switch clamped {
            case 90...100: return .excellent
            case 80..<90:  return .good
            case 70..<80:  return .fair
            case 60..<70:  return .poor
            default:       return .dangerous
            }
        }()

        return SafetyScore(score: clamped, grade: grade, deductions: deductions)
    }
}

// MARK: - TripResult convenience extension

extension TripResult {
    /// Safety score computed on the fly from existing trip data.
    var safetyScore: SafetyScore {
        SafetyScore.compute(from: self)
    }
}

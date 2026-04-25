import Foundation
import SwiftUI

// MARK: - DriveDNA

/// Pure analytics engine. No storage — always derived from TripHistoryStore.trips.
struct DriveDNA {

    let trips: [TripResult]

    // MARK: - Time Slots

    enum TimeSlot: String, CaseIterable, Identifiable {
        case morning   = "Morning"
        case afternoon = "Afternoon"
        case evening   = "Evening"
        case night     = "Night"

        var id: String { rawValue }
        var hours: ClosedRange<Int> {
            switch self {
            case .morning:   return 5...11
            case .afternoon: return 12...16
            case .evening:   return 17...20
            case .night:     return 21...23  // also 0...4, handled in classifier
            }
        }
        var icon: String {
            switch self {
            case .morning:   return "sunrise.fill"
            case .afternoon: return "sun.max.fill"
            case .evening:   return "sunset.fill"
            case .night:     return "moon.stars.fill"
            }
        }
        var color: Color {
            switch self {
            case .morning:   return Color(red: 1.0, green: 0.75, blue: 0.2)
            case .afternoon: return Color(red: 0.2, green: 0.6, blue: 1.0)
            case .evening:   return Color(red: 0.9, green: 0.4, blue: 0.2)
            case .night:     return Color(red: 0.4, green: 0.2, blue: 0.8)
            }
        }

        static func classify(hour: Int) -> TimeSlot {
            switch hour {
            case 5...11:  return .morning
            case 12...16: return .afternoon
            case 17...20: return .evening
            default:      return .night
            }
        }
    }

    // MARK: - Day Buckets

    enum DayGroup: String, CaseIterable, Identifiable {
        case monday = "Mon"; case tuesday = "Tue"; case wednesday = "Wed"
        case thursday = "Thu"; case friday = "Fri"
        case saturday = "Sat"; case sunday = "Sun"
        var id: String { rawValue }

        var weekdayIndex: Int {  // Calendar weekday: Sun=1, Mon=2…
            switch self {
            case .monday: return 2; case .tuesday: return 3; case .wednesday: return 4
            case .thursday: return 5; case .friday: return 6
            case .saturday: return 7; case .sunday: return 1
            }
        }
        var isWeekend: Bool { self == .saturday || self == .sunday }
    }

    // MARK: - Per-trip aggression score (raw, not safety-score inverted)

    static func aggressionScore(_ t: TripResult) -> Double {
        Double(t.hardBrakes * 3 + t.sharpTurns * 2 + t.aggressiveAccels * 2)
    }

    // MARK: - By Day of Week

    struct DayStats {
        let day:             DayGroup
        let tripCount:       Int
        let avgAggression:   Double
        let avgMpg:          Double
    }

    var byDay: [DayStats] {
        DayGroup.allCases.map { day in
            let dayTrips = trips.filter {
                Calendar.current.component(.weekday, from: $0.endedAt) == day.weekdayIndex
            }
            guard !dayTrips.isEmpty else {
                return DayStats(day: day, tripCount: 0, avgAggression: 0, avgMpg: 0)
            }
            return DayStats(
                day:          day,
                tripCount:    dayTrips.count,
                avgAggression: dayTrips.map { Self.aggressionScore($0) }.mean,
                avgMpg:       dayTrips.map { $0.mpg }.mean
            )
        }
    }

    var worstDay: DayStats? {
        byDay.filter { $0.tripCount > 0 }.max(by: { $0.avgAggression < $1.avgAggression })
    }
    var bestDay: DayStats? {
        byDay.filter { $0.tripCount > 0 }.min(by: { $0.avgAggression < $1.avgAggression })
    }

    // MARK: - By Time of Day

    struct TimeStats {
        let slot:          TimeSlot
        let tripCount:     Int
        let avgAggression: Double
    }

    var byTime: [TimeStats] {
        TimeSlot.allCases.map { slot in
            let slotTrips = trips.filter {
                TimeSlot.classify(
                    hour: Calendar.current.component(.hour, from: $0.endedAt)
                ) == slot
            }
            guard !slotTrips.isEmpty else {
                return TimeStats(slot: slot, tripCount: 0, avgAggression: 0)
            }
            return TimeStats(
                slot:          slot,
                tripCount:     slotTrips.count,
                avgAggression: slotTrips.map { Self.aggressionScore($0) }.mean
            )
        }
    }

    // MARK: - Overall Fingerprint Stats

    var totalTrips: Int { trips.count }

    var avgHardBrakesPerTrip: Double {
        guard !trips.isEmpty else { return 0 }
        return Double(trips.map { $0.hardBrakes }.reduce(0, +)) / Double(trips.count)
    }

    var avgSharpTurnsPerTrip: Double {
        guard !trips.isEmpty else { return 0 }
        return Double(trips.map { $0.sharpTurns }.reduce(0, +)) / Double(trips.count)
    }

    var avgAggressiveAccelsPerTrip: Double {
        guard !trips.isEmpty else { return 0 }
        return Double(trips.map { $0.aggressiveAccels }.reduce(0, +)) / Double(trips.count)
    }

    var avgMpg: Double {
        guard !trips.isEmpty else { return 0 }
        return trips.map { $0.mpg }.mean
    }

    var totalMiles: Double {
        trips.compactMap { $0.distanceMiles }.reduce(0, +)
    }

    /// Average aggression score per trip (lower is better)
    var avgAggression: Double {
        guard !trips.isEmpty else { return 0 }
        return trips.map { Self.aggressionScore($0) }.mean
    }

    var weekendVsWeekdayAggression: (weekday: Double, weekend: Double) {
        let weekday = trips.filter {
            let w = Calendar.current.component(.weekday, from: $0.endedAt)
            return (2...6).contains(w)
        }
        let weekend = trips.filter {
            let w = Calendar.current.component(.weekday, from: $0.endedAt)
            return w == 1 || w == 7
        }
        return (
            weekday: weekday.isEmpty ? 0 : weekday.map { Self.aggressionScore($0) }.mean,
            weekend: weekend.isEmpty ? 0 : weekend.map { Self.aggressionScore($0) }.mean
        )
    }

    // MARK: - Fingerprint Grade (based on aggression, not a letter grade)

    /// Label describing overall driving smoothness
    var fingerprintLabel: String {
        switch avgAggression {
        case 0..<2:   return "Smooth"
        case 2..<5:   return "Moderate"
        case 5..<10:  return "Aggressive"
        default:      return "Very Aggressive"
        }
    }

    var fingerprintColor: Color {
        switch avgAggression {
        case 0..<2:  return .green
        case 2..<5:  return Color(red: 0.2, green: 0.5, blue: 1.0)
        case 5..<10: return .orange
        default:     return .red
        }
    }

    // MARK: - Prompt Builder (used by OpenAI)

    func buildPrompt(vehicle: VehicleProfile?) -> String {
        var lines: [String] = []
        lines.append("Analyze this driver's habits across \(totalTrips) saved trips.")
        lines.append("Overall driving style: \(fingerprintLabel)")
        lines.append("Avg aggression score/trip: \(String(format: "%.1f", avgAggression))")
        lines.append("Avg hard brakes/trip: \(String(format: "%.1f", avgHardBrakesPerTrip))")
        lines.append("Avg sharp turns/trip: \(String(format: "%.1f", avgSharpTurnsPerTrip))")
        lines.append("Avg aggressive accels/trip: \(String(format: "%.1f", avgAggressiveAccelsPerTrip))")
        lines.append("Avg MPG: \(String(format: "%.1f", avgMpg))")

        let wv = weekendVsWeekdayAggression
        lines.append("Weekday aggression avg: \(String(format: "%.1f", wv.weekday))")
        lines.append("Weekend aggression avg: \(String(format: "%.1f", wv.weekend))")

        lines.append("\nBy day of week (aggression score):")
        for d in byDay where d.tripCount > 0 {
            lines.append("  \(d.day.rawValue): \(d.tripCount) trips, aggression \(String(format: "%.1f", d.avgAggression))")
        }

        lines.append("\nBy time of day:")
        for t in byTime where t.tripCount > 0 {
            lines.append("  \(t.slot.rawValue): \(t.tripCount) trips, aggression \(String(format: "%.1f", t.avgAggression))")
        }

        if let v = vehicle {
            lines.append("\nVehicle: \(v.year) \(v.make) \(v.model), \(v.fuelType.label)")
        }

        return lines.joined(separator: "\n")
    }
}

// MARK: - Array helpers

private extension Array where Element == Double {
    var mean: Double {
        isEmpty ? 0 : reduce(0, +) / Double(count)
    }
}


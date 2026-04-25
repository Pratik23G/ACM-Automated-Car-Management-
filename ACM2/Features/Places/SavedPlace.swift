import Foundation
import SwiftUI

// MARK: - Place Category

enum PlaceCategory: String, Codable, CaseIterable, Identifiable {
    case home   = "home"
    case work   = "work"
    case school = "school"
    case gym    = "gym"
    case other  = "other"

    var id: String { rawValue }

    var label: String {
        switch self {
        case .home:   return "Home"
        case .work:   return "Work"
        case .school: return "School"
        case .gym:    return "Gym"
        case .other:  return "Other"
        }
    }

    var icon: String {
        switch self {
        case .home:   return "house.fill"
        case .work:   return "briefcase.fill"
        case .school: return "building.columns.fill"
        case .gym:    return "figure.run"
        case .other:  return "mappin.circle.fill"
        }
    }

    var color: Color {
        switch self {
        case .home:   return Color(red: 0.2, green: 0.6, blue: 1.0)
        case .work:   return Color(red: 0.3, green: 0.7, blue: 0.4)
        case .school: return Color(red: 0.9, green: 0.6, blue: 0.1)
        case .gym:    return Color(red: 0.8, green: 0.2, blue: 0.4)
        case .other:  return Color(red: 0.5, green: 0.4, blue: 0.8)
        }
    }
}

// MARK: - Place Reminder

struct PlaceReminder: Identifiable, Codable {
    var id:      UUID   = UUID()
    var title:   String
    var body:    String
    var isActive: Bool  = true
    var createdAt: Date = Date()
}

// MARK: - Trip Pattern (computed from associated trips)

struct TripPattern {
    let avgDurationMinutes:  Double
    let avgDistanceMiles:    Double
    let avgFuelCost:         Double
    let avgAggression:       Double
    let busiestHour:         Int?     // 0-23, most common departure hour
    let busiestDay:          String?  // e.g. "Tuesday"
    let tripCount:           Int

    var avgDurationFormatted: String {
        let m = Int(avgDurationMinutes)
        return m >= 60 ? "\(m/60)h \(m%60)m" : "\(m) min"
    }

    var busiestHourFormatted: String? {
        guard let h = busiestHour else { return nil }
        let fmt = DateFormatter()
        fmt.dateFormat = "h a"
        var comps = DateComponents(); comps.hour = h; comps.minute = 0
        guard let d = Calendar.current.date(from: comps) else { return nil }
        return fmt.string(from: d)
    }

    var busiestTimeLabel: String {
        guard let hour = busiestHour else { return "varies" }
        switch hour {
        case 6..<9:   return "morning rush"
        case 9..<12:  return "mid-morning"
        case 12..<14: return "lunch"
        case 14..<17: return "afternoon"
        case 17..<20: return "evening rush"
        default:      return "off-peak"
        }
    }
}

// MARK: - SavedPlace

struct SavedPlace: Identifiable, Codable {
    var id:          UUID          = UUID()
    var name:        String
    var category:    PlaceCategory
    var customLabel: String?       // overrides category label if set
    var tripIds:     [UUID]        = []   // TripResult IDs associated with this place
    var reminders:   [PlaceReminder] = []
    var createdAt:   Date          = Date()
    var lastVisited: Date?

    var displayName: String { customLabel ?? category.label }

    var tripCount: Int { tripIds.count }

    /// Compute pattern analytics from associated TripResult data
    func pattern(from history: [TripResult]) -> TripPattern? {
        let trips = history.filter { tripIds.contains($0.id) }
        guard !trips.isEmpty else { return nil }

        let avgDuration = Double(trips.map { $0.durationSeconds }.reduce(0, +)) / Double(trips.count) / 60
        let avgDistance = trips.compactMap { $0.distanceMiles }.reduce(0, +) / Double(max(trips.count, 1))
        let avgFuel     = trips.compactMap { $0.estimatedFuelCost }.reduce(0, +) / Double(max(trips.count, 1))
        let avgAgg      = trips.map { Double($0.hardBrakes * 3 + $0.sharpTurns * 2 + $0.aggressiveAccels * 2) }.reduce(0, +) / Double(trips.count)

        // Most common departure hour
        let hours = trips.map { Calendar.current.component(.hour, from: $0.endedAt) }
        let hourCounts = Dictionary(hours.map { ($0, 1) }, uniquingKeysWith: +)
        let busiestHour = hourCounts.max(by: { $0.value < $1.value })?.key

        // Most common day
        let days = trips.map { Calendar.current.component(.weekday, from: $0.endedAt) }
        let dayCounts = Dictionary(days.map { ($0, 1) }, uniquingKeysWith: +)
        let busiestWeekday = dayCounts.max(by: { $0.value < $1.value })?.key
        let dayName: String? = busiestWeekday.map { weekday in
            ["Sun","Mon","Tue","Wed","Thu","Fri","Sat"][safe: weekday - 1] ?? "Unknown"
        }

        return TripPattern(
            avgDurationMinutes: avgDuration,
            avgDistanceMiles:   avgDistance,
            avgFuelCost:        avgFuel,
            avgAggression:      avgAgg,
            busiestHour:        busiestHour,
            busiestDay:         dayName,
            tripCount:          trips.count
        )
    }
}

// MARK: - Safe array subscript

private extension Array {
    subscript(safe index: Int) -> Element? {
        indices.contains(index) ? self[index] : nil
    }
}


import Foundation
import CoreLocation
import SwiftUI

// MARK: - Serializable Coordinate

/// CLLocationCoordinate2D is not Codable — this wrapper is.
struct SerializableCoordinate: Codable, Equatable {
    var latitude:  Double
    var longitude: Double

    init(_ coord: CLLocationCoordinate2D) {
        self.latitude  = coord.latitude
        self.longitude = coord.longitude
    }

    init(latitude: Double, longitude: Double) {
        self.latitude  = latitude
        self.longitude = longitude
    }

    var clCoordinate: CLLocationCoordinate2D {
        CLLocationCoordinate2D(latitude: latitude, longitude: longitude)
    }

    /// Distance in meters from another coordinate.
    func distance(to other: SerializableCoordinate) -> Double {
        let a = CLLocation(latitude: latitude, longitude: longitude)
        let b = CLLocation(latitude: other.latitude, longitude: other.longitude)
        return a.distance(from: b)
    }
}

// MARK: - RouteNote

struct RouteNote: Identifiable, Codable, Equatable {
    var id:          UUID   = UUID()
    var tripId:      UUID                    // links to TripResult.id
    var coordinate:  SerializableCoordinate
    var type:        NoteType
    var title:       String
    var body:        String
    var isReminder:  Bool   = false
    var reminderMessage: String?             // shown when approaching
    var createdAt:   Date   = Date()

    // MARK: NoteType

    enum NoteType: String, Codable, CaseIterable, Identifiable {
        case general     = "general"
        case food        = "food"
        case roadQuality = "roadQuality"
        case hazard      = "hazard"
        case reminder    = "reminder"

        var id: String { rawValue }

        var label: String {
            switch self {
            case .general:     return "Note"
            case .food:        return "Food / Gas"
            case .roadQuality: return "Road Quality"
            case .hazard:      return "Hazard / Warning"
            case .reminder:    return "Reminder"
            }
        }

        var icon: String {
            switch self {
            case .general:     return "note.text"
            case .food:        return "fork.knife"
            case .roadQuality: return "road.lanes"
            case .hazard:      return "exclamationmark.triangle.fill"
            case .reminder:    return "bell.fill"
            }
        }

        var color: Color {
            switch self {
            case .general:     return .blue
            case .food:        return .orange
            case .roadQuality: return Color(red: 0.9, green: 0.7, blue: 0.0)
            case .hazard:      return .red
            case .reminder:    return .purple
            }
        }
    }
}

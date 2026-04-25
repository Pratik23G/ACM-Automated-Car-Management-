import Foundation

/// An automatically-detected drive that has NOT yet been confirmed by the user.
/// Stored in SharedDefaults until the user taps Confirm or Discard.
struct PendingAutoTrip: Codable, Identifiable {

    var id:            UUID   = UUID()
    var detectedAt:    Date   = Date()
    var startedAt:     Date
    var endedAt:       Date
    var source:        Source

    // Estimated metrics (filled in from CoreMotion / GPS when available)
    var estimatedDistanceMiles: Double?
    var estimatedAvgSpeedMph:   Double?
    var durationSeconds: Int {
        Int(endedAt.timeIntervalSince(startedAt))
    }

    var durationFormatted: String {
        let s = durationSeconds
        let h = s / 3600
        let m = (s % 3600) / 60
        if h > 0 { return "\(h)h \(m)m" }
        return "\(m) min"
    }

    enum Source: String, Codable {
        case motionActivity = "motion"    // CMMotionActivityManager detected automotive
        case bluetooth      = "bluetooth" // Car Bluetooth connected/disconnected
    }

    var sourceLabel: String {
        switch source {
        case .motionActivity: return "Auto-detected via motion sensor"
        case .bluetooth:      return "Triggered by car Bluetooth"
        }
    }
}


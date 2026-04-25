import Foundation
import CoreMotion
import Combine
import UserNotifications

/// Monitors motion activity in the background and detects automotive trips.
/// When a drive is detected and completed, it writes a PendingAutoTrip to
/// SharedDefaults and fires a local notification asking the user to confirm.
@MainActor
final class DriveDetector: ObservableObject {

    // MARK: - Published

    @Published var isMonitoring:   Bool = false
    @Published var currentActivity: String = "Unknown"

    // MARK: - Private

    private let motionManager = CMMotionActivityManager()
    private var driveStartTime: Date?
    private var lastAutomotiveDate: Date?

    /// Minimum drive duration to be considered a real trip (avoid brief stops)
    private let minimumTripMinutes: Double = 3

    // MARK: - Availability

    static var isAvailable: Bool { CMMotionActivityManager.isActivityAvailable() }

    // MARK: - Public API

    func startMonitoring() {
        guard Self.isAvailable else { return }
        isMonitoring = true

        motionManager.startActivityUpdates(to: .main) { [weak self] activity in
            guard let self, let activity else { return }
            Task { @MainActor in
                self.process(activity: activity)
            }
        }
    }

    func stopMonitoring() {
        motionManager.stopActivityUpdates()
        isMonitoring = false
        driveStartTime = nil
    }

    /// Query historical motion data for the last N hours (for retroactive detection).
    func queryRecentActivity(hours: Double = 2) {
        guard Self.isAvailable else { return }
        let start = Date().addingTimeInterval(-hours * 3600)
        motionManager.queryActivityStarting(from: start, to: Date(), to: .main) { [weak self] activities, _ in
            guard let self, let activities, !activities.isEmpty else { return }
            Task { @MainActor in
                self.analyzeHistorical(activities: activities)
            }
        }
    }

    // MARK: - Processing

    private func process(activity: CMMotionActivity) {
        currentActivity = activityLabel(activity)

        if activity.automotive && activity.confidence != .low {
            // Started or still driving
            if driveStartTime == nil {
                driveStartTime = activity.startDate
            }
            lastAutomotiveDate = activity.startDate
        } else if !activity.automotive {
            // Stopped — check if we have a completed drive
            finalizeDriveIfNeeded(endTime: activity.startDate)
        }
    }

    private func analyzeHistorical(activities: [CMMotionActivity]) {
        var driveStart: Date?
        var lastAuto: Date?

        for activity in activities.sorted(by: { $0.startDate < $1.startDate }) {
            if activity.automotive && activity.confidence != .low {
                if driveStart == nil { driveStart = activity.startDate }
                lastAuto = activity.startDate
            } else if !activity.automotive, let start = driveStart, let end = lastAuto {
                let duration = end.timeIntervalSince(start) / 60
                if duration >= minimumTripMinutes {
                    createPendingTrip(start: start, end: end, source: .motionActivity)
                }
                driveStart = nil
                lastAuto   = nil
            }
        }

        // Still driving at end of window
        if let start = driveStart, let end = lastAuto {
            let duration = end.timeIntervalSince(start) / 60
            if duration >= minimumTripMinutes {
                createPendingTrip(start: start, end: end, source: .motionActivity)
            }
        }
    }

    private func finalizeDriveIfNeeded(endTime: Date) {
        guard let start = driveStartTime else { return }
        let duration = endTime.timeIntervalSince(start) / 60
        if duration >= minimumTripMinutes {
            createPendingTrip(start: start, end: endTime, source: .motionActivity)
        }
        driveStartTime = nil
        lastAutomotiveDate = nil
    }

    // MARK: - Create Pending Trip

    func createPendingTrip(start: Date, end: Date, source: PendingAutoTrip.Source) {
        // Don't duplicate — check if we already have one for this timeframe
        if let existing = SharedDefaults.pendingAutoTrip,
           abs(existing.startedAt.timeIntervalSince(start)) < 120 { return }

        let pending = PendingAutoTrip(startedAt: start, endedAt: end, source: source)
        SharedDefaults.pendingAutoTrip = pending
        fireDetectionNotification(pending: pending)
    }

    // MARK: - Notification

    private func fireDetectionNotification(pending: PendingAutoTrip) {
        let content = UNMutableNotificationContent()
        content.title = "🚗 Drive Detected"
        content.body  = "ACM noticed a \(pending.durationFormatted) drive. Was this you?"
        content.sound = .default
        content.categoryIdentifier = "DRIVE_CONFIRM"
        content.userInfo = ["tripId": pending.id.uuidString]

        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: 2, repeats: false)
        let request = UNNotificationRequest(
            identifier: "drive_\(pending.id.uuidString)",
            content: content,
            trigger: trigger
        )
        UNUserNotificationCenter.current().add(request)
    }

    // MARK: - Register Notification Actions

    static func registerNotificationCategories() {
        let confirm = UNNotificationAction(
            identifier: "CONFIRM_DRIVE",
            title: "Yes, Save It",
            options: [.foreground]
        )
        let discard = UNNotificationAction(
            identifier: "DISCARD_DRIVE",
            title: "No, Discard",
            options: [.destructive]
        )
        let category = UNNotificationCategory(
            identifier: "DRIVE_CONFIRM",
            actions: [confirm, discard],
            intentIdentifiers: []
        )
        UNUserNotificationCenter.current().setNotificationCategories([category])
    }

    // MARK: - Helpers

    private func activityLabel(_ a: CMMotionActivity) -> String {
        if a.automotive { return "Driving 🚗" }
        if a.running    { return "Running 🏃" }
        if a.cycling    { return "Cycling 🚴" }
        if a.walking    { return "Walking 🚶" }
        if a.stationary { return "Stationary ⏸" }
        return "Unknown"
    }
}

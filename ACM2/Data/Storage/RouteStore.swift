import Foundation
import Combine
import CoreLocation
import UserNotifications

@MainActor
final class RouteStore: ObservableObject {

    @Published private(set) var routes: [TripRoute] = []

    // Notes that carry isReminder=true across ALL past trips, used for proximity alerts.
    var allReminderNotes: [RouteNote] {
        routes.flatMap { $0.notes }.filter { $0.isReminder }
    }

    private let fileURL: URL = {
        let docs = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
        return docs.appendingPathComponent("trip_routes.json")
    }()

    // Track which reminder note ids have already fired this trip session
    private var firedReminderIds: Set<UUID> = []
    /// Radius in meters that triggers a reminder notification.
    private let reminderRadius: Double = 350

    // MARK: - Init

    init() { load() }

    // MARK: - Active Trip Building

    /// Called by TripManager on every GPS update while a trip is active.
    func appendCoordinate(_ coord: SerializableCoordinate, toTripId id: UUID) {
        if let idx = routes.firstIndex(where: { $0.id == id }) {
            routes[idx].coordinates.append(coord)
        } else {
            var newRoute = TripRoute(id: id)
            newRoute.coordinates.append(coord)
            routes.insert(newRoute, at: 0)
        }
        // No save here — we batch-save on trip end for performance.
    }

    /// Called when the user drops a note during a trip.
    func addNote(_ note: RouteNote) {
        if let idx = routes.firstIndex(where: { $0.id == note.tripId }) {
            routes[idx].notes.append(note)
        } else {
            var newRoute = TripRoute(id: note.tripId)
            newRoute.notes.append(note)
            routes.insert(newRoute, at: 0)
        }
        save()
    }

    func deleteNote(id: UUID, fromTripId tripId: UUID) {
        guard let rIdx = routes.firstIndex(where: { $0.id == tripId }),
              let nIdx = routes[rIdx].notes.firstIndex(where: { $0.id == id }) else { return }
        routes[rIdx].notes.remove(at: nIdx)
        save()
    }

    /// Finalise a trip's route (set endedAt and persist).
    func finaliseRoute(tripId: UUID) {
        guard let idx = routes.firstIndex(where: { $0.id == tripId }) else { return }
        routes[idx].endedAt = Date()
        firedReminderIds.removeAll()
        save()
    }

    // MARK: - Proximity Reminders

    /// Call this on every location update while a trip is active.
    func checkProximityReminders(location: CLLocation) {
        for note in allReminderNotes where !firedReminderIds.contains(note.id) {
            let noteLoc = CLLocation(latitude: note.coordinate.latitude,
                                     longitude: note.coordinate.longitude)
            if location.distance(from: noteLoc) <= reminderRadius {
                firedReminderIds.insert(note.id)
                fireReminderNotification(note: note)
            }
        }
    }

    // MARK: - Notification

    func requestNotificationPermission() {
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound]) { _, _ in }
    }

    private func fireReminderNotification(note: RouteNote) {
        let content = UNMutableNotificationContent()
        content.title = "📍 Reminder: \(note.title)"
        content.body  = note.reminderMessage ?? note.body
        content.sound = .default

        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: 1, repeats: false)
        let request = UNNotificationRequest(
            identifier: note.id.uuidString,
            content: content,
            trigger: trigger
        )
        UNUserNotificationCenter.current().add(request)
    }

    // MARK: - Route Management

    func deleteRoute(id: UUID) {
        routes.removeAll { $0.id == id }
        save()
    }

    func route(for tripId: UUID) -> TripRoute? {
        routes.first { $0.id == tripId }
    }

    func upsert(_ route: TripRoute) {
        if let idx = routes.firstIndex(where: { $0.id == route.id }) {
            routes[idx] = route
        } else {
            routes.insert(route, at: 0)
        }
        save()
    }

    // MARK: - Persistence

    private func save() {
        do {
            let enc = JSONEncoder()
            enc.dateEncodingStrategy = .iso8601
            enc.outputFormatting = [.prettyPrinted]
            let data = try enc.encode(routes)
            try data.write(to: fileURL, options: [.atomic])
        } catch {
            print("❌ RouteStore save error:", error)
        }
    }

    private func load() {
        guard FileManager.default.fileExists(atPath: fileURL.path) else { return }
        do {
            let data = try Data(contentsOf: fileURL)
            let dec = JSONDecoder()
            dec.dateDecodingStrategy = .iso8601
            routes = try dec.decode([TripRoute].self, from: data)
        } catch {
            print("❌ RouteStore load error:", error)
        }
    }
}

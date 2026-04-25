import Foundation

/// Single source of truth shared between the main app and the widget extension.
/// Both targets must have the same App Group: group.com.acm2.shared
/// Add this capability in Xcode: Target → Signing & Capabilities → + App Group
enum SharedDefaults {

    static let suiteName = "group.com.acm2.shared"

    private static var store: UserDefaults {
        UserDefaults(suiteName: suiteName) ?? .standard
    }

    // MARK: - Keys

    private enum Key {
        static let tripActive       = "tripActive"
        static let tripStartedAt    = "tripStartedAt"
        static let vehicleDisplay   = "vehicleDisplay"
        static let elapsedSeconds   = "elapsedSeconds"
        static let pendingAutoTrip  = "pendingAutoTrip"   // JSON-encoded PendingAutoTrip?
    }

    // MARK: - Trip State (written by main app, read by widget)

    static var isTripActive: Bool {
        get { store.bool(forKey: Key.tripActive) }
        set { store.set(newValue, forKey: Key.tripActive) }
    }

    static var tripStartedAt: Date? {
        get { store.object(forKey: Key.tripStartedAt) as? Date }
        set { store.set(newValue, forKey: Key.tripStartedAt) }
    }

    static var vehicleDisplayName: String {
        get { store.string(forKey: Key.vehicleDisplay) ?? "My Vehicle" }
        set { store.set(newValue, forKey: Key.vehicleDisplay) }
    }

    static var elapsedSeconds: Int {
        get { store.integer(forKey: Key.elapsedSeconds) }
        set { store.set(newValue, forKey: Key.elapsedSeconds) }
    }

    // MARK: - Pending Auto Trip (written by DriveDetector, read by main app)

    static var pendingAutoTrip: PendingAutoTrip? {
        get {
            guard let data = store.data(forKey: Key.pendingAutoTrip) else { return nil }
            return try? JSONDecoder().decode(PendingAutoTrip.self, from: data)
        }
        set {
            if let value = newValue,
               let data = try? JSONEncoder().encode(value) {
                store.set(data, forKey: Key.pendingAutoTrip)
            } else {
                store.removeObject(forKey: Key.pendingAutoTrip)
            }
        }
    }

    // MARK: - URL Scheme

    /// Deep-link URL the widget opens to trigger a trip action.
    static func url(action: String) -> URL {
        URL(string: "acm2://\(action)")!
    }
}


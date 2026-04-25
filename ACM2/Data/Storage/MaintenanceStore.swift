import Foundation
import Combine

@MainActor
final class MaintenanceStore: ObservableObject {

    @Published var reminders: [MaintenanceReminder] = []

    private let fileURL: URL = {
        let docs = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
        return docs.appendingPathComponent("maintenance.json")
    }()

    init() { load(); initializeDefaultsIfNeeded() }

    // MARK: - Public API

    func markServiced(id: UUID, currentOdometer: Double) {
        guard let idx = reminders.firstIndex(where: { $0.id == id }) else { return }
        reminders[idx].lastServiceOdometer = currentOdometer
        reminders[idx].lastServiceDate = Date()
        save()
    }

    func updateInterval(id: UUID, miles: Double) {
        guard let idx = reminders.firstIndex(where: { $0.id == id }) else { return }
        reminders[idx].intervalMiles = miles
        save()
    }

    /// Clears all "last serviced" dates and odometer readings.
    /// Called when the user switches to a different vehicle make/model.
    func resetServiceHistory() {
        for idx in reminders.indices {
            reminders[idx].lastServiceDate     = nil
            reminders[idx].lastServiceOdometer = nil
        }
        save()
    }

    // MARK: - Private

    private func initializeDefaultsIfNeeded() {
        guard reminders.isEmpty else { return }
        reminders = MaintenanceReminder.ServiceType.allCases.map {
            MaintenanceReminder(serviceType: $0, intervalMiles: $0.defaultIntervalMiles)
        }
        save()
    }

    private func save() {
        do {
            let enc = JSONEncoder(); enc.dateEncodingStrategy = .iso8601
            try enc.encode(reminders).write(to: fileURL, options: .atomic)
        } catch { print("❌ MaintenanceStore save error:", error) }
    }

    private func load() {
        guard FileManager.default.fileExists(atPath: fileURL.path) else { return }
        do {
            let dec = JSONDecoder(); dec.dateDecodingStrategy = .iso8601
            reminders = try dec.decode([MaintenanceReminder].self,
                                       from: Data(contentsOf: fileURL))
        } catch { print("❌ MaintenanceStore load error:", error) }
    }
}


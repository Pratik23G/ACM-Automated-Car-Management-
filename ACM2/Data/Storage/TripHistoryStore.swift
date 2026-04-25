import Foundation
import Combine

@MainActor
final class TripHistoryStore: ObservableObject {
    @Published private(set) var trips: [TripResult] = []

    private let saveURL: URL

    init() {
        let docs = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
        self.saveURL = docs.appendingPathComponent("trips.json")
        load()
    }

    // MARK: - Public API

    func add(_ trip: TripResult) {
        if let idx = trips.firstIndex(where: { $0.id == trip.id }) {
            trips[idx] = trip
        } else {
            trips.insert(trip, at: 0) // newest first
        }
        save()
    }

    func delete(at offsets: IndexSet) {
        for index in offsets.sorted(by: >) {
            trips.remove(at: index)
        }
        save()
    }

    func delete(id: UUID) {
        trips.removeAll { $0.id == id }
        save()
    }

    func isSaved(_ id: UUID) -> Bool {
        trips.contains { $0.id == id }
    }

    // MARK: - Computed

    /// Sum of all distanceMiles across saved trips. Used by MaintenanceView.
    var totalMilesEstimated: Double {
        trips.compactMap { $0.distanceMiles }.reduce(0, +)
    }

    // MARK: - Persistence

    private func save() {
        do {
            let encoder = JSONEncoder()
            encoder.outputFormatting = [.prettyPrinted]
            encoder.dateEncodingStrategy = .iso8601
            let data = try encoder.encode(trips)
            try data.write(to: saveURL, options: [.atomic])
        } catch {
            print("❌ TripHistoryStore save error:", error)
        }
    }

    private func load() {
        do {
            guard FileManager.default.fileExists(atPath: saveURL.path) else { return }
            let data = try Data(contentsOf: saveURL)
            let decoder = JSONDecoder()
            decoder.dateDecodingStrategy = .iso8601
            trips = try decoder.decode([TripResult].self, from: data)
        } catch {
            print("❌ TripHistoryStore load error:", error)
        }
    }
}


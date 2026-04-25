import Foundation
import Combine

@MainActor
final class FuelPriceSnapshotStore: ObservableObject {
    @Published private(set) var snapshots: [FuelPriceSnapshot] = []

    private let fileURL: URL = {
        let docs = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
        return docs.appendingPathComponent("fuel_price_snapshots.json")
    }()

    init() {
        load()
    }

    func add(_ snapshot: FuelPriceSnapshot) {
        let startOfDay = Calendar.current.startOfDay(for: snapshot.capturedAt)
        if let index = snapshots.firstIndex(where: {
            $0.areaLabel == snapshot.areaLabel &&
            Calendar.current.isDate(Calendar.current.startOfDay(for: $0.capturedAt), inSameDayAs: startOfDay)
        }) {
            snapshots[index] = snapshot
        } else {
            snapshots.insert(snapshot, at: 0)
        }
        snapshots.sort { $0.capturedAt > $1.capturedAt }
        save()
    }

    func history(for areaLabel: String) -> [FuelPriceSnapshot] {
        snapshots
            .filter { $0.areaLabel == areaLabel }
            .sorted { $0.capturedAt > $1.capturedAt }
    }

    private func save() {
        do {
            let encoder = JSONEncoder()
            encoder.outputFormatting = [.prettyPrinted]
            encoder.dateEncodingStrategy = .iso8601
            let data = try encoder.encode(snapshots)
            try data.write(to: fileURL, options: [.atomic])
        } catch {
            print("❌ FuelPriceSnapshotStore save error:", error)
        }
    }

    private func load() {
        guard FileManager.default.fileExists(atPath: fileURL.path) else { return }
        do {
            let data = try Data(contentsOf: fileURL)
            let decoder = JSONDecoder()
            decoder.dateDecodingStrategy = .iso8601
            snapshots = try decoder.decode([FuelPriceSnapshot].self, from: data)
            snapshots.sort { $0.capturedAt > $1.capturedAt }
        } catch {
            print("❌ FuelPriceSnapshotStore load error:", error)
        }
    }
}

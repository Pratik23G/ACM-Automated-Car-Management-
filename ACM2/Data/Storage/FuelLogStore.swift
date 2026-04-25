import Foundation
import Combine

@MainActor
final class FuelLogStore: ObservableObject {
    @Published private(set) var logs: [FuelLog] = []

    private let saveURL: URL

    init() {
        let docs = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
        saveURL = docs.appendingPathComponent("fuel_logs.json")
        load()
    }

    func add(_ log: FuelLog) {
        if let index = logs.firstIndex(where: { $0.id == log.id }) {
            logs[index] = log
        } else {
            logs.insert(log, at: 0)
        }
        save()
    }

    func totalCost(in interval: DateInterval) -> Double {
        logs.filter { interval.contains($0.loggedAt) }.reduce(0) { $0 + $1.totalCost }
    }

    func averageDailyCost(last days: Int) -> Double {
        guard days > 0 else { return 0 }
        let start = Calendar.current.date(byAdding: .day, value: -(days - 1), to: Date()) ?? Date()
        let interval = DateInterval(start: start, end: Date().addingTimeInterval(1))
        return totalCost(in: interval) / Double(days)
    }

    private func save() {
        do {
            let encoder = JSONEncoder()
            encoder.outputFormatting = [.prettyPrinted]
            encoder.dateEncodingStrategy = .iso8601
            let data = try encoder.encode(logs)
            try data.write(to: saveURL, options: [.atomic])
        } catch {
            print("FuelLogStore save error:", error)
        }
    }

    private func load() {
        do {
            guard FileManager.default.fileExists(atPath: saveURL.path) else { return }
            let data = try Data(contentsOf: saveURL)
            let decoder = JSONDecoder()
            decoder.dateDecodingStrategy = .iso8601
            logs = try decoder.decode([FuelLog].self, from: data)
        } catch {
            print("FuelLogStore load error:", error)
        }
    }
}

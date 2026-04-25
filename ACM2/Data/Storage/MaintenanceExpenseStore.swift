import Foundation
import Combine

@MainActor
final class MaintenanceExpenseStore: ObservableObject {
    @Published private(set) var expenses: [MaintenanceExpense] = []

    private let saveURL: URL

    init() {
        let docs = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
        saveURL = docs.appendingPathComponent("maintenance_expenses.json")
        load()
    }

    func add(_ expense: MaintenanceExpense) {
        if let index = expenses.firstIndex(where: { $0.id == expense.id }) {
            expenses[index] = expense
        } else {
            expenses.insert(expense, at: 0)
        }
        save()
    }

    private func save() {
        do {
            let encoder = JSONEncoder()
            encoder.outputFormatting = [.prettyPrinted]
            encoder.dateEncodingStrategy = .iso8601
            let data = try encoder.encode(expenses)
            try data.write(to: saveURL, options: [.atomic])
        } catch {
            print("MaintenanceExpenseStore save error:", error)
        }
    }

    private func load() {
        do {
            guard FileManager.default.fileExists(atPath: saveURL.path) else { return }
            let data = try Data(contentsOf: saveURL)
            let decoder = JSONDecoder()
            decoder.dateDecodingStrategy = .iso8601
            expenses = try decoder.decode([MaintenanceExpense].self, from: data)
        } catch {
            print("MaintenanceExpenseStore load error:", error)
        }
    }
}

import SwiftUI

struct MaintenanceExpenseSheet: View {
    @Environment(\.dismiss) private var dismiss

    @State private var purchasedAt = Date()
    @State private var category: MaintenanceExpense.Category = .oil
    @State private var itemName = ""
    @State private var purchaseLocation = ""
    @State private var totalCostText = ""
    @State private var notes = ""

    let onSave: (MaintenanceExpense) -> Void

    var body: some View {
        NavigationStack {
            Form {
                Section("Part or Service") {
                    DatePicker("Date", selection: $purchasedAt, displayedComponents: .date)
                    Picker("Category", selection: $category) {
                        ForEach(MaintenanceExpense.Category.allCases) { category in
                            Text(category.label).tag(category)
                        }
                    }
                    TextField("Item name", text: $itemName)
                    TextField("Location", text: $purchaseLocation)
                    TextField("Price", text: $totalCostText)
                        .keyboardType(.decimalPad)
                }

                Section("Notes") {
                    TextField(
                        "Example: bought new front tires after noticing uneven tread wear",
                        text: $notes,
                        axis: .vertical
                    )
                    .lineLimit(3...6)
                }
            }
            .navigationTitle("Add Maintenance Cost")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }

                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        save()
                    }
                    .disabled(!canSave)
                }
            }
        }
    }

    private var parsedCost: Double? {
        Double(totalCostText.replacingOccurrences(of: ",", with: ""))
    }

    private var canSave: Bool {
        itemName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == false
            && purchaseLocation.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == false
            && (parsedCost ?? 0) > 0
    }

    private func save() {
        guard let parsedCost, canSave else { return }

        onSave(
            MaintenanceExpense(
                purchasedAt: purchasedAt,
                category: category,
                itemName: itemName.trimmingCharacters(in: .whitespacesAndNewlines),
                purchaseLocation: purchaseLocation.trimmingCharacters(in: .whitespacesAndNewlines),
                totalCost: parsedCost,
                notes: notes.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                    ? nil
                    : notes.trimmingCharacters(in: .whitespacesAndNewlines)
            )
        )
        dismiss()
    }
}

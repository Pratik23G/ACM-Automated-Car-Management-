import SwiftUI

struct FuelLogSheet: View {
    @Environment(\.dismiss) private var dismiss

    let coordinate: SerializableCoordinate?
    let defaultArea: String
    let onSave: (FuelLog) -> Void

    @State private var stationName = ""
    @State private var areaLabel: String
    @State private var selectedProduct: FuelProduct
    @State private var priceText = ""
    @State private var amountText = ""
    @State private var promoTitle = ""

    init(
        coordinate: SerializableCoordinate?,
        defaultArea: String,
        preferredProduct: FuelProduct,
        onSave: @escaping (FuelLog) -> Void
    ) {
        self.coordinate = coordinate
        self.defaultArea = defaultArea
        self.onSave = onSave
        _areaLabel = State(initialValue: defaultArea)
        _selectedProduct = State(initialValue: preferredProduct)
    }

    private var totalCost: Double {
        let price = Double(priceText.replacingOccurrences(of: ",", with: ".")) ?? 0
        let amount = Double(amountText.replacingOccurrences(of: ",", with: ".")) ?? 0
        return price * amount
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Station") {
                    TextField("Station name", text: $stationName)
                    TextField("Area", text: $areaLabel)
                    if coordinate != nil {
                        Text("Using your current map location for this fill-up.")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    } else {
                        Text("No live map coordinate available, so this save will be profile-only.")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }

                Section("Fuel") {
                    Picker("Product", selection: $selectedProduct) {
                        ForEach(FuelProduct.allCases) { product in
                            Text(product.label).tag(product)
                        }
                    }
                    TextField("Price per gallon", text: $priceText)
                        .keyboardType(.decimalPad)
                    TextField("Amount (gallons)", text: $amountText)
                        .keyboardType(.decimalPad)
                    TextField("Promo or rewards note", text: $promoTitle)
                }

                Section("Summary") {
                    Row(label: "Estimated total", value: String(format: "$%.2f", totalCost))
                    Text("This manual logger is the UI seam for your later Tinyfish station picker and Redis/AWS backend save.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            .navigationTitle("Log Fuel Stop")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Save") { save() }
                        .disabled(!canSave)
                }
            }
        }
        .presentationDetents([.medium, .large])
    }

    private var canSave: Bool {
        !stationName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        && (Double(priceText.replacingOccurrences(of: ",", with: ".")) ?? 0) > 0
        && (Double(amountText.replacingOccurrences(of: ",", with: ".")) ?? 0) > 0
    }

    private func save() {
        let log = FuelLog(
            stationName: stationName.trimmingCharacters(in: .whitespacesAndNewlines),
            areaLabel: areaLabel.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? defaultArea : areaLabel,
            coordinate: coordinate,
            fuelProduct: selectedProduct,
            pricePerUnit: Double(priceText.replacingOccurrences(of: ",", with: ".")) ?? 0,
            amount: Double(amountText.replacingOccurrences(of: ",", with: ".")) ?? 0,
            promoTitle: promoTitle.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? nil : promoTitle,
            totalCostOverride: nil
        )
        onSave(log)
        dismiss()
    }
}

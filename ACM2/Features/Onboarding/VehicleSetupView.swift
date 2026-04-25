import SwiftUI

struct VehicleSetupView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject var vehicleStore:     VehicleProfileStore
    @EnvironmentObject var maintenanceStore: MaintenanceStore

    let existingProfile: VehicleProfile?

    private let makes: [String] = [
        "Tesla","Toyota","Honda","Ford","Chevrolet","BMW","Mercedes-Benz","Volkswagen","Other"
    ]
    private let modelsByMake: [String: [String]] = [
        "Tesla":         ["Model 3","Model Y","Model S","Model X","Cybertruck","Other"],
        "Toyota":        ["Camry","Corolla","RAV4","Prius","Tacoma","Other"],
        "Honda":         ["Civic","Accord","CR-V","Pilot","Other"],
        "Ford":          ["F-150","Mustang","Explorer","Other"],
        "Chevrolet":     ["Silverado","Malibu","Tahoe","Other"],
        "BMW":           ["3 Series","5 Series","X3","X5","Other"],
        "Mercedes-Benz": ["C-Class","E-Class","GLC","GLE","Other"],
        "Volkswagen":    ["Jetta","Golf","Tiguan","Passat","Other"],
        "Other":         ["Other"]
    ]
    private let years: [Int] = Array(
        (1990...Calendar.current.component(.year, from: Date()) + 1).reversed()
    )

    @State private var selectedMake:  String
    @State private var selectedModel: String
    @State private var selectedYear:  Int
    @State private var fuelType:      FuelType
    @State private var mpgText:       String
    @State private var miPerKwhText:  String
    @State private var odometerText:  String
    @State private var homeAreaText:  String
    @State private var weeklyMilesText: String
    @State private var commonRoutesText: String
    @State private var preferredFuelProduct: FuelProduct
    @State private var stationPreference: FuelStationPreference
    @State private var prioritizePromos: Bool
    @State private var trackBrakes:   Bool
    @State private var brakePadsInstalledAt: Date
    @State private var motionAutoDetect:     Bool
    @State private var bluetoothDeviceUUID:  String?
    @State private var bluetoothDeviceName:  String?
    @State private var showBTPairing         = false
    @State private var showTypeChangeWarning = false
    @State private var pendingSave:          VehicleProfile?

    private var isEditing: Bool { existingProfile != nil }
    private var profileId: UUID { existingProfile?.id ?? UUID() }

    init(existingProfile: VehicleProfile?) {
        self.existingProfile = existingProfile
        let p = existingProfile
        _selectedMake  = State(initialValue: p?.make  ?? "Toyota")
        _selectedModel = State(initialValue: p?.model ?? "Camry")
        _selectedYear  = State(initialValue: p?.year  ?? Calendar.current.component(.year, from: Date()))
        _fuelType      = State(initialValue: p?.fuelType ?? .gasoline)
        _mpgText       = State(initialValue: p?.mpg.map      { String(format: "%.0f", $0) } ?? "")
        _miPerKwhText  = State(initialValue: p?.miPerKwh.map { String(format: "%.1f", $0) } ?? "")
        _odometerText  = State(initialValue: p?.currentOdometerMiles.map { String(Int($0)) } ?? "")
        _homeAreaText = State(initialValue: p?.homeArea ?? "")
        _weeklyMilesText = State(initialValue: p.map { String(Int($0.weeklyMiles)) } ?? "140")
        _commonRoutesText = State(initialValue: p?.commonRoutes.joined(separator: ", ") ?? "")
        _preferredFuelProduct = State(initialValue: p?.preferredFuelProduct ?? .regular)
        _stationPreference = State(initialValue: p?.stationPreference ?? .balanced)
        _prioritizePromos = State(initialValue: p?.prioritizePromos ?? true)
        _trackBrakes   = State(initialValue: p?.brakePadsInstalledAt != nil)
        _brakePadsInstalledAt = State(initialValue: p?.brakePadsInstalledAt ?? Date())
        _motionAutoDetect    = State(initialValue: p?.motionAutoDetectEnabled ?? true)
        _bluetoothDeviceUUID = State(initialValue: p?.bluetoothDeviceUUID)
        _bluetoothDeviceName = State(initialValue: p?.bluetoothDeviceName)
    }

    // MARK: - Body

    var body: some View {
        NavigationStack {
            Form {
                vehicleSection
                powertrainSection
                fuelAgentSection
                maintenanceSection
                if isEditing { editWarningSection }
                autoDetectSection
                saveSection
            }
            .navigationTitle(isEditing ? "Edit Vehicle" : "Add Vehicle")
            .navigationBarTitleDisplayMode(.inline)
            .sheet(isPresented: $showBTPairing) {
                BluetoothPairingView(
                    pairedDeviceUUID: $bluetoothDeviceUUID,
                    pairedDeviceName: $bluetoothDeviceName
                )
            }
            .toolbar {
                if isEditing {
                    ToolbarItem(placement: .topBarLeading) {
                        Button("Cancel") { dismiss() }
                    }
                }
            }
            .alert("Vehicle Type Changed",
                   isPresented: $showTypeChangeWarning,
                   presenting: pendingSave) { pending in
                Button("Save & Keep History") {
                    vehicleStore.save(pending); dismiss()
                }
                Button("Save & Reset Service History", role: .destructive) {
                    vehicleStore.save(pending)
                    maintenanceStore.resetServiceHistory()
                    dismiss()
                }
                Button("Cancel", role: .cancel) { pendingSave = nil }
            } message: { _ in
                Text("Changing the make or model will affect maintenance tracking. Odometer and trip history are always kept.")
            }
        }
    }

    // MARK: - Sections (split out so Swift can type-check each independently)

    private var vehicleSection: some View {
        Section("Vehicle") {
            Picker("Make", selection: $selectedMake) {
                ForEach(makes, id: \.self) { Text($0).tag($0) }
            }
            .onChange(of: selectedMake) { _, newMake in
                selectedModel = modelsByMake[newMake]?.first ?? "Other"
            }
            Picker("Model", selection: $selectedModel) {
                ForEach(modelsByMake[selectedMake] ?? ["Other"], id: \.self) {
                    Text($0).tag($0)
                }
            }
            Picker("Year", selection: $selectedYear) {
                ForEach(years, id: \.self) { y in Text(verbatim: "\(y)").tag(y) }
            }
        }
    }

    private var powertrainSection: some View {
        Section("Powertrain") {
            Picker("Fuel Type", selection: $fuelType) {
                ForEach(FuelType.allCases) { Text($0.label).tag($0) }
            }
            .onChange(of: fuelType) { _, _ in
                if !filteredFuelProducts.contains(preferredFuelProduct) {
                    preferredFuelProduct = filteredFuelProducts.first ?? .regular
                }
            }
            if fuelType == .electric {
                TextField("mi/kWh (optional)", text: $miPerKwhText)
                    .keyboardType(.decimalPad)
            } else {
                TextField("MPG (optional)", text: $mpgText)
                    .keyboardType(.decimalPad)
            }
        }
    }

    private var maintenanceSection: some View {
        Section("Maintenance") {
            TextField("Current odometer (miles, optional)", text: $odometerText)
                .keyboardType(.numberPad)
            Toggle("Track brake pad install date", isOn: $trackBrakes)
            if trackBrakes {
                DatePicker("Brake pads installed",
                           selection: $brakePadsInstalledAt,
                           displayedComponents: .date)
            }
        }
    }

    private var fuelAgentSection: some View {
        Section("Fuel Agent Preferences") {
            TextField("Home area or ZIP", text: $homeAreaText)
                .textInputAutocapitalization(.words)

            TextField("Weekly miles", text: $weeklyMilesText)
                .keyboardType(.decimalPad)

            TextField("Common routes (comma separated)", text: $commonRoutesText, axis: .vertical)

            Picker("Preferred Product", selection: $preferredFuelProduct) {
                ForEach(filteredFuelProducts) { product in
                    Text(product.label).tag(product)
                }
            }

            Picker("Station Strategy", selection: $stationPreference) {
                ForEach(FuelStationPreference.allCases) { preference in
                    Text(preference.label).tag(preference)
                }
            }

            Toggle("Prioritize promo stations", isOn: $prioritizePromos)

            Text("This is the profile layer for your future Tinyfish, Redis, Vapi, and backend fuel personalization.")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }

    private var editWarningSection: some View {
        Section {
            Text("⚠️ If you change your vehicle's make or model, you will be prompted about maintenance service history. Your odometer reading and trip data will always be preserved.")
                .font(.footnote)
                .foregroundStyle(Color.orange)
        }
    }

    private var autoDetectSection: some View {
        Section(
            header: Text("Auto Trip Detection"),
            footer: Text("No Bluetooth in your car? Motion auto-detect and the home screen widget both work without it.").font(.caption)
        ) {
            Toggle(isOn: $motionAutoDetect) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Motion Auto-Detect")
                    Text("iPhone detects drives automatically")
                        .font(.caption).foregroundStyle(Color.secondary)
                }
            }
            bluetoothRow
        }
    }

    private var saveSection: some View {
        Section {
            Button(isEditing ? "Save Changes" : "Add Vehicle") {
                attemptSave()
            }
            .font(.headline)
        }
    }

    // MARK: - Bluetooth Row

    private var bluetoothRow: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text("Car Bluetooth")
                Text(bluetoothDeviceName ?? "Not paired — optional")
                    .font(.caption)
                    .foregroundStyle(bluetoothDeviceName != nil ? Color.green : Color.secondary)
            }
            Spacer()
            Button(bluetoothDeviceName != nil ? "Change" : "Pair") {
                showBTPairing = true
            }
            .font(.subheadline)
            .foregroundStyle(Color.blue)
        }
    }

    // MARK: - Save Logic

    private func attemptSave() {
        let mpg      = Double(mpgText.replacingOccurrences(of: ",", with: "."))
        let miPerKwh = Double(miPerKwhText.replacingOccurrences(of: ",", with: "."))
        let odometer = Double(odometerText.replacingOccurrences(of: ",", with: ""))
        let weeklyMiles = Double(weeklyMilesText.replacingOccurrences(of: ",", with: "."))
        let commonRoutes = commonRoutesText
            .components(separatedBy: CharacterSet(charactersIn: ",\n"))
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }

        let profile = VehicleProfile(
            id:       profileId,
            make:     selectedMake,
            model:    selectedModel,
            year:     selectedYear,
            fuelType: fuelType,
            mpg:      (fuelType == .electric) ? nil : mpg,
            miPerKwh: (fuelType == .electric) ? miPerKwh : nil,
            brakePadsInstalledAt:    trackBrakes ? brakePadsInstalledAt : nil,
            currentOdometerMiles:    odometer,
            homeArea:                homeAreaText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? nil : homeAreaText.trimmingCharacters(in: .whitespacesAndNewlines),
            preferredFuelProduct:    preferredFuelProduct,
            stationPreference:       stationPreference,
            prioritizePromos:        prioritizePromos,
            weeklyMiles:             max(weeklyMiles ?? existingProfile?.weeklyMiles ?? 140, 0),
            commonRoutes:            commonRoutes,
            bluetoothDeviceUUID:     bluetoothDeviceUUID,
            bluetoothDeviceName:     bluetoothDeviceName,
            motionAutoDetectEnabled: motionAutoDetect
        )

        if isEditing, let old = existingProfile,
           vehicleStore.isVehicleTypeChange(from: old, to: profile) {
            pendingSave = profile
            showTypeChangeWarning = true
        } else {
            vehicleStore.save(profile)
            dismiss()
        }
    }

    private var filteredFuelProducts: [FuelProduct] {
        switch fuelType {
        case .diesel:
            return [.diesel]
        case .electric:
            return [.electric]
        case .hybrid, .gasoline:
            return [.regular, .midgrade, .premium, .flexible]
        }
    }
}

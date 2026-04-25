import SwiftUI

struct VehicleListView: View {

    @EnvironmentObject var vehicleStore:     VehicleProfileStore
    @EnvironmentObject var maintenanceStore: MaintenanceStore

    @State private var showAddSheet    = false
    @State private var editingProfile: VehicleProfile?
    @State private var deleteTarget:   VehicleProfile?
    @State private var switchTarget:   VehicleProfile?  // triggers maintenance warning if needed
    @State private var showMaintenanceWarning = false
    @State private var pendingSwitch:  VehicleProfile?

    var body: some View {
        List {
            Section {
                ForEach(vehicleStore.profiles) { profile in
                    vehicleRow(profile)
                }
                .onDelete { offsets in
                    for idx in offsets {
                        let p = vehicleStore.profiles[idx]
                        vehicleStore.delete(id: p.id)
                    }
                }
            } footer: {
                Text("Tap a vehicle to make it active. Swipe left to delete.")
                    .font(.caption)
            }

            Section {
                Button {
                    editingProfile = nil
                    showAddSheet   = true
                } label: {
                    Label("Add New Vehicle", systemImage: "plus.circle.fill")
                        .foregroundStyle(Color.accentColor)
                }
            }
        }
        .navigationTitle("My Vehicles")
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) { EditButton() }
        }
        // Add new vehicle
        .sheet(isPresented: $showAddSheet) {
            VehicleSetupView(existingProfile: nil)
        }
        // Edit existing vehicle
        .sheet(item: $editingProfile) { profile in
            VehicleSetupView(existingProfile: profile)
        }
        // Maintenance warning when switching to a different car type
        .alert("Switch Vehicle?", isPresented: $showMaintenanceWarning,
               presenting: pendingSwitch) { pending in
            Button("Switch & Keep History") {
                vehicleStore.setActive(id: pending.id)
            }
            Button("Switch & Reset Service History", role: .destructive) {
                vehicleStore.setActive(id: pending.id)
                maintenanceStore.resetServiceHistory()
            }
            Button("Cancel", role: .cancel) { pendingSwitch = nil }
        } message: { pending in
            Text("Switching to \(pending.displayName). Your odometer and trip data will stay. Do you want to keep or reset maintenance service history?")
        }
    }

    // MARK: - Vehicle Row

    private func vehicleRow(_ profile: VehicleProfile) -> some View {
        let isActive = vehicleStore.activeProfileId == profile.id

        return HStack(spacing: 14) {
            // Active indicator
            ZStack {
                Circle()
                    .fill(isActive ? Color.green : Color.gray.opacity(0.15))
                    .frame(width: 36, height: 36)
                Image(systemName: fuelIcon(profile.fuelType))
                    .foregroundStyle(isActive ? .white : .secondary)
                    .font(.subheadline)
            }

            VStack(alignment: .leading, spacing: 3) {
                Text(profile.displayName)
                    .font(.headline)
                HStack(spacing: 8) {
                    Text(profile.fuelType.label)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    if let area = profile.homeArea, !area.isEmpty {
                        Text("· \(area)")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    if let mpg = profile.mpg {
                        Text("· \(Int(mpg)) MPG")
                            .font(.caption).foregroundStyle(.secondary)
                    }
                    if let mi = profile.miPerKwh {
                        Text("· \(String(format: "%.1f", mi)) mi/kWh")
                            .font(.caption).foregroundStyle(.secondary)
                    }
                    if let odo = profile.currentOdometerMiles {
                        Text("· \(Int(odo)) mi")
                            .font(.caption).foregroundStyle(.secondary)
                    }
                }
                Text("\(profile.preferredFuelProduct.label) • \(profile.stationPreference.label)\(profile.prioritizePromos ? " • Promos on" : "")")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                if isActive {
                    Text("Active").font(.caption.bold()).foregroundStyle(.green)
                }
            }

            Spacer()

            // Edit button
            Button {
                editingProfile = profile
            } label: {
                Image(systemName: "pencil.circle.fill")
                    .foregroundStyle(.secondary)
                    .font(.title3)
            }
            .buttonStyle(.plain)
        }
        .contentShape(Rectangle())
        .onTapGesture {
            guard !isActive else { return }
            handleSwitch(to: profile)
        }
        .padding(.vertical, 4)
    }

    // MARK: - Switch Logic

    private func handleSwitch(to profile: VehicleProfile) {
        guard let current = vehicleStore.profile else {
            vehicleStore.setActive(id: profile.id)
            return
        }
        if vehicleStore.isVehicleTypeChange(from: current, to: profile) {
            pendingSwitch = profile
            showMaintenanceWarning = true
        } else {
            vehicleStore.setActive(id: profile.id)
        }
    }

    private func fuelIcon(_ type: FuelType) -> String {
        switch type {
        case .electric: return "bolt.fill"
        case .hybrid:   return "leaf.fill"
        default:        return "fuelpump.fill"
        }
    }
}

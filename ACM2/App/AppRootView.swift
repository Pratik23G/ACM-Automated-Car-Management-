import SwiftUI
import Combine
import WidgetKit

struct AppRootView: View {

    private enum AppTab {
        case drive
        case fuelInsights
        case costTracker
        case maintenance
        case copilot
    }

    @StateObject private var tripManager      = TripManager()
    @StateObject private var vehicleStore     = VehicleProfileStore()
    @StateObject private var tripHistory      = TripHistoryStore()
    @StateObject private var maintenanceStore = MaintenanceStore()
    @StateObject private var maintenanceExpenseStore = MaintenanceExpenseStore()
    @StateObject private var routeStore       = RouteStore()
    @StateObject private var fuelLogStore     = FuelLogStore()
    @StateObject private var fuelSettingsStore = FuelInsightsSettingsStore()
    @StateObject private var driveDetector    = DriveDetector()
    @StateObject private var btTrigger        = BluetoothTripTrigger()
    @StateObject private var placesStore      = SavedPlacesStore()
    @StateObject private var fuelSnapshots    = FuelPriceSnapshotStore()

    // Pending auto-detected trip waiting for confirmation
    @State private var pendingAutoTrip: PendingAutoTrip? = SharedDefaults.pendingAutoTrip
    @State private var selectedTab: AppTab = .drive

    var body: some View {
        Group {
            if vehicleStore.hasProfile {
                TabView(selection: $selectedTab) {
                    TripHomeView(pendingAutoTrip: $pendingAutoTrip)
                        .tabItem {
                            Label("Drive", systemImage: "steeringwheel")
                        }
                        .tag(AppTab.drive)

                    NavigationStack {
                        FuelIntelView()
                    }
                    .tabItem {
                        Label("Fuel Insights", systemImage: "newspaper.fill")
                    }
                    .tag(AppTab.fuelInsights)

                    NavigationStack {
                        CostTrackerView()
                    }
                    .tabItem {
                        Label("Cost Tracker", systemImage: "chart.bar.xaxis")
                    }
                    .tag(AppTab.costTracker)

                    NavigationStack {
                        MaintenanceView()
                    }
                    .tabItem {
                        Label("Maintenance", systemImage: "wrench.and.screwdriver.fill")
                    }
                    .tag(AppTab.maintenance)

                    NavigationStack {
                        CopilotHomeView()
                    }
                    .tabItem {
                        Label("Copilot", systemImage: "sparkles")
                    }
                    .tag(AppTab.copilot)
                }
            } else {
                VehicleSetupView(existingProfile: nil)
            }
        }
        .environmentObject(tripManager)
        .environmentObject(vehicleStore)
        .environmentObject(tripHistory)
        .environmentObject(maintenanceStore)
        .environmentObject(maintenanceExpenseStore)
        .environmentObject(routeStore)
        .environmentObject(fuelLogStore)
        .environmentObject(fuelSettingsStore)
        .environmentObject(driveDetector)
        .environmentObject(btTrigger)
        .environmentObject(placesStore)
        .environmentObject(fuelSnapshots)
        .onAppear(perform: setup)
        .onChange(of: pendingAutoTrip?.id) { _, newValue in
            if newValue != nil {
                selectedTab = .drive
            }
        }
        // Widget deep-link: start trip
        .onReceive(NotificationCenter.default.publisher(for: .acmWidgetStartTrip)) { _ in
            guard !tripManager.isTripActive else { return }
            selectedTab = .drive
            tripManager.startTrip()
        }
        // Widget deep-link: stop trip
        .onReceive(NotificationCenter.default.publisher(for: .acmWidgetStopTrip)) { _ in
            guard tripManager.isTripActive,
                  let vehicle = vehicleStore.profile else { return }
            if let id = tripManager.activeTripId { routeStore.finaliseRoute(tripId: id) }
            tripManager.stopTrip(vehicle: vehicle)
        }
        // Notification action: confirm auto trip
        .onReceive(NotificationCenter.default.publisher(for: .acmConfirmAutoTrip)) { _ in
            confirmPendingTrip()
        }
        // Notification action: discard auto trip
        .onReceive(NotificationCenter.default.publisher(for: .acmDiscardAutoTrip)) { _ in
            discardPendingTrip()
        }
        // Poll SharedDefaults for new pending trips (e.g. detected while app was backgrounded)
        .onReceive(Timer.publish(every: 5, on: .main, in: .common).autoconnect()) { _ in
            if let t = SharedDefaults.pendingAutoTrip, pendingAutoTrip?.id != t.id {
                withAnimation { pendingAutoTrip = t }
            }
        }
    }

    // MARK: - Setup

    private func setup() {
        // Sync vehicle name to widget
        if let name = vehicleStore.profile?.displayName {
            SharedDefaults.vehicleDisplayName = name
        }

        // If widget started a trip while app was closed, resume it in TripManager
        if SharedDefaults.isTripActive && !tripManager.isTripActive {
            tripManager.resumeFromWidget(startedAt: SharedDefaults.tripStartedAt ?? Date())
        }

        // Check for a pending auto trip that arrived while app was closed
        if let pending = SharedDefaults.pendingAutoTrip, pendingAutoTrip?.id != pending.id {
            withAnimation { pendingAutoTrip = pending }
        }

        // Start motion monitoring if active vehicle has it enabled
        if vehicleStore.profile?.motionAutoDetectEnabled == true {
            driveDetector.startMonitoring()
            driveDetector.queryRecentActivity(hours: 2)
        }

        // Configure Bluetooth trigger with paired device
        if let uuid = vehicleStore.profile?.bluetoothDeviceUUID {
            btTrigger.configure(pairedDeviceUUID: uuid)
        }
    }

    // MARK: - Auto Trip Actions

    private func confirmPendingTrip() {
        guard let pending = pendingAutoTrip,
              let vehicle = vehicleStore.profile else { return }
        selectedTab = .drive
        tripManager.confirmAutoTrip(pending, vehicle: vehicle)
        withAnimation { pendingAutoTrip = nil }
        SharedDefaults.pendingAutoTrip = nil
    }

    private func discardPendingTrip() {
        SharedDefaults.pendingAutoTrip = nil
        withAnimation { pendingAutoTrip = nil }
    }
}

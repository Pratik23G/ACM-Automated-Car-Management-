import SwiftUI
import MapKit

struct TripMapView: View {

    @EnvironmentObject var tripManager:  TripManager
    @EnvironmentObject var routeStore:   RouteStore
    @EnvironmentObject var vehicleStore: VehicleProfileStore
    @EnvironmentObject var fuelLogStore: FuelLogStore

    @StateObject private var locationManager = LocationManager()

    // Map camera
    @State private var position: MapCameraPosition = .userLocation(
        followsHeading: true, fallback: .automatic)
    @State private var followsUser = true

    // Record sheet
    @State private var showNoteSheet  = false
    @State private var showFuelSheet  = false
    @State private var showPermAlert  = false

    // Simulation engine
    @State private var simTimer:  Timer?
    @State private var simIndex:  Int = 0
    // A small loop route around SF for testing
    private let simCoords: [SerializableCoordinate] = {
        // Generates a small grid walk near Union Square, SF
        let base = (lat: 37.7879, lng: -122.4074)
        var pts: [SerializableCoordinate] = []
        let step = 0.0004
        for i in 0..<20 { pts.append(.init(latitude: base.lat + Double(i) * step,
                                            longitude: base.lng)) }
        for i in 0..<20 { pts.append(.init(latitude: base.lat + 20 * step,
                                            longitude: base.lng + Double(i) * step)) }
        for i in (0..<20).reversed() { pts.append(.init(latitude: base.lat + Double(i) * step,
                                                          longitude: base.lng + 20 * step)) }
        for i in (0..<20).reversed() { pts.append(.init(latitude: base.lat,
                                                          longitude: base.lng + Double(i) * step)) }
        return pts
    }()

    // Computed helpers
    private var activeTripId: UUID? { tripManager.activeTripId }
    private var currentRoute: TripRoute? {
        activeTripId.flatMap { routeStore.route(for: $0) }
    }
    private var routeCoords: [CLLocationCoordinate2D] {
        currentRoute?.coordinates.map { $0.clCoordinate } ?? []
    }
    private var routeNotes: [RouteNote] { currentRoute?.notes ?? [] }

    // MARK: - Body

    var body: some View {
        ZStack(alignment: .bottom) {
            map
            controlBar
        }
        .navigationTitle("Live Map")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar { followButton }
        .sheet(isPresented: $showNoteSheet, onDismiss: resumeTracking) {
            // snapshot coordinate at the moment Record is tapped
            let coord = snapshotCoord()
            if let id = activeTripId, let coord {
                QuickRecordSheet(tripId: id, coordinate: coord) { note in
                    routeStore.addNote(note)
                }
            }
        }
        .sheet(isPresented: $showFuelSheet) {
            FuelLogSheet(
                coordinate: currentFuelCoordinate,
                defaultArea: vehicleStore.profile?.homeArea ?? "Current Area",
                preferredProduct: vehicleStore.profile?.preferredFuelProduct ?? .regular
            ) { log in
                fuelLogStore.add(log)
            }
        }
        .alert("Location Access Needed", isPresented: $showPermAlert) {
            Button("Open Settings") {
                if let url = URL(string: UIApplication.openSettingsURLString) {
                    UIApplication.shared.open(url)
                }
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("Enable Location in Settings so ACM can track your route.")
        }
        .onAppear(perform: setup)
        .onDisappear(perform: teardown)
        .onChange(of: tripManager.isTripActive) { _, active in
            if active { beginTracking() } else { stopAll() }
        }
    }

    // MARK: - Map

    private var map: some View {
        Map(position: $position) {
            UserAnnotation()

            if routeCoords.count > 1 {
                MapPolyline(coordinates: routeCoords)
                    .stroke(.blue, style: StrokeStyle(lineWidth: 5, lineCap: .round,
                                                       lineJoin: .round))
            }

            if let first = routeCoords.first {
                Annotation("Start", coordinate: first) {
                    Circle().fill(.green).frame(width: 12, height: 12)
                        .overlay(Circle().stroke(.white, lineWidth: 2))
                }
            }

            ForEach(routeNotes) { note in
                Annotation(note.title, coordinate: note.coordinate.clCoordinate) {
                    ZStack {
                        Circle().fill(note.type.color)
                            .frame(width: 32, height: 32).shadow(radius: 3)
                        Image(systemName: note.type.icon)
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundStyle(.white)
                    }
                }
            }
        }
        .mapStyle(.standard)
        .mapControls { MapCompass(); MapScaleView() }
        .ignoresSafeArea(edges: .top)
        .simultaneousGesture(DragGesture().onChanged { _ in followsUser = false })
    }

    // MARK: - Control Bar

    private var controlBar: some View {
        VStack(spacing: 0) {
            // Live stats strip
            if tripManager.isTripActive {
                HStack(spacing: 24) {
                    statsItem(icon: "timer", value: formatTime(tripManager.elapsedSeconds))
                    statsItem(icon: "road.lanes",
                              value: currentRoute.map {
                                $0.calculatedDistanceMiles > 0
                                  ? String(format: "%.1f mi", $0.calculatedDistanceMiles)
                                  : "-- mi"
                              } ?? "-- mi")
                    statsItem(icon: "mappin.circle.fill",
                              value: "\(routeNotes.count) note\(routeNotes.count == 1 ? "" : "s")")
                }
                .padding(.horizontal, 24).padding(.vertical, 10)
                .background(.ultraThinMaterial)
            }

            // Record button
            if tripManager.isTripActive {
                HStack(spacing: 12) {
                    Button(action: { showFuelSheet = true }) {
                        Label("Log Fuel", systemImage: "fuelpump.fill")
                            .font(.subheadline.bold())
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 12)
                            .background(Color.green)
                            .foregroundStyle(.white)
                            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                    }
                    .buttonStyle(.plain)

                    Button(action: tapRecord) {
                        HStack(spacing: 10) {
                            Image(systemName: "record.circle.fill").font(.title2)
                            Text("Record Moment").font(.headline)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                        .background(Color.red)
                        .foregroundStyle(.white)
                        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                    }
                    .buttonStyle(.plain)
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 12)
                .background(.ultraThinMaterial)
            } else {
                VStack(spacing: 10) {
                    Button(action: { showFuelSheet = true }) {
                        Label("Log Fuel Stop", systemImage: "fuelpump.circle.fill")
                            .font(.headline)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 14)
                            .background(Color.green)
                            .foregroundStyle(.white)
                            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                    }
                    .padding(.horizontal, 20)

                    VStack(spacing: 6) {
                        Image(systemName: "car.fill").font(.title2).foregroundStyle(.secondary)
                        Text("Start a trip from the home screen to begin recording.")
                            .font(.footnote).foregroundStyle(.secondary).multilineTextAlignment(.center)
                    }
                    .padding(.bottom, 20).frame(maxWidth: .infinity)
                }
                .background(.ultraThinMaterial)
            }
        }
    }

    // MARK: - Follow Button

    private var followButton: some ToolbarContent {
        ToolbarItem(placement: .topBarTrailing) {
            Button {
                followsUser = true
                position = .userLocation(followsHeading: true, fallback: .automatic)
            } label: {
                Image(systemName: followsUser ? "location.fill" : "location")
                    .foregroundStyle(followsUser ? .blue : .secondary)
            }
        }
    }

    // MARK: - Record Tap

    private func tapRecord() {
        // Pause the line while sheet is open
        locationManager.isPaused = true
        showNoteSheet = true
    }

    private var currentFuelCoordinate: SerializableCoordinate? {
        if let current = locationManager.currentLocation?.coordinate {
            return SerializableCoordinate(current)
        }
        if let last = routeCoords.last {
            return SerializableCoordinate(last)
        }
        return nil
    }

    private func resumeTracking() {
        locationManager.isPaused = false
    }

    // MARK: - Setup / Teardown

    private func setup() {
        routeStore.requestNotificationPermission()

        switch locationManager.authorizationStatus {
        case .notDetermined: locationManager.requestPermission()
        case .denied, .restricted: showPermAlert = true
        default: break
        }

        locationManager.onLocationUpdate = { [self] location in
            guard tripManager.isTripActive,
                  let tripId = tripManager.activeTripId else { return }
            let coord = SerializableCoordinate(location.coordinate)
            routeStore.appendCoordinate(coord, toTripId: tripId)
            routeStore.checkProximityReminders(location: location)
        }

        if tripManager.isTripActive { beginTracking() }
    }

    private func teardown() {
        locationManager.stopTracking()
        stopSimulation()
    }

    private func beginTracking() {
        if tripManager.simulationMode {
            startSimulation()
        } else {
            locationManager.startTracking()
        }
    }

    private func stopAll() {
        locationManager.stopTracking()
        stopSimulation()
    }

    // MARK: - Simulation Engine

    private func startSimulation() {
        guard let tripId = tripManager.activeTripId else { return }
        simIndex = 0
        simTimer?.invalidate()
        simTimer = Timer.scheduledTimer(withTimeInterval: 1.2, repeats: true) { _ in
            Task { @MainActor in
                guard self.tripManager.isTripActive,
                      !self.locationManager.isPaused else { return }
                let coord = self.simCoords[self.simIndex % self.simCoords.count]
                self.routeStore.appendCoordinate(coord, toTripId: tripId)
                // Move camera to simulated position
                self.locationManager.currentLocation = CLLocation(
                    latitude: coord.latitude, longitude: coord.longitude)
                self.simIndex += 1
                if self.followsUser {
                    self.position = .camera(MapCamera(
                        centerCoordinate: coord.clCoordinate,
                        distance: 800, heading: 0, pitch: 0))
                }
            }
        }
    }

    private func stopSimulation() {
        simTimer?.invalidate()
        simTimer = nil
    }

    // MARK: - Helpers

    private func snapshotCoord() -> SerializableCoordinate? {
        if tripManager.simulationMode {
            return simCoords[max(0, simIndex - 1) % simCoords.count]
        }
        return locationManager.currentLocation.map { SerializableCoordinate($0.coordinate) }
    }

    private func statsItem(icon: String, value: String) -> some View {
        HStack(spacing: 5) {
            Image(systemName: icon).font(.caption).foregroundStyle(.secondary)
            Text(value).font(.subheadline.bold())
        }
    }

    private func formatTime(_ s: Int) -> String {
        String(format: "%02d:%02d", s / 60, s % 60)
    }
}

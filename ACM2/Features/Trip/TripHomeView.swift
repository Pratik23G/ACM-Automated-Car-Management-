import SwiftUI

struct TripHomeView: View {
    @EnvironmentObject var tripManager:      TripManager
    @EnvironmentObject var vehicleStore:     VehicleProfileStore
    @EnvironmentObject var tripHistory:      TripHistoryStore
    @EnvironmentObject var maintenanceStore: MaintenanceStore
    @EnvironmentObject var routeStore:       RouteStore
    @EnvironmentObject var placesStore:      SavedPlacesStore

    @Binding var pendingAutoTrip: PendingAutoTrip?
    @State private var showTripComplete = false

    enum IssueType: String, CaseIterable, Identifiable {
        case noise, braking, steering, vibration, warningLight, leak, electrical, performance, other
        var id: String { rawValue }
        var label: String { rawValue.capitalized }
    }
    enum Severity: String, CaseIterable, Identifiable {
        case low, medium, high, stopDriving
        var id: String { rawValue }
        var label: String {
            switch self {
            case .low: return "Low"; case .medium: return "Medium"
            case .high: return "High"; case .stopDriving: return "Stop Driving"
            }
        }
    }

    @State private var issueType:      IssueType  = .noise
    @State private var severity:       Severity   = .medium
    @State private var issueText:      String     = ""
    @State private var carIssueLoading = false
    @State private var carIssueError:  String?
    @State private var carIssueResult: CarIssueTriage?

    private let copilotClient = CopilotClient()

    private var currentOdometer: Double {
        (vehicleStore.profile?.currentOdometerMiles ?? 0) + tripHistory.totalMilesEstimated
    }
    private var avgHardBrakes: Double {
        guard !tripHistory.trips.isEmpty else { return 0 }
        return Double(tripHistory.trips.map { $0.hardBrakes }.reduce(0, +)) / Double(tripHistory.trips.count)
    }
    private var avgSharpTurns: Double {
        guard !tripHistory.trips.isEmpty else { return 0 }
        return Double(tripHistory.trips.map { $0.sharpTurns }.reduce(0, +)) / Double(tripHistory.trips.count)
    }
    private var avgAggression: Double {
        guard !tripHistory.trips.isEmpty else { return 0 }
        return tripHistory.trips.map {
            Double($0.hardBrakes * 3 + $0.sharpTurns * 2 + $0.aggressiveAccels * 2)
        }.reduce(0, +) / Double(tripHistory.trips.count)
    }
    private var maintenanceAlertCount: Int {
        maintenanceStore.reminders.filter { r in
            let ei = r.effectiveInterval(avgHardBrakes: avgHardBrakes,
                                          avgSharpTurns: avgSharpTurns,
                                          avgAggression: avgAggression,
                                          tripCount: tripHistory.trips.count)
            return r.isOverdue(currentOdometer: currentOdometer, effectiveInterval: ei)
                || r.isDueSoon(currentOdometer: currentOdometer, effectiveInterval: ei)
        }.count
    }
    private var totalFuelCostThisMonth: Double {
        let start = Calendar.current.date(from: Calendar.current.dateComponents(
            [.year, .month], from: Date())) ?? Date()
        return tripHistory.trips
            .filter { $0.endedAt >= start }
            .compactMap { $0.estimatedFuelCost }
            .reduce(0, +)
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 14) {
                    // Auto-detected trip confirmation banner
                    if let pending = pendingAutoTrip {
                        AutoTripConfirmationBanner(
                            pending: pending,
                            onConfirm: {
                                guard let vehicle = vehicleStore.profile else { return }
                                tripManager.confirmAutoTrip(pending, vehicle: vehicle)
                                withAnimation { pendingAutoTrip = nil }
                                SharedDefaults.pendingAutoTrip = nil
                                showTripComplete = true
                            },
                            onDiscard: {
                                SharedDefaults.pendingAutoTrip = nil
                                withAnimation { pendingAutoTrip = nil }
                            }
                        )
                        .padding(.bottom, 2)
                    }
                    activeVehicleBanner
                    tripControlsCard
                    quickNavCard
                    fuelWorkspaceCard
                    carIssueBox
                }
                .padding()
            }
            .navigationTitle("ACM 2.0")
            .navigationDestination(isPresented: $showTripComplete) {
                TripCompleteView()
            }
            // Widget or auto-trip completions won't go through the Stop button,
            // so watch completedTrip directly — whenever it changes to a non-nil
            // value and we're not already showing the summary, navigate there.
            .onChange(of: tripManager.completedTrip?.id) { _, newId in
                if newId != nil && !showTripComplete {
                    showTripComplete = true
                }
            }
        }
    }

    // MARK: - Active Vehicle Banner

    private var activeVehicleBanner: some View {
        NavigationLink(destination: VehicleListView()) {
            HStack(spacing: 12) {
                ZStack {
                    RoundedRectangle(cornerRadius: 10).fill(Color.blue.opacity(0.12))
                        .frame(width: 40, height: 40)
                    Image(systemName: vehicleStore.profile?.fuelType == .electric
                          ? "bolt.fill" : "car.fill")
                        .foregroundStyle(.blue)
                }
                VStack(alignment: .leading, spacing: 2) {
                    Text(vehicleStore.profile?.displayName ?? "No Vehicle Selected")
                        .font(.subheadline.bold())
                    Text(vehicleStore.profiles.count > 1
                         ? "\(vehicleStore.profiles.count) vehicles · Tap to switch"
                         : "Tap to manage vehicle")
                        .font(.caption).foregroundStyle(.secondary)
                }
                Spacer()
                Image(systemName: "chevron.right").font(.caption).foregroundStyle(.secondary)
            }
            .padding(.horizontal, 14).padding(.vertical, 10)
            .background(.thinMaterial)
            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        }
        .buttonStyle(.plain)
    }

    // MARK: - Trip Controls

    private var tripControlsCard: some View {
        Card(title: "Trip Controls") {
            Button("Start Trip") { tripManager.startTrip() }
                .buttonStyle(.borderedProminent).frame(maxWidth: .infinity)
                .disabled(tripManager.isTripActive)

            Button("Stop Trip") {
                let vehicle = vehicleStore.profile ?? VehicleProfile(
                    make: "Unknown", model: "Vehicle", year: 2026, fuelType: .gasoline, mpg: 27.0
                )
                if let id = tripManager.activeTripId { routeStore.finaliseRoute(tripId: id) }
                tripManager.stopTrip(vehicle: vehicle)
                if tripManager.completedTrip != nil { showTripComplete = true }
            }
            .buttonStyle(.bordered).frame(maxWidth: .infinity)
            .disabled(!tripManager.isTripActive)

            if tripManager.isTripActive {
                HStack {
                    Image(systemName: "circle.fill").foregroundStyle(.green).font(.caption)
                    Text("In progress — \(formatTime(tripManager.elapsedSeconds))")
                        .font(.footnote).foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
    }

    // MARK: - Quick Nav

    private var quickNavCard: some View {
        Card(title: "My Drive") {
            NavigationLink(destination: TripMapView()) {
                navRow(icon: "map.fill", color: .blue, label: "Live Map",
                       badge: tripManager.isTripActive ? "LIVE" : nil, badgeColor: .red)
            }.buttonStyle(.plain)

            Divider()
            NavigationLink(destination: PlacesListView()) {
                navRow(icon: "mappin.and.ellipse", color: .blue,
                       label: "My Places",
                       detail: "Home, Work, School + briefings")
            }.buttonStyle(.plain)

            Divider()
            NavigationLink(destination: RouteHistoryView()) {
                navRow(icon: "point.topleft.down.to.point.bottomright.curvepath.fill",
                       color: .teal, label: "Route History",
                       detail: "\(routeStore.routes.filter { $0.endedAt != nil }.count) routes")
            }.buttonStyle(.plain)

            Divider()
            NavigationLink(destination: TripHistoryView()) {
                navRow(icon: "clock.arrow.circlepath", color: .indigo, label: "Trip History",
                       detail: "\(tripHistory.trips.count) saved")
            }.buttonStyle(.plain)

            Divider()
            NavigationLink(destination: MaintenanceView()) {
                navRow(icon: "wrench.and.screwdriver.fill", color: .orange, label: "Maintenance",
                       badge: maintenanceAlertCount > 0 ? "\(maintenanceAlertCount)" : nil,
                       badgeColor: .orange)
            }.buttonStyle(.plain)

            Divider()
            NavigationLink(destination: DriveDNAView()) {
                navRow(icon: "dna", color: Color(red: 0.5, green: 0.2, blue: 0.9),
                       label: "Drive DNA",
                       detail: tripHistory.trips.count >= 3 ? "Tap to view patterns" : "Need 3+ trips")
            }.buttonStyle(.plain)

            Divider()
            NavigationLink(destination: PreTripView()) {
                navRow(icon: "brain.head.profile", color: Color(red: 0.1, green: 0.6, blue: 0.5),
                       label: "Pre-Trip Intel",
                       detail: "AI co-pilot briefing")
            }.buttonStyle(.plain)
        }
    }

    private var fuelWorkspaceCard: some View {
        Card(title: "Workspace Tabs") {
            VStack(alignment: .leading, spacing: 8) {
                Text("Use the Fuel Insights tab for gas-price news, projected outlooks, alerts, and voice questions.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)

                Text("Use the Cost Tracker tab for daily, weekly, monthly, and yearly fill-up analysis.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)

                Text("Use the Maintenance tab for your existing reminder flow and behavior-adjusted service intervals.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)

                Text("Use the Copilot tab when you want the backend to merge fuel and maintenance context into one brief or answer.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)

                if totalFuelCostThisMonth > 0 {
                    Text(String(format: "Trip-estimated fuel spend this month: $%.0f", totalFuelCostThisMonth))
                        .font(.subheadline.bold())
                }

                Divider()

                NavigationLink(destination: FuelIntelligenceDemoView()) {
                    navRow(icon: "fuelpump.and.filter.fill",
                           color: Color(red: 0.0, green: 0.45, blue: 0.65),
                           label: "TinyFish Fuel Demo",
                           detail: "Web-extracted local price demo")
                }
                .buttonStyle(.plain)
            }
        }
    }

    private func navRow(icon: String, color: Color, label: String,
                        detail: String? = nil, badge: String? = nil,
                        badgeColor: Color = .gray) -> some View {
        HStack(spacing: 12) {
            ZStack {
                RoundedRectangle(cornerRadius: 8).fill(color.opacity(0.15))
                Image(systemName: icon).foregroundStyle(color).font(.subheadline)
            }
            .frame(width: 34, height: 34)
            Text(label).font(.subheadline)
            Spacer()
            if let badge {
                Text(badge).font(.caption.bold()).foregroundStyle(.white)
                    .padding(.horizontal, 7).padding(.vertical, 3)
                    .background(badgeColor).clipShape(Capsule())
            } else if let detail {
                Text(detail).font(.caption).foregroundStyle(.secondary)
            }
            Image(systemName: "chevron.right").font(.caption2).foregroundStyle(.secondary)
        }
        .padding(.vertical, 4)
    }

    // MARK: - Car Issue Box

    private var carIssueBox: some View {
        Card(title: "Car Issue Assistant") {
            Text("Describe a symptom and get possible causes + next steps.")
                .font(.footnote).foregroundStyle(.secondary)
            Picker("Issue Type", selection: $issueType) {
                ForEach(IssueType.allCases) { t in Text(t.label).tag(t) }
            }.pickerStyle(.menu)
            Picker("Severity", selection: $severity) {
                ForEach(Severity.allCases) { s in Text(s.label).tag(s) }
            }.pickerStyle(.menu)
            TextField("Describe the issue", text: $issueText, axis: .vertical)
                .textFieldStyle(.roundedBorder)
            if let carIssueError {
                Text("⚠️ \(carIssueError)").font(.footnote).foregroundStyle(.red)
            }
            Button { Task { await runCarIssueAI() } } label: {
                Text(carIssueLoading ? "Analyzing..." : "Analyze Issue")
                    .frame(maxWidth: .infinity).padding()
            }
            .buttonStyle(.borderedProminent)
            .disabled(carIssueLoading || issueText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            if let result = carIssueResult {
                Divider().padding(.vertical, 6)
                carIssueResultView(result)
            }
        }
    }

    @ViewBuilder
    private func carIssueResultView(_ result: CarIssueTriage) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(result.title).font(.headline)
            Text("Urgency: \(result.urgency)").font(.subheadline).foregroundStyle(.secondary)
            if !result.likelyCauses.isEmpty {
                Text("Likely Causes").font(.subheadline).fontWeight(.semibold)
                ForEach(result.likelyCauses, id: \.self) { Text("• \($0)").font(.footnote) }
            }
            if !result.checksYouCanDo.isEmpty {
                Text("Checks You Can Do").font(.subheadline).fontWeight(.semibold)
                ForEach(result.checksYouCanDo, id: \.self) { Text("• \($0)").font(.footnote) }
            }
            if !result.nextSteps.isEmpty {
                Text("Next Steps").font(.subheadline).fontWeight(.semibold)
                ForEach(result.nextSteps, id: \.self) { Text("• \($0)").font(.footnote) }
            }
            if !result.safetyNotes.isEmpty {
                Text("Safety Notes").font(.subheadline).fontWeight(.semibold)
                ForEach(result.safetyNotes, id: \.self) {
                    Text("• \($0)").font(.footnote).foregroundStyle(.secondary)
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func runCarIssueAI() async {
        carIssueLoading = true; carIssueError = nil; carIssueResult = nil
        let trimmed = issueText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            carIssueLoading = false
            return
        }
        do {
            let response = try await copilotClient.query(
                userId: vehicleStore.profile?.backendUserId ?? "demo-user",
                query: carIssuePrompt(symptom: trimmed)
            )
            carIssueResult = buildCarIssueResult(from: response, symptom: trimmed)
        } catch { carIssueError = error.localizedDescription }
        carIssueLoading = false
    }

    private func carIssuePrompt(symptom: String) -> String {
        var lines: [String] = []
        lines.append("Help with a car issue.")
        if let vehicle = vehicleStore.profile {
            lines.append("Vehicle: \(vehicle.displayName)")
        }
        lines.append("Issue type: \(issueType.label)")
        lines.append("Urgency selected by user: \(severity.label)")
        lines.append("Symptom: \(symptom)")
        lines.append("Respond with likely causes, a couple safe checks, next steps, and a safety caution.")
        return lines.joined(separator: "\n")
    }

    private func buildCarIssueResult(from response: CopilotQueryResponse, symptom: String) -> CarIssueTriage {
        let followUpSteps = response.actions.map(\.title)
        let followUpDetails = response.actions.map(\.description)
        let cardBodies = response.cards.map(\.body)

        return CarIssueTriage(
            title: response.cards.first?.title ?? "\(issueType.label) Guidance",
            urgency: severity.label,
            likelyCauses: [response.answer],
            checksYouCanDo: cardBodies.isEmpty ? [
                "Check for warning lights, unusual smells, or fresh leaks connected to “\(symptom)”.",
                "Note whether the issue appears only during braking, turning, acceleration, or idling."
            ] : Array(cardBodies.prefix(2)),
            nextSteps: followUpSteps.isEmpty ? [
                "Capture when the symptom happens so the maintenance agent can compare it against recent trips.",
                "Book an inspection if the issue is getting louder, more frequent, or affecting control."
            ] : followUpSteps + followUpDetails,
            safetyNotes: safetyNotes(for: symptom)
        )
    }

    private func safetyNotes(for symptom: String) -> [String] {
        if severity == .stopDriving {
            return ["The selected severity is Stop Driving, so treat this as a do-not-continue issue until the car is checked."]
        }
        if severity == .high {
            return ["If “\(symptom)” affects steering, braking, overheating, or warning lights, stop driving and get the vehicle inspected."]
        }
        return ["If the symptom escalates or starts affecting control, stop driving and inspect it before the next trip."]
    }

    private func formatTime(_ s: Int) -> String { String(format: "%02d:%02d", s/60, s%60) }
}

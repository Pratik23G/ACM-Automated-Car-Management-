import SwiftUI

struct TripCompleteView: View {
    @Environment(\.dismiss) private var dismiss

    @EnvironmentObject var tripManager:  TripManager
    @EnvironmentObject var vehicleStore: VehicleProfileStore
    @EnvironmentObject var tripHistory:  TripHistoryStore
    @EnvironmentObject var routeStore:   RouteStore
    @EnvironmentObject var placesStore:  SavedPlacesStore

    @State private var isLoadingAI   = false
    @State private var aiError:      String?
    @State private var isSaved:      Bool = false
    @State private var showPlaceSheet = false

    private let copilotClient = CopilotClient()

    private var completedRoute: TripRoute? {
        guard let id = tripManager.completedTrip?.id else { return nil }
        return routeStore.route(for: id)
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 14) {
                    if let trip = tripManager.completedTrip {
                        if let route = completedRoute, !route.notes.isEmpty || route.coordinates.count > 1 {
                            routeRecapCard(route)
                        }
                        tripSummaryCard(trip)
                        drivingEventsCard(trip)
                        fuelCard(trip)
                        roadQualityCard(trip)
                        overallTipCard(trip)
                        aiControlsCard(trip)
                    }
                }
                .padding()
            }
            .navigationTitle("Trip Complete")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { tripManager.dismissTripSummary(); dismiss() }
                }
            }
            .onAppear {
                if let t = tripManager.completedTrip { isSaved = tripHistory.isSaved(t.id) }
            }
            .sheet(isPresented: $showPlaceSheet) {
                if let trip = tripManager.completedTrip {
                    SaveTripToPlaceSheet(tripId: trip.id, isPresented: $showPlaceSheet)
                }
            }
        }
    }

    // MARK: - Route Recap Card

    private func routeRecapCard(_ route: TripRoute) -> some View {
        Card(title: "Route Recap") {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text("GPS Points").font(.caption).foregroundStyle(.secondary)
                    Text("\(route.coordinates.count)").font(.headline)
                }
                Spacer()
                VStack(alignment: .center, spacing: 2) {
                    Text("Distance").font(.caption).foregroundStyle(.secondary)
                    Text(route.calculatedDistanceMiles > 0
                         ? String(format: "%.1f mi", route.calculatedDistanceMiles)
                         : "--")
                        .font(.headline)
                }
                Spacer()
                VStack(alignment: .trailing, spacing: 2) {
                    Text("Notes").font(.caption).foregroundStyle(.secondary)
                    Text("\(route.notes.count)").font(.headline)
                }
            }
            .padding(.vertical, 4)

            if !route.notes.isEmpty {
                Divider()
                VStack(alignment: .leading, spacing: 6) {
                    ForEach(route.notes.prefix(4)) { note in
                        HStack(spacing: 8) {
                            Image(systemName: note.type.icon)
                                .foregroundStyle(note.type.color)
                                .frame(width: 18)
                            Text(note.title)
                                .font(.footnote)
                            if note.isReminder {
                                Image(systemName: "bell.fill")
                                    .font(.caption2)
                                    .foregroundStyle(.purple)
                            }
                        }
                    }
                    if route.notes.count > 4 {
                        Text("+ \(route.notes.count - 4) more notes…")
                            .font(.caption).foregroundStyle(.secondary)
                    }
                }
            }

            NavigationLink("View Full Route on Map") {
                TripRouteDetailView(route: route)
            }
            .font(.footnote)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 8)
            .buttonStyle(.bordered)
        }
    }

    // MARK: - Trip Stats Cards

    private func tripSummaryCard(_ trip: TripResult) -> some View {
        Card(title: "Trip Summary") {
            Row(label: "Duration", value: formatTime(trip.durationSeconds))
            Row(label: "Distance",  value: trip.distanceMiles.map { String(format: "%.2f mi", $0) } ?? "--")
            Row(label: "Avg Speed", value: trip.avgSpeedMph.map  { String(format: "%.1f mph", $0) } ?? "--")
            Row(label: "Max Speed", value: trip.maxSpeedMph.map  { String(format: "%.1f mph", $0) } ?? "--")
            Divider().padding(.vertical, 6)
            Text(trip.aiTripSummary ?? "AI trip summary not generated yet.")
                .font(.footnote).foregroundStyle(.secondary)
        }
    }

    private func drivingEventsCard(_ trip: TripResult) -> some View {
        Card(title: "Driving Events") {
            Row(label: "Hard Brakes",       value: "\(trip.hardBrakes)")
            Row(label: "Sharp Turns",       value: "\(trip.sharpTurns)")
            Row(label: "Aggressive Accels", value: "\(trip.aggressiveAccels)")
            Divider().padding(.vertical, 6)
            Text(trip.aiDrivingBehavior ?? "AI driving behavior insight not generated yet.")
                .font(.footnote).foregroundStyle(.secondary)
        }
    }

    private func fuelCard(_ trip: TripResult) -> some View {
        Card(title: "Fuel & Cost") {
            Row(label: "MPG",           value: String(format: "%.1f", trip.mpg))
            Row(label: "Gallons Spent", value: trip.estimatedGallons.map { String(format: "%.2f", $0) } ?? "--")
            Row(label: "Fuel Cost",     value: trip.estimatedFuelCost.map { String(format: "$%.2f", $0) } ?? "--")
            Divider().padding(.vertical, 6)
            Text(trip.aiFuelInsight ?? "AI fuel insight not generated yet.")
                .font(.footnote).foregroundStyle(.secondary)
        }
    }

    private func roadQualityCard(_ trip: TripResult) -> some View {
        Card(title: "Road Quality") {
            Row(label: "Bumps Detected", value: "\(trip.bumpsDetected)")
            Divider().padding(.vertical, 6)
            Text(trip.aiRoadImpact ?? "AI road impact not generated yet.")
                .font(.footnote).foregroundStyle(.secondary)
        }
    }

    private func overallTipCard(_ trip: TripResult) -> some View {
        Card(title: "Overall Tip") {
            Text(trip.aiOverallTip ?? "Generate AI Summary to get a personalized tip.")
                .font(.footnote).foregroundStyle(.secondary)
        }
    }

    // MARK: - AI Controls

    private func aiControlsCard(_ trip: TripResult) -> some View {
        Card(title: "AI Summary") {
            if let aiError {
                Text("⚠️ \(aiError)").font(.footnote).foregroundStyle(.red)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            Button { Task { await generateAI() } } label: {
                Text(isLoadingAI ? "Generating..." : "Generate AI Summary")
                    .frame(maxWidth: .infinity).padding()
            }
            .buttonStyle(.borderedProminent).disabled(isLoadingAI)

            Button { saveTrip() } label: {
                Text(isSaved ? "Saved ✓" : "Save Trip").frame(maxWidth: .infinity).padding()
            }
            .buttonStyle(.bordered).disabled(isSaved)

            if isSaved {
                Button(role: .destructive) { deleteSavedTrip() } label: {
                    Text("Delete Saved Trip").frame(maxWidth: .infinity).padding()
                }
                .buttonStyle(.bordered)
            }
        }
    }

    // MARK: - Actions

    private func generateAI() async {
        guard var trip = tripManager.completedTrip else { return }
        isLoadingAI = true; aiError = nil
        do {
            let response = try await copilotClient.query(
                userId: vehicleStore.profile?.backendUserId ?? "demo-user",
                query: trip.copilotSummaryPrompt(vehicle: vehicleStore.profile)
            )
            applyTripSummary(response: response, to: &trip)
            tripManager.completedTrip = trip
            if tripHistory.isSaved(trip.id) { tripHistory.add(trip); isSaved = true }
        } catch {
            applyOfflineTripSummary(to: &trip)
            tripManager.completedTrip = trip
            aiError = error.localizedDescription
        }
        isLoadingAI = false
    }

    private func applyTripSummary(response: CopilotQueryResponse, to trip: inout TripResult) {
        trip.aiTripSummary = response.answer
        trip.aiDrivingBehavior = drivingBehaviorText(for: trip)
        trip.aiFuelInsight = fuelInsightText(for: trip)
        trip.aiRoadImpact = roadImpactText(for: trip)
        trip.aiBrakeWear = brakeWearText(for: trip)
        trip.aiOverallTip = response.cards.first?.body ?? overallTipText(for: trip)
    }

    private func applyOfflineTripSummary(to trip: inout TripResult) {
        trip.aiTripSummary = offlineSummaryText(for: trip)
        trip.aiDrivingBehavior = drivingBehaviorText(for: trip)
        trip.aiFuelInsight = fuelInsightText(for: trip)
        trip.aiRoadImpact = roadImpactText(for: trip)
        trip.aiBrakeWear = brakeWearText(for: trip)
        trip.aiOverallTip = overallTipText(for: trip)
    }

    private func offlineSummaryText(for trip: TripResult) -> String {
        let distanceText = trip.distanceMiles.map { String(format: "%.1f mi", $0) } ?? "an unmeasured route"
        return "This \(distanceText) trip is using the backend-ready summary scaffold. Once the copilot backend is fully integrated, this overview will come back as a structured response instead of an on-device fallback."
    }

    private func drivingBehaviorText(for trip: TripResult) -> String {
        if trip.hardBrakes >= max(trip.sharpTurns, trip.aggressiveAccels) && trip.hardBrakes > 0 {
            return "Hard braking stood out the most on this trip, which usually means momentum is being lost later than it needs to be."
        }
        if trip.aggressiveAccels > 0 {
            return "Acceleration pressure was the strongest driving signal on this trip, so smoother throttle use would likely calm both fuel burn and engine load."
        }
        if trip.sharpTurns > 0 {
            return "Turning loads were more noticeable than braking or acceleration spikes, which points to more route or cornering stress than straight-line driving."
        }
        return "This trip looked fairly calm from a behavior standpoint, with no major aggressive driving signal dominating the run."
    }

    private func fuelInsightText(for trip: TripResult) -> String {
        if let estimatedFuelCost = trip.estimatedFuelCost,
           let estimatedGallons = trip.estimatedGallons {
            return String(format: "Estimated spend was $%.2f across %.2f gallons. Backend fuel context can now merge this with local price intel and station history.", estimatedFuelCost, estimatedGallons)
        }
        return String(format: "Estimated MPG landed at %.1f. Once the fuel agent backend is live, this view can explain that efficiency against live gas prices and your fill-up history.", trip.mpg)
    }

    private func roadImpactText(for trip: TripResult) -> String {
        if trip.bumpsDetected > 0 {
            return "The app detected \(trip.bumpsDetected) bumps, which suggests this route may contribute more suspension and tire wear than a smoother commute."
        }
        return "No meaningful bump activity stood out on this trip, so the route itself did not look unusually rough."
    }

    private func brakeWearText(for trip: TripResult) -> String {
        if trip.hardBrakes == 0 {
            return "Brake wear pressure looked relatively normal on this trip because hard-stop events stayed low."
        }
        return "Brake wear risk is elevated by \(trip.hardBrakes) hard braking event\(trip.hardBrakes == 1 ? "" : "s"), which is exactly the kind of pattern the maintenance agent will use for adjusted service estimates."
    }

    private func overallTipText(for trip: TripResult) -> String {
        if trip.aggressiveAccels >= trip.hardBrakes && trip.aggressiveAccels >= trip.sharpTurns && trip.aggressiveAccels > 0 {
            return "Use gentler roll-ons from stops first. That is the clearest way to improve both fuel efficiency and maintenance load from this trip."
        }
        if trip.hardBrakes > 0 {
            return "Leave a little more following distance so you can coast into slowdowns instead of braking late and re-accelerating."
        }
        if trip.bumpsDetected > 0 {
            return "If this route is common, flag rough sections in the map flow so future maintenance and route summaries can account for them."
        }
        return "Keep logging trips and fill-ups so the backend has enough context to turn these summaries from good heuristics into personalized agent output."
    }

    private func saveTrip() {
        guard let trip = tripManager.completedTrip else { return }
        tripHistory.add(trip)
        isSaved = true
        // Show place assignment sheet if this trip isn't already assigned
        if placesStore.place(forTrip: trip.id) == nil {
            showPlaceSheet = true
        }
    }

    private func deleteSavedTrip() {
        guard let trip = tripManager.completedTrip else { return }
        tripHistory.delete(id: trip.id); isSaved = false
    }

    private func formatTime(_ s: Int) -> String { String(format: "%02d:%02d", s/60, s%60) }
}

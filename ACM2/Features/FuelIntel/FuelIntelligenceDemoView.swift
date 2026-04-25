import SwiftUI

struct FuelIntelligenceDemoView: View {
    @EnvironmentObject var vehicleStore: VehicleProfileStore
    @EnvironmentObject var tripHistory: TripHistoryStore
    @EnvironmentObject var routeStore: RouteStore
    @EnvironmentObject var placesStore: SavedPlacesStore
    @EnvironmentObject var fuelSnapshots: FuelPriceSnapshotStore

    @State private var isLoading = false
    @State private var errorMessage: String?
    @State private var report: FuelIntelligenceReport?
    @State private var seedMessage: String?

    private var apiKeyStatus: String {
        let value = Bundle.main.object(forInfoDictionaryKey: "TINYFISH_API_KEY") as? String ?? ""
        let cleaned = value.trimmingCharacters(in: .whitespacesAndNewlines)
        return (cleaned.isEmpty || cleaned == "ADD_YOUR_KEY_LOCALLY") ? "Missing" : "Configured"
    }

    private var latestStoredSnapshot: FuelPriceSnapshot? {
        fuelSnapshots.snapshots.first
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                statusCard
                contextCard
                actionCard

                if let errorMessage {
                    Card(title: "TinyFish Error") {
                        Text(errorMessage)
                            .font(.footnote)
                            .foregroundStyle(.red)
                    }
                }

                if let seedMessage {
                    Card(title: "Demo Data") {
                        Text(seedMessage)
                            .font(.footnote)
                            .foregroundStyle(.green)
                    }
                }

                if let report {
                    summaryCard(report)
                    projectionCard(report)
                    stationsCard(report)
                    sourcesCard(report)
                    voiceCard(report)
                }

                historyCard
            }
            .padding()
        }
        .navigationTitle("Fuel Intel")
        .navigationBarTitleDisplayMode(.large)
    }

    private var statusCard: some View {
        Card(title: "TinyFish Demo Status") {
            Row(label: "API Key", value: apiKeyStatus)
            Row(label: "Saved Trips", value: "\(tripHistory.trips.count)")
            Row(label: "Recorded Routes", value: "\(routeStore.routes.filter { $0.endedAt != nil }.count)")
            Row(label: "Snapshots", value: "\(fuelSnapshots.snapshots.count)")

            Text("This first demo uses TinyFish Search to find local fuel-price pages, then TinyFish Agent to extract current station prices into structured data.")
                .font(.caption)
                .foregroundStyle(.secondary)
                .padding(.top, 4)
        }
    }

    private var contextCard: some View {
        Card(title: "What We Send") {
            if let vehicle = vehicleStore.profile {
                Row(label: "Vehicle", value: vehicle.displayName)
                if let mpg = vehicle.mpg, vehicle.fuelType != .electric {
                    Row(label: "Efficiency", value: String(format: "%.1f MPG", mpg))
                } else if let miPerKwh = vehicle.miPerKwh {
                    Row(label: "Efficiency", value: String(format: "%.1f mi/kWh", miPerKwh))
                }
            } else {
                Text("No vehicle selected.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }

            let routeHints = routeHints
            if routeHints.isEmpty {
                Text("No common route hints yet. Record a trip and save a place for better locality matching.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            } else {
                ForEach(routeHints, id: \.self) { hint in
                    Text("• \(hint)")
                        .font(.footnote)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
            }
        }
    }

    private var actionCard: some View {
        Card(title: "Run Demo") {
            Text("The demo infers your common drive area from recorded routes, fetches current nearby fuel prices, stores today’s snapshot, and calculates cost/savings projections.")
                .font(.footnote)
                .foregroundStyle(.secondary)

            Button {
                Task { await runDemo() }
            } label: {
                HStack {
                    if isLoading {
                        ProgressView()
                            .tint(.white)
                    }
                    Text(isLoading ? "Running TinyFish..." : "Fetch Local Fuel Intelligence")
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 10)
            }
            .buttonStyle(.borderedProminent)
            .disabled(isLoading)

            Button {
                Task { await seedDemoData() }
            } label: {
                Text("Load Rich Bay Area Demo History")
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 8)
            }
            .buttonStyle(.bordered)
            .disabled(isLoading)
        }
    }

    private func summaryCard(_ report: FuelIntelligenceReport) -> some View {
        Card(title: "Summary") {
            Text(report.priceTrendSummary)
                .font(.subheadline)
            Divider()
            Text(report.recommendation)
                .font(.subheadline)
            Divider()
            Text(report.savingsEstimate)
                .font(.subheadline)

            Divider()

            Row(label: "Common Area", value: report.areaLabel)
            Row(label: "Local Average", value: String(format: "$%.2f/gal", report.localAveragePrice))
            Row(label: "Cheapest Station", value: report.cheapestStation.name)
            Row(label: "Cheapest Price", value: report.cheapestStation.priceDisplay)
            if let distance = report.cheapestStation.distanceMiles {
                Row(label: "Approx Distance", value: String(format: "%.1f mi", distance))
            }
        }
    }

    private func projectionCard(_ report: FuelIntelligenceReport) -> some View {
        Card(title: "Commute Cost") {
            Row(label: "Recent Weekly Mileage", value: String(format: "%.0f mi", report.recentWeeklyMileage))

            if let average = report.averageProjection {
                Divider()
                Text("At today’s sampled local average:")
                    .font(.footnote.bold())
                    .foregroundStyle(.secondary)
                Row(label: "Week", value: currency(average.weekly))
                Row(label: "Month", value: currency(average.monthly))
                Row(label: "Year", value: currency(average.yearly))
            }

            if let cheapest = report.cheapestProjection {
                Divider()
                Text("If you switch to the cheapest station:")
                    .font(.footnote.bold())
                    .foregroundStyle(.secondary)
                Row(label: "Week", value: currency(cheapest.weekly))
                Row(label: "Month", value: currency(cheapest.monthly))
                Row(label: "Year", value: currency(cheapest.yearly))
            }
        }
    }

    private func stationsCard(_ report: FuelIntelligenceReport) -> some View {
        Card(title: "Nearby Cheapest Stations") {
            ForEach(report.snapshot.stations.prefix(5)) { station in
                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        Text(station.name)
                            .font(.subheadline.bold())
                        Spacer()
                        Text(station.priceDisplay)
                            .font(.subheadline.bold())
                            .foregroundStyle(.green)
                    }

                    if !station.address.isEmpty {
                        Text(station.address)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }

                    HStack {
                        if let distance = station.distanceMiles {
                            Text(String(format: "%.1f mi away", distance))
                        } else {
                            Text("Distance not shown")
                        }
                        if !station.sourceNote.isEmpty {
                            Text("• \(station.sourceNote)")
                        }
                    }
                    .font(.caption)
                    .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                if station.id != report.snapshot.stations.prefix(5).last?.id {
                    Divider()
                }
            }
        }
    }

    private func sourcesCard(_ report: FuelIntelligenceReport) -> some View {
        Card(title: "Sources") {
            Link(report.sourceURL, destination: URL(string: report.sourceURL)!)
                .font(.footnote)

            if !report.sources.isEmpty {
                Divider()
                ForEach(report.sources) { source in
                    VStack(alignment: .leading, spacing: 4) {
                        Text(source.title)
                            .font(.footnote.bold())
                        Text(source.siteName)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        Text(source.snippet)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    if source.id != report.sources.last?.id {
                        Divider()
                    }
                }
            }
        }
    }

    private func voiceCard(_ report: FuelIntelligenceReport) -> some View {
        Card(title: "Vapi-Ready Brief") {
            Text(report.spokenBrief)
                .font(.subheadline)
                .frame(maxWidth: .infinity, alignment: .leading)

            Text("You can hand this directly to a Vapi assistant as the spoken summary for the fuel agent.")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }

    private var historyCard: some View {
        Card(title: "Historical Daily Snapshots") {
            if fuelSnapshots.snapshots.isEmpty {
                Text("No saved snapshots yet. Run the demo once to start building local price history.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            } else {
                ForEach(fuelSnapshots.snapshots.prefix(5)) { snapshot in
                    VStack(alignment: .leading, spacing: 4) {
                        Text(snapshot.areaLabel)
                            .font(.subheadline.bold())
                        Text("\(snapshotDate(snapshot.capturedAt)) • Avg \(currency(snapshot.localAveragePrice))/gal • \(snapshot.stations.count) stations")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    if snapshot.id != fuelSnapshots.snapshots.prefix(5).last?.id {
                        Divider()
                    }
                }
            }

            if let latestStoredSnapshot {
                Divider()
                Text("Latest saved query: \(latestStoredSnapshot.query)")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }

    private var routeHints: [String] {
        let hints = placesStore.places
            .compactMap { place -> (String, Int)? in
                guard let pattern = place.pattern(from: tripHistory.trips), pattern.tripCount > 0 else { return nil }
                return ("\(place.displayName) (\(pattern.tripCount) trips)", pattern.tripCount)
            }
            .sorted { $0.1 > $1.1 }
            .prefix(3)
            .map(\.0)

        if !hints.isEmpty { return hints }

        return tripHistory.trips.prefix(3).compactMap { trip in
            guard let miles = trip.distanceMiles else { return nil }
            return String(format: "%.0f mile recent trip", miles)
        }
    }

    @MainActor
    private func runDemo() async {
        isLoading = true
        errorMessage = nil
        seedMessage = nil

        let apiKey = Bundle.main.object(forInfoDictionaryKey: "TINYFISH_API_KEY") as? String ?? ""
        let service = TinyFishFuelService(apiKey: apiKey)

        do {
            let report = try await service.buildReport(
                vehicle: vehicleStore.profile,
                trips: tripHistory.trips,
                routes: routeStore.routes,
                places: placesStore.places,
                priorSnapshots: fuelSnapshots.snapshots
            )
            fuelSnapshots.add(report.snapshot)
            self.report = report
        } catch {
            errorMessage = error.localizedDescription
        }

        isLoading = false
    }

    @MainActor
    private func seedDemoData() async {
        errorMessage = nil
        report = nil
        seedMessage = nil
        isLoading = true

        do {
            let result = try await DemoTripSeeder.seedRichBayAreaHistory(
                vehicleStore: vehicleStore,
                tripHistory: tripHistory,
                routeStore: routeStore,
                placesStore: placesStore
            )

            seedMessage = "Loaded \(result.tripCount) simulated Bay Area trips, \(result.placeCount) saved places, and demo vehicle \(result.vehicleName) with real Apple Maps route geometry plus seeded food, gas, reminder, and hazard notes."
        } catch {
            errorMessage = error.localizedDescription
        }

        isLoading = false
    }

    private func currency(_ value: Double) -> String {
        String(format: "$%.2f", value)
    }

    private func snapshotDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }
}

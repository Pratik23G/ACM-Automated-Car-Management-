import SwiftUI

struct FuelInsightsView: View {

    @EnvironmentObject var tripHistory: TripHistoryStore
    @EnvironmentObject var vehicleStore: VehicleProfileStore
    @EnvironmentObject var fuelLogStore: FuelLogStore
    @EnvironmentObject var fuelSettingsStore: FuelInsightsSettingsStore

    @State private var questionText = ""
    @State private var isAskingFuelCoach = false
    @State private var isRefreshingSummary = false
    @State private var fuelCoachError: String?
    @State private var summaryError: String?
    @State private var fuelCoachBrief: FuelCoachBrief?
    @State private var remoteSummary: FuelSummary?
    @State private var showVoiceAgentSheet = false

    private let service = FuelAgentService()
    private let fuelClient = FuelAgentClient()
    private let copilotClient = CopilotClient()

    private var userId: String {
        vehicleStore.profile?.backendUserId ?? "demo-user"
    }

    private var refreshToken: String {
        let profileToken = vehicleStore.profile?.id.uuidString ?? "none"
        return [
            profileToken,
            String(tripHistory.trips.count),
            String(fuelLogStore.logs.count),
            vehicleStore.profile?.preferredFuelProduct.rawValue ?? "none"
        ].joined(separator: "|")
    }

    private var dashboard: FuelDashboard {
        if let remoteSummary {
            return dashboard(from: remoteSummary)
        }

        return service.buildDashboard(
            profile: vehicleStore.profile,
            trips: tripHistory.trips,
            fuelLogs: fuelLogStore.logs
        )
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                projectionCard
                marketNewsCard
                coordinationCard
                stationSignalsCard
                notificationCard
                fuelCoachCard
            }
            .padding()
        }
        .navigationTitle("Fuel Insights")
        .navigationBarTitleDisplayMode(.large)
        .sheet(isPresented: $showVoiceAgentSheet) {
            FuelVoiceAgentSheet(prompts: dashboard.suggestedQuestions) { prompt in
                questionText = prompt
            }
        }
        .task(id: refreshToken) {
            await loadFuelSummary()
        }
        .refreshable {
            await loadFuelSummary()
        }
        .onAppear {
            fuelSettingsStore.refreshAuthorizationStatus()
        }
    }

    private var projectionCard: some View {
        Card(title: "Projected Outlook") {
            VStack(alignment: .leading, spacing: 12) {
                Text(dashboard.projectionSummary)
                    .font(.title3.bold())

                Text(dashboard.efficiencyHeadline)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)

                Text(dashboard.profileSummary)
                    .font(.caption)
                    .foregroundStyle(.secondary)

                if isRefreshingSummary {
                    Text("Refreshing Tinyfish-ready backend fuel summary...")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }

                if let summaryError {
                    Text(summaryError)
                        .font(.footnote)
                        .foregroundStyle(.orange)
                }

                HStack(spacing: 12) {
                    statPill(title: "Daily Avg", value: currency(dashboard.spendSnapshot.dailyAverage))
                    statPill(title: "This Week", value: currency(dashboard.spendSnapshot.weeklyTotal))
                    statPill(title: "This Month", value: currency(dashboard.spendSnapshot.monthlyTotal))
                }
            }
        }
    }

    private var marketNewsCard: some View {
        Card(title: "Gas News + Price Signals") {
            VStack(alignment: .leading, spacing: 12) {
                ForEach(dashboard.marketUpdates) { update in
                    HStack(alignment: .top, spacing: 10) {
                        trendBadge(update.direction)
                        VStack(alignment: .leading, spacing: 4) {
                            Text(update.headline)
                                .font(.subheadline.bold())
                            Text(update.summary)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                }
            }
        }
    }

    private var coordinationCard: some View {
        Card(title: "Agent Coordination") {
            VStack(alignment: .leading, spacing: 12) {
                Text("This is the structure for how your news, fuel, and driving agents can collaborate before answering questions.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)

                ForEach(dashboard.coordinationNotes) { note in
                    HStack(alignment: .top, spacing: 10) {
                        sourceIcon(note.source)
                        VStack(alignment: .leading, spacing: 4) {
                            Text(note.title)
                                .font(.subheadline.bold())
                            Text(note.summary)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                }
            }
        }
    }

    private var stationSignalsCard: some View {
        Card(title: "Station Quality + Promo Signals") {
            VStack(alignment: .leading, spacing: 12) {
                ForEach(dashboard.stationInsights) { insight in
                    HStack(alignment: .top, spacing: 12) {
                        stationBadge(insight.highlight)
                        VStack(alignment: .leading, spacing: 4) {
                            HStack {
                                Text(insight.stationName)
                                    .font(.subheadline.bold())
                                Spacer()
                                Text(insight.priceText)
                                    .font(.subheadline.bold())
                                    .foregroundStyle(.green)
                            }
                            Text(insight.areaLabel)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                            Text(insight.detail)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                }
            }
        }
    }

    private var notificationCard: some View {
        Card(title: "Insight Alerts") {
            VStack(alignment: .leading, spacing: 10) {
                Text("Turn on alerts for fuel news that could affect gas prices, promo timing, and weekly digests.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)

                Toggle(
                    "Fuel insight alerts",
                    isOn: Binding(
                        get: { fuelSettingsStore.insightAlertsEnabled },
                        set: { fuelSettingsStore.updateInsightAlerts(enabled: $0) }
                    )
                )

                Toggle("Price-moving news", isOn: $fuelSettingsStore.priceShockAlertsEnabled)
                    .disabled(!fuelSettingsStore.insightAlertsEnabled)
                Toggle("Promo opportunities", isOn: $fuelSettingsStore.promoAlertsEnabled)
                    .disabled(!fuelSettingsStore.insightAlertsEnabled)
                Toggle("Weekly digest", isOn: $fuelSettingsStore.weeklyDigestEnabled)
                    .disabled(!fuelSettingsStore.insightAlertsEnabled)

                HStack {
                    Text("Status")
                        .foregroundStyle(.secondary)
                    Spacer()
                    Text(fuelSettingsStore.authorizationStatusText)
                        .fontWeight(.semibold)
                }
                .font(.caption)

                if let actions = remoteSummary?.actions, !actions.isEmpty {
                    Divider()
                    Text("Backend recommendations")
                        .font(.subheadline.bold())

                    ForEach(actions) { action in
                        HStack(alignment: .top, spacing: 10) {
                            Circle()
                                .fill(priorityColor(action.priority))
                                .frame(width: 10, height: 10)
                                .padding(.top, 5)
                            VStack(alignment: .leading, spacing: 2) {
                                Text(action.title)
                                    .font(.footnote.bold())
                                Text(action.description)
                                    .font(.footnote)
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }
                }
            }
        }
    }

    private var fuelCoachCard: some View {
        Card(title: "Ask Fuel Agent") {
            VStack(alignment: .leading, spacing: 12) {
                Text("Keep text input for typed questions, or use the voice button so the future Vapi flow drops into the same answer pipeline.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)

                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        ForEach(dashboard.suggestedQuestions, id: \.self) { question in
                            Button(question) { questionText = question }
                                .buttonStyle(.bordered)
                        }
                    }
                }

                TextField("Ask about gas quality, refill timing, price projections, or station strategy...", text: $questionText, axis: .vertical)
                    .textFieldStyle(.roundedBorder)

                HStack(spacing: 12) {
                    Button {
                        showVoiceAgentSheet = true
                    } label: {
                        Label("Start Voice Agent", systemImage: "mic.circle.fill")
                            .frame(maxWidth: .infinity)
                            .padding()
                    }
                    .buttonStyle(.bordered)

                    Button {
                        Task { await runFuelCoach() }
                    } label: {
                        Text(isAskingFuelCoach ? "Analyzing..." : "Generate Insight")
                            .frame(maxWidth: .infinity)
                            .padding()
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(isAskingFuelCoach || questionText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }

                if let fuelCoachError {
                    Text(fuelCoachError)
                        .font(.footnote)
                        .foregroundStyle(.red)
                }

                if let brief = fuelCoachBrief {
                    Divider()
                    VStack(alignment: .leading, spacing: 8) {
                        Text(brief.summary).font(.subheadline.bold())
                        Text(brief.pricingOutlook).font(.footnote)
                        Text(brief.efficiencyDiagnosis).font(.footnote)
                        ForEach(brief.actionPlan, id: \.self) { step in
                            Text("• \(step)")
                                .font(.footnote)
                                .foregroundStyle(.secondary)
                        }
                    }
                }
            }
        }
    }

    private func loadFuelSummary() async {
        guard let profile = vehicleStore.profile else { return }

        isRefreshingSummary = true
        summaryError = nil
        defer { isRefreshingSummary = false }

        do {
            remoteSummary = try await fuelClient.fetchSummary(
                userId: userId,
                profile: profile,
                trips: tripHistory.trips,
                fuelLogs: fuelLogStore.logs
            )
        } catch {
            remoteSummary = nil
            summaryError = "Using local fuel scaffold because the backend is not reachable yet. \(error.localizedDescription)"
        }
    }

    private func runFuelCoach() async {
        let trimmed = questionText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }

        isAskingFuelCoach = true
        fuelCoachError = nil
        defer { isAskingFuelCoach = false }

        do {
            let response = try await copilotClient.query(
                userId: userId,
                query: """
                Answer this fuel-agent question using the latest fuel intel and trip memory.
                Question: \(trimmed)
                """
            )

            fuelCoachBrief = FuelCoachBrief(
                summary: response.answer,
                pricingOutlook: remoteSummary?.newsHeadline ?? dashboard.projectionSummary,
                efficiencyDiagnosis: response.cards.first?.body ?? dashboard.efficiencyHeadline,
                actionPlan: response.actions.isEmpty
                    ? dashboard.suggestedQuestions.prefix(3).map { "Explore: \($0)" }
                    : response.actions.map { "\($0.title): \($0.description)" }
            )
        } catch {
            fuelCoachBrief = service.fallbackCoachBrief(
                question: trimmed,
                profile: vehicleStore.profile,
                trips: tripHistory.trips,
                fuelLogs: fuelLogStore.logs,
                marketUpdates: dashboard.marketUpdates
            )
            fuelCoachError = error.localizedDescription
        }
    }

    private func dashboard(from summary: FuelSummary) -> FuelDashboard {
        let fallback = service.buildDashboard(
            profile: vehicleStore.profile,
            trips: tripHistory.trips,
            fuelLogs: fuelLogStore.logs
        )

        var stationInsights: [FuelStationInsight] = [
            FuelStationInsight(
                highlight: .cheapest,
                stationName: summary.cheapestStation.name,
                areaLabel: summary.cheapestStation.areaLabel,
                priceText: currency(summary.cheapestStation.price),
                detail: summary.cheapestStation.savingsNote
            )
        ]

        if let premiumStation = summary.premiumStation {
            stationInsights.append(
                FuelStationInsight(
                    highlight: .premiumPick,
                    stationName: premiumStation.name,
                    areaLabel: premiumStation.areaLabel,
                    priceText: currency(premiumStation.price),
                    detail: premiumStation.qualitySignal
                )
            )
        }

        if let promoAction = summary.actions.first(where: { $0.destination == "fuel" || $0.type == .recommendation }) {
            stationInsights.append(
                FuelStationInsight(
                    highlight: .bestPromo,
                    stationName: summary.cheapestStation.name,
                    areaLabel: summary.areaLabel,
                    priceText: currency(summary.cheapestStation.price),
                    detail: promoAction.description
                )
            )
        } else if let fallbackPromo = fallback.stationInsights.first(where: { $0.highlight == .bestPromo }) {
            stationInsights.append(fallbackPromo)
        }

        let direction = trendDirection(from: summary)
        let mappedUpdates: [FuelMarketUpdate] = [
            FuelMarketUpdate(
                headline: "Projected Price Move",
                summary: summary.newsHeadline,
                direction: direction
            )
        ] + summary.cards.prefix(2).map {
            FuelMarketUpdate(
                headline: $0.title,
                summary: $0.body,
                direction: toneDirection($0.tone)
            )
        }

        let coordinationNotes = [
            FuelAgentCoordinationNote(
                source: .marketNews,
                title: "Tinyfish + backend summary",
                summary: "Fuel outlook now comes from the Express backend, which can normalize Tinyfish station and news signals before the app renders cards."
            ),
            FuelAgentCoordinationNote(
                source: .fillHistory,
                title: "Redis-ready driving memory",
                summary: "Saved fuel stops and trip history are sent as payload context so the backend can compare live price shifts against your actual fill-up behavior."
            ),
            FuelAgentCoordinationNote(
                source: .agentBridge,
                title: "Copilot query bridge",
                summary: "Typed questions in this tab now route through the backend copilot layer instead of requiring an API key in the app."
            )
        ]

        return FuelDashboard(
            stationInsights: stationInsights,
            marketUpdates: mappedUpdates,
            spendSnapshot: FuelSpendSnapshot(
                dailyAverage: summary.weeklyCost / 7,
                weeklyTotal: summary.weeklyCost,
                monthlyTotal: summary.monthlyCost,
                yearlyProjection: summary.yearlyCost
            ),
            profileSummary: fallback.profileSummary,
            efficiencyHeadline: summary.cards.first?.body ?? fallback.efficiencyHeadline,
            suggestedQuestions: fallback.suggestedQuestions,
            projectionSummary: "Average \(currency(summary.localAveragePrice)) in \(summary.areaLabel), with about \(currency(summary.estimatedSavings)) in potential weekly savings if you switch to the best current option.",
            coordinationNotes: coordinationNotes
        )
    }

    private func trendDirection(from summary: FuelSummary) -> FuelTrendDirection {
        if let warningCard = summary.cards.first(where: { $0.tone == .warning || $0.tone == .critical }) {
            return toneDirection(warningCard.tone)
        }
        if summary.estimatedSavings > 4 {
            return .down
        }
        return .steady
    }

    private func toneDirection(_ tone: CopilotCardTone) -> FuelTrendDirection {
        switch tone {
        case .success:
            return .down
        case .warning, .critical:
            return .up
        case .info:
            return .steady
        }
    }

    private func priorityColor(_ priority: AgentActionPriority) -> Color {
        switch priority {
        case .low:
            return .blue
        case .medium:
            return .orange
        case .high:
            return .red
        }
    }

    private func sourceIcon(_ source: FuelAgentCoordinationNote.Source) -> some View {
        let config: (String, Color)
        switch source {
        case .marketNews:
            config = ("newspaper.fill", .blue)
        case .fillHistory:
            config = ("fuelpump.fill", .green)
        case .drivingBehavior:
            config = ("speedometer", .orange)
        case .agentBridge:
            config = ("waveform.path.ecg", .purple)
        }

        return Image(systemName: config.0)
            .foregroundStyle(config.1)
            .frame(width: 18)
    }

    private func stationBadge(_ highlight: FuelStationInsight.Highlight) -> some View {
        let config: (String, Color)
        switch highlight {
        case .cheapest:
            config = ("Cheapest", .green)
        case .premiumPick:
            config = ("Quality", .blue)
        case .bestPromo:
            config = ("Promo", .orange)
        }

        return Text(config.0)
            .font(.caption.bold())
            .padding(.horizontal, 8)
            .padding(.vertical, 5)
            .background(config.1.opacity(0.15))
            .foregroundStyle(config.1)
            .clipShape(Capsule())
    }

    private func trendBadge(_ direction: FuelTrendDirection) -> some View {
        let config: (String, Color)
        switch direction {
        case .down:
            config = ("Down", .green)
        case .steady:
            config = ("Stable", .yellow)
        case .up:
            config = ("Up", .red)
        }

        return Text(config.0)
            .font(.caption.bold())
            .padding(.horizontal, 8)
            .padding(.vertical, 5)
            .background(config.1.opacity(0.15))
            .foregroundStyle(config.1)
            .clipShape(Capsule())
    }

    private func statPill(title: String, value: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(title)
                .font(.caption)
                .foregroundStyle(.secondary)
            Text(value)
                .font(.subheadline.bold())
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(10)
        .background(Color.secondary.opacity(0.08))
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
    }

    private func currency(_ value: Double) -> String {
        String(format: "$%.2f", value)
    }
}

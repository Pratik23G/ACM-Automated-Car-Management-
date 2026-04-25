import SwiftUI

struct CopilotHomeView: View {
    @EnvironmentObject var vehicleStore: VehicleProfileStore
    @EnvironmentObject var tripHistory: TripHistoryStore
    @EnvironmentObject var maintenanceStore: MaintenanceStore
    @EnvironmentObject var maintenanceExpenseStore: MaintenanceExpenseStore
    @EnvironmentObject var fuelLogStore: FuelLogStore

    @State private var dailyBrief: DailyBrief?
    @State private var queryText = ""
    @State private var voiceTranscript = ""
    @State private var queryResponse: CopilotQueryResponse?
    @State private var voiceSummary: VoiceSummaryResponse?
    @State private var isRefreshing = false
    @State private var isQuerying = false
    @State private var isSummarizingVoice = false
    @State private var loadError: String?

    private let fuelClient = FuelAgentClient()
    private let maintenanceClient = MaintenanceAgentClient()
    private let copilotClient = CopilotClient()
    private let voiceClient = VoiceAgentClient()

    private var userId: String {
        vehicleStore.profile?.backendUserId ?? "demo-user"
    }

    private var refreshToken: String {
        let profileToken = vehicleStore.profile?.id.uuidString ?? "none"
        return [
            profileToken,
            String(tripHistory.trips.count),
            String(fuelLogStore.logs.count),
            String(maintenanceStore.reminders.count),
            String(maintenanceExpenseStore.expenses.count)
        ].joined(separator: "|")
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                briefStatusCard
                if let dailyBrief {
                    briefCardsCard(dailyBrief)
                }
                queryCard
                voiceCard
            }
            .padding()
        }
        .navigationTitle("Copilot")
        .navigationBarTitleDisplayMode(.large)
        .task(id: refreshToken) {
            await refreshDailyBrief()
        }
        .refreshable {
            await refreshDailyBrief()
        }
    }

    private var briefStatusCard: some View {
        Card(title: "Daily Brief") {
            VStack(alignment: .leading, spacing: 12) {
                if let headline = dailyBrief?.headline {
                    Text(headline)
                        .font(.title3.bold())
                } else if isRefreshing {
                    Text("Refreshing merged fuel and maintenance context from the backend...")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                } else {
                    Text("Run the backend once and this tab will merge the current fuel and maintenance snapshots into one daily brief.")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }

                if let loadError {
                    Text(loadError)
                        .font(.footnote)
                        .foregroundStyle(.red)
                }

                if let actions = dailyBrief?.actions, !actions.isEmpty {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Recommended actions")
                            .font(.subheadline.bold())
                        ForEach(actions) { action in
                            actionRow(action)
                        }
                    }
                }

                Button {
                    Task { await refreshDailyBrief() }
                } label: {
                    Text(isRefreshing ? "Refreshing..." : "Refresh Brief")
                        .frame(maxWidth: .infinity)
                        .padding()
                }
                .buttonStyle(.borderedProminent)
                .disabled(isRefreshing)
            }
        }
    }

    private func briefCardsCard(_ brief: DailyBrief) -> some View {
        Card(title: "Structured Cards") {
            VStack(alignment: .leading, spacing: 12) {
                ForEach(brief.cards) { card in
                    VStack(alignment: .leading, spacing: 6) {
                        Text(card.title)
                            .font(.subheadline.bold())
                        Text(card.body)
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                        if let items = card.items, !items.isEmpty {
                            ForEach(items, id: \.self) { item in
                                Row(label: item.label, value: item.value)
                            }
                        }
                        if card.id != brief.cards.last?.id {
                            Divider()
                        }
                    }
                }
            }
        }
    }

    private var queryCard: some View {
        Card(title: "Ask Copilot") {
            VStack(alignment: .leading, spacing: 12) {
                Text("This sends your question to the backend so fuel and maintenance context can answer together.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)

                TextField("Ask a combined question about fuel, maintenance, or both...", text: $queryText, axis: .vertical)
                    .textFieldStyle(.roundedBorder)

                Button {
                    Task { await runQuery() }
                } label: {
                    Text(isQuerying ? "Thinking..." : "Ask Copilot")
                        .frame(maxWidth: .infinity)
                        .padding()
                }
                .buttonStyle(.borderedProminent)
                .disabled(isQuerying || queryText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)

                if let queryResponse {
                    Divider()
                    Text(queryResponse.answer)
                        .font(.subheadline.bold())
                    ForEach(queryResponse.cards) { card in
                        VStack(alignment: .leading, spacing: 4) {
                            Text(card.title)
                                .font(.footnote.bold())
                            Text(card.body)
                                .font(.footnote)
                                .foregroundStyle(.secondary)
                        }
                    }
                }
            }
        }
    }

    private var voiceCard: some View {
        Card(title: "Voice Summary") {
            VStack(alignment: .leading, spacing: 12) {
                Text("This is the SwiftUI handoff point for Vapi. For now, type the voice transcript you want summarized and the backend will shape the response.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)

                TextField("Example: summarize what changed with my fuel and maintenance this week", text: $voiceTranscript, axis: .vertical)
                    .textFieldStyle(.roundedBorder)

                Button {
                    Task { await runVoiceSummary() }
                } label: {
                    Text(isSummarizingVoice ? "Summarizing..." : "Generate Voice Summary")
                        .frame(maxWidth: .infinity)
                        .padding()
                }
                .buttonStyle(.bordered)
                .disabled(isSummarizingVoice || voiceTranscript.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)

                if let voiceSummary {
                    Divider()
                    Text(voiceSummary.summary)
                        .font(.subheadline.bold())
                    ForEach(voiceSummary.cards) { card in
                        VStack(alignment: .leading, spacing: 4) {
                            Text(card.title)
                                .font(.footnote.bold())
                            Text(card.body)
                                .font(.footnote)
                                .foregroundStyle(.secondary)
                        }
                    }
                }
            }
        }
    }

    private func actionRow(_ action: AgentAction) -> some View {
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

    private func refreshDailyBrief() async {
        guard let profile = vehicleStore.profile else { return }

        isRefreshing = true
        loadError = nil
        defer { isRefreshing = false }

        do {
            async let fuelSummary = fuelClient.fetchSummary(
                userId: userId,
                profile: profile,
                trips: tripHistory.trips,
                fuelLogs: fuelLogStore.logs
            )
            async let maintenanceAnalysis = maintenanceClient.analyze(
                userId: userId,
                profile: profile,
                reminders: maintenanceStore.reminders,
                trips: tripHistory.trips,
                expenses: maintenanceExpenseStore.expenses
            )

            _ = try await fuelSummary
            _ = try await maintenanceAnalysis
            dailyBrief = try await copilotClient.fetchDailyBrief(userId: userId)
        } catch {
            loadError = error.localizedDescription
        }
    }

    private func runQuery() async {
        let trimmed = queryText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }

        isQuerying = true
        defer { isQuerying = false }

        do {
            queryResponse = try await copilotClient.query(userId: userId, query: trimmed)
        } catch {
            loadError = error.localizedDescription
        }
    }

    private func runVoiceSummary() async {
        let trimmed = voiceTranscript.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }

        isSummarizingVoice = true
        defer { isSummarizingVoice = false }

        do {
            voiceSummary = try await voiceClient.summarize(userId: userId, context: .copilot, transcript: trimmed)
        } catch {
            loadError = error.localizedDescription
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
}

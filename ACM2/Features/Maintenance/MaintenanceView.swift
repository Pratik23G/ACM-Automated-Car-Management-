import SwiftUI

struct MaintenanceView: View {

    @EnvironmentObject var maintenanceStore: MaintenanceStore
    @EnvironmentObject var maintenanceExpenseStore: MaintenanceExpenseStore
    @EnvironmentObject var tripHistory: TripHistoryStore
    @EnvironmentObject var vehicleStore: VehicleProfileStore

    @State private var editingReminder: MaintenanceReminder?
    @State private var editIntervalText: String = ""
    @State private var remoteAnalysis: MaintenanceAnalysis?
    @State private var isRefreshingAnalysis = false
    @State private var analysisError: String?

    private let maintenanceClient = MaintenanceAgentClient()

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

    private var hasBehaviorData: Bool { tripHistory.trips.count >= 3 }

    private var alertCount: Int {
        if let remoteAnalysis {
            return remoteAnalysis.estimates.filter { $0.severity != .ok }.count
        }

        return maintenanceStore.reminders.filter { reminder in
            let effectiveInterval = reminder.effectiveInterval(
                avgHardBrakes: avgHardBrakes,
                avgSharpTurns: avgSharpTurns,
                avgAggression: avgAggression,
                tripCount: tripHistory.trips.count
            )
            return reminder.isOverdue(currentOdometer: currentOdometer, effectiveInterval: effectiveInterval)
                || reminder.isDueSoon(currentOdometer: currentOdometer, effectiveInterval: effectiveInterval)
        }.count
    }

    private var refreshToken: String {
        let profileToken = vehicleStore.profile?.id.uuidString ?? "none"
        return [
            profileToken,
            String(tripHistory.trips.count),
            String(maintenanceStore.reminders.count),
            String(maintenanceExpenseStore.expenses.count)
        ].joined(separator: "|")
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 14) {
                mileageCard
                if remoteAnalysis != nil || analysisError != nil || isRefreshingAnalysis {
                    agentSnapshotCard(remoteAnalysis)
                }
                if hasBehaviorData { behaviorBadge }
                if alertCount > 0 { alertBanner }
                ForEach(maintenanceStore.reminders) { reminder in
                    reminderCard(reminder)
                }
            }
            .padding()
        }
        .navigationTitle("Maintenance")
        .sheet(item: $editingReminder) { reminder in
            editIntervalSheet(reminder: reminder)
        }
        .task(id: refreshToken) {
            await loadAnalysis()
        }
        .refreshable {
            await loadAnalysis()
        }
    }

    private var mileageCard: some View {
        Card(title: "Vehicle Mileage") {
            if let baseline = vehicleStore.profile?.currentOdometerMiles {
                Row(label: "Odometer (from setup)", value: String(format: "%.0f mi", baseline))
            } else {
                HStack {
                    Text("Odometer baseline").foregroundStyle(.secondary)
                    Spacer()
                    Text("Not set").foregroundStyle(.orange).fontWeight(.semibold)
                }
            }
            Row(label: "Miles tracked in app", value: String(format: "%.1f mi", tripHistory.totalMilesEstimated))
            Row(label: "Estimated total", value: String(format: "%.0f mi", currentOdometer))

            if vehicleStore.profile?.currentOdometerMiles == nil {
                Text("⚠️ Add your odometer reading in Vehicle Setup for accurate reminders.")
                    .font(.caption).foregroundStyle(.orange).padding(.top, 2)
            }
        }
    }

    private func agentSnapshotCard(_ analysis: MaintenanceAnalysis?) -> some View {
        Card(title: "Maintenance Agent") {
            VStack(alignment: .leading, spacing: 10) {
                if let summaryCard = analysis?.cards.first {
                    Text(summaryCard.title)
                        .font(.subheadline.bold())
                    Text(summaryCard.body)
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }

                if let analysisError {
                    Text(analysisError)
                        .font(.footnote)
                        .foregroundStyle(.orange)
                } else if isRefreshingAnalysis {
                    Text("Refreshing backend maintenance analysis...")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }

                if let actions = analysis?.actions, !actions.isEmpty {
                    Divider()
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

    private var behaviorBadge: some View {
        HStack(spacing: 10) {
            Image(systemName: "gauge.with.needle.fill").foregroundStyle(.purple)
            VStack(alignment: .leading, spacing: 2) {
                Text("Intervals adjusted for your driving style")
                    .font(.subheadline.bold())
                Text("Based on \(tripHistory.trips.count) trips — hard braking, sharp turns, and aggression all factor in.")
                    .font(.caption).foregroundStyle(.secondary)
            }
            Spacer()
        }
        .padding(12)
        .background(Color.purple.opacity(0.08))
        .clipShape(RoundedRectangle(cornerRadius: 14))
        .overlay(RoundedRectangle(cornerRadius: 14).stroke(Color.purple.opacity(0.2), lineWidth: 1))
    }

    private var alertBanner: some View {
        HStack(spacing: 10) {
            Image(systemName: "wrench.and.screwdriver.fill").foregroundStyle(.white)
            Text("\(alertCount) service\(alertCount == 1 ? "" : "s") need\(alertCount == 1 ? "s" : "") attention")
                .font(.subheadline.bold()).foregroundStyle(.white)
            Spacer()
        }
        .padding()
        .background(Color.orange)
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
    }

    @ViewBuilder
    private func reminderCard(_ reminder: MaintenanceReminder) -> some View {
        let tripCount = tripHistory.trips.count
        let localEffectiveInterval = reminder.effectiveInterval(
            avgHardBrakes: avgHardBrakes,
            avgSharpTurns: avgSharpTurns,
            avgAggression: avgAggression,
            tripCount: tripCount
        )
        let remoteEstimate = remoteEstimate(for: reminder)
        let effectiveInterval = remoteEstimate?.adjustedIntervalMiles ?? localEffectiveInterval
        let overdue = remoteEstimate?.severity == .overdue
            || reminder.isOverdue(currentOdometer: currentOdometer, effectiveInterval: effectiveInterval)
        let soon = remoteEstimate?.severity == .soon
            || reminder.isDueSoon(currentOdometer: currentOdometer, effectiveInterval: effectiveInterval)
        let statusColor: Color = overdue ? .red : soon ? .orange : .green
        let statusLabel = overdue ? "Overdue" : soon ? "Due Soon" : "OK"
        let rawMilesLeft = remoteEstimate?.dueInMiles ?? reminder.milesUntilDue(currentOdometer: currentOdometer, effectiveInterval: effectiveInterval)
        let milesLeft = max(0, rawMilesLeft)
        let milesSinceService = reminder.milesSinceService(currentOdometer: currentOdometer)
        let progress = min(1.0, max(0, milesSinceService / max(effectiveInterval, 1)))
        let isAdjusted = hasBehaviorData && effectiveInterval < reminder.intervalMiles
        let reason = remoteEstimate?.reason ?? reminder.adjustmentReason(
            avgHardBrakes: avgHardBrakes,
            avgSharpTurns: avgSharpTurns,
            avgAggression: avgAggression,
            tripCount: tripCount
        )

        Card(title: reminder.serviceType.label) {
            HStack(spacing: 14) {
                ZStack {
                    Circle().fill(statusColor.opacity(0.15)).frame(width: 46, height: 46)
                    Image(systemName: reminder.serviceType.icon)
                        .font(.title3).foregroundStyle(statusColor)
                }

                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        Text(statusLabel).font(.subheadline.bold()).foregroundStyle(statusColor)
                        Spacer()
                        if overdue {
                            let overdueMiles = abs(min(0, rawMilesLeft))
                            Text("\(Int(overdueMiles)) mi overdue")
                                .font(.caption.bold()).foregroundStyle(.red)
                        } else {
                            Text("\(Int(milesLeft)) mi left")
                                .font(.caption).foregroundStyle(.secondary)
                        }
                    }

                    GeometryReader { geo in
                        ZStack(alignment: .leading) {
                            RoundedRectangle(cornerRadius: 4)
                                .fill(Color.gray.opacity(0.18)).frame(height: 7)
                            RoundedRectangle(cornerRadius: 4)
                                .fill(statusColor)
                                .frame(width: geo.size.width * CGFloat(progress), height: 7)
                                .animation(.spring(duration: 0.6), value: progress)
                        }
                    }
                    .frame(height: 7)

                    HStack(spacing: 6) {
                        if isAdjusted {
                            Text("Every")
                                .font(.caption).foregroundStyle(.secondary)
                            Text("\(Int(reminder.intervalMiles)) mi")
                                .font(.caption).foregroundStyle(.secondary)
                                .strikethrough(true, color: .secondary)
                            Text("→ \(Int(effectiveInterval)) mi")
                                .font(.caption.bold()).foregroundStyle(.purple)
                        } else {
                            Text("Every \(Int(effectiveInterval)) mi")
                                .font(.caption).foregroundStyle(.secondary)
                        }
                        Spacer()
                        if let date = reminder.lastServiceDate {
                            Text("Last: \(date.formatted(date: .abbreviated, time: .omitted))")
                                .font(.caption).foregroundStyle(.secondary)
                        } else {
                            Text(remoteEstimate?.dueDateLabel ?? "No service logged")
                                .font(.caption).foregroundStyle(.secondary)
                        }
                    }
                }
            }

            if let reason {
                HStack(spacing: 6) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .font(.caption2).foregroundStyle(.purple)
                    Text(reason).font(.caption).foregroundStyle(.purple)
                }
                .padding(.horizontal, 10).padding(.vertical, 6)
                .background(Color.purple.opacity(0.07))
                .clipShape(RoundedRectangle(cornerRadius: 8))
            }

            if let recommendedAction = remoteEstimate?.recommendedAction {
                Text(recommendedAction)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Divider().padding(.vertical, 4)

            HStack(spacing: 8) {
                Button {
                    maintenanceStore.markServiced(id: reminder.id, currentOdometer: currentOdometer)
                } label: {
                    Label("Mark Serviced", systemImage: "checkmark.circle.fill")
                        .frame(maxWidth: .infinity).padding(.vertical, 8)
                }
                .buttonStyle(.borderedProminent).tint(.green)

                Button {
                    editingReminder = reminder
                } label: {
                    Label("Edit Interval", systemImage: "slider.horizontal.3")
                        .frame(maxWidth: .infinity).padding(.vertical, 8)
                }
                .buttonStyle(.bordered)
            }
        }
    }

    private func editIntervalSheet(reminder: MaintenanceReminder) -> some View {
        NavigationStack {
            Form {
                Section("Base miles between \(reminder.serviceType.label)s") {
                    TextField("Miles", text: $editIntervalText).keyboardType(.numberPad)
                }
                Section {
                    Text("Default: \(Int(reminder.serviceType.defaultIntervalMiles)) mi")
                        .font(.footnote).foregroundStyle(.secondary)
                    if hasBehaviorData {
                        let tripCount = tripHistory.trips.count
                        let effectiveInterval = reminder.effectiveInterval(
                            avgHardBrakes: avgHardBrakes,
                            avgSharpTurns: avgSharpTurns,
                            avgAggression: avgAggression,
                            tripCount: tripCount
                        )
                        if let miles = Double(editIntervalText), miles > 0 {
                            let factor = 1.0 - reminder.reductionFactor(
                                avgHardBrakes: avgHardBrakes,
                                avgSharpTurns: avgSharpTurns,
                                avgAggression: avgAggression,
                                tripCount: tripCount
                            )
                            let preview = (miles * factor).rounded()
                            Text("With your driving style → effective interval: \(Int(preview)) mi")
                                .font(.footnote).foregroundStyle(.purple)
                        }
                        if effectiveInterval < reminder.intervalMiles {
                            Text("Your driving behavior is currently shortening this interval.")
                                .font(.caption).foregroundStyle(.secondary)
                        }
                    }
                }
            }
            .navigationTitle("Edit Interval")
            .navigationBarTitleDisplayMode(.inline)
            .onAppear { editIntervalText = String(Int(reminder.intervalMiles)) }
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        if let miles = Double(editIntervalText), miles > 0 {
                            maintenanceStore.updateInterval(id: reminder.id, miles: miles)
                        }
                        editingReminder = nil
                    }
                }
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { editingReminder = nil }
                }
            }
        }
    }

    private func loadAnalysis() async {
        guard let profile = vehicleStore.profile else { return }

        isRefreshingAnalysis = true
        analysisError = nil
        defer { isRefreshingAnalysis = false }

        do {
            remoteAnalysis = try await maintenanceClient.analyze(
                userId: profile.backendUserId,
                profile: profile,
                reminders: maintenanceStore.reminders,
                trips: tripHistory.trips,
                expenses: maintenanceExpenseStore.expenses
            )
        } catch {
            remoteAnalysis = nil
            analysisError = "Using on-device maintenance logic because the backend is not reachable yet. \(error.localizedDescription)"
        }
    }

    private func remoteEstimate(for reminder: MaintenanceReminder) -> MaintenanceEstimate? {
        remoteAnalysis?.estimates.first { $0.serviceType.rawValue == reminder.serviceType.rawValue }
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

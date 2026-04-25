import SwiftUI

struct CostTrackerView: View {

    @EnvironmentObject var fuelLogStore: FuelLogStore
    @EnvironmentObject var maintenanceExpenseStore: MaintenanceExpenseStore

    @State private var selectedMode: CostTrackerMode = .fuel
    @State private var selectedPeriod: FuelCostPeriod = .weekly
    @State private var showMaintenanceExpenseSheet = false

    private let service = FuelAgentService()

    private var fuelSummary: FuelCostSummary {
        service.buildCostSummary(period: selectedPeriod, fuelLogs: fuelLogStore.logs)
    }

    private var maintenanceSummary: MaintenanceCostSummary {
        service.buildMaintenanceCostSummary(period: selectedPeriod, expenses: maintenanceExpenseStore.expenses)
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                modePicker
                periodPicker
                agentBridgeCard
                if selectedMode == .fuel {
                    fuelHeadlineCard
                    fuelHistoryChartCard
                    fuelInsightCard
                    recentFillUpsCard
                } else {
                    maintenanceEntryCard
                    maintenanceHeadlineCard
                    maintenanceHistoryChartCard
                    maintenanceInsightCard
                    recentMaintenancePurchasesCard
                }
            }
            .padding()
        }
        .navigationTitle("Cost Tracker")
        .navigationBarTitleDisplayMode(.large)
        .toolbar {
            if selectedMode == .maintenance {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button {
                        showMaintenanceExpenseSheet = true
                    } label: {
                        Label("Add Entry", systemImage: "plus")
                    }
                }
            }
        }
        .sheet(isPresented: $showMaintenanceExpenseSheet) {
            MaintenanceExpenseSheet { expense in
                maintenanceExpenseStore.add(expense)
            }
        }
    }

    private var agentBridgeCard: some View {
        Card(title: "Agent Backbone") {
            Text(selectedMode == .fuel
                 ? "Fuel logs from this tracker are already shaped so the Fuel Agent backend can read them for summaries, savings cards, and daily briefs."
                 : "Maintenance purchases from this tracker are already shaped so the Maintenance Agent backend can explain parts spend alongside service timing.")
                .font(.footnote)
                .foregroundStyle(.secondary)
        }
    }

    private var modePicker: some View {
        Picker("Tracker Mode", selection: $selectedMode) {
            ForEach(CostTrackerMode.allCases) { mode in
                Text(mode.rawValue).tag(mode)
            }
        }
        .pickerStyle(.segmented)
    }

    private var periodPicker: some View {
        Picker("Period", selection: $selectedPeriod) {
            ForEach(FuelCostPeriod.allCases) { period in
                Text(period.rawValue).tag(period)
            }
        }
        .pickerStyle(.segmented)
    }

    private var fuelHeadlineCard: some View {
        let summary = fuelSummary

        return Card(title: summary.headline) {
            VStack(alignment: .leading, spacing: 12) {
                if summary.fillUpCount == 0 {
                    Text(summary.summary)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                } else {
                    HStack(alignment: .bottom, spacing: 6) {
                        Text(currency(summary.totalSpend))
                            .font(.system(size: 44, weight: .black, design: .rounded))
                        Text(selectedPeriod.rawValue.lowercased())
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                            .padding(.bottom, 8)
                    }

                    Text(summary.summary)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)

                    HStack(spacing: 12) {
                        metricCard(title: "Fill-Ups", value: "\(summary.fillUpCount)")
                        metricCard(title: "Avg Fill", value: currency(summary.averageFillCost))
                        metricCard(title: "Avg Price", value: summary.averagePricePerUnit > 0 ? String(format: "$%.2f", summary.averagePricePerUnit) : "--")
                    }

                    HStack(spacing: 12) {
                        metricCard(title: "Common Station", value: summary.dominantStation ?? "--")
                        metricCard(title: "Common Area", value: summary.dominantArea ?? "--")
                    }

                    Text(summary.comparisonText)
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
            }
        }
    }

    private var maintenanceEntryCard: some View {
        Card(title: "Manual Maintenance Entries") {
            VStack(alignment: .leading, spacing: 12) {
                Text("Switch into maintenance mode when you want to log oil, tires, filters, or other parts with date, location, price, and notes.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)

                Text("These entries stay separate from fuel spend, but they give your future maintenance agent better cost context.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)

                Button {
                    showMaintenanceExpenseSheet = true
                } label: {
                    Label("Add Maintenance Purchase", systemImage: "plus.circle.fill")
                        .frame(maxWidth: .infinity)
                        .padding()
                }
                .buttonStyle(.borderedProminent)
            }
        }
    }

    private var maintenanceHeadlineCard: some View {
        let summary = maintenanceSummary

        return Card(title: summary.headline) {
            VStack(alignment: .leading, spacing: 12) {
                if summary.entryCount == 0 {
                    Text(summary.summary)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                } else {
                    HStack(alignment: .bottom, spacing: 6) {
                        Text(currency(summary.totalSpend))
                            .font(.system(size: 44, weight: .black, design: .rounded))
                        Text(selectedPeriod.rawValue.lowercased())
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                            .padding(.bottom, 8)
                    }

                    Text(summary.summary)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)

                    HStack(spacing: 12) {
                        metricCard(title: "Entries", value: "\(summary.entryCount)")
                        metricCard(title: "Avg Purchase", value: currency(summary.averageEntryCost))
                        metricCard(title: "Top Category", value: summary.dominantCategory ?? "--")
                    }

                    HStack(spacing: 12) {
                        metricCard(title: "Common Shop", value: summary.dominantLocation ?? "--")
                        metricCard(title: "Notes Ready", value: summary.expenses.contains { $0.notes?.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == false } ? "Yes" : "Add notes")
                    }

                    Text(summary.comparisonText)
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
            }
        }
    }

    private var fuelHistoryChartCard: some View {
        let summary = fuelSummary

        return Card(title: "\(selectedPeriod.rawValue) History") {
            if summary.buckets.isEmpty {
                Text("No cost history yet for this view.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            } else {
                let maxSpend = max(summary.buckets.map(\.totalSpend).max() ?? 1, 1)
                GeometryReader { geo in
                    HStack(alignment: .bottom, spacing: 8) {
                        ForEach(summary.buckets) { bucket in
                            VStack(spacing: 6) {
                                Text(currency(bucket.totalSpend))
                                    .font(.system(size: 10))
                                    .foregroundStyle(.secondary)
                                RoundedRectangle(cornerRadius: 8)
                                    .fill(Color.green.opacity(0.75))
                                    .frame(
                                        width: max(18, (geo.size.width - CGFloat(max(summary.buckets.count - 1, 0)) * 8) / CGFloat(max(summary.buckets.count, 1))),
                                        height: max(10, 120 * CGFloat(bucket.totalSpend / maxSpend))
                                    )
                                Text(bucket.label)
                                    .font(.system(size: 10))
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottom)
                }
                .frame(height: 170)

                Divider()

                ForEach(summary.buckets.reversed()) { bucket in
                    HStack(alignment: .top) {
                        VStack(alignment: .leading, spacing: 4) {
                            Text(bucket.label).font(.subheadline.bold())
                            Text(bucket.summary)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        Spacer()
                        VStack(alignment: .trailing, spacing: 4) {
                            Text(currency(bucket.totalSpend))
                                .font(.subheadline.bold())
                            Text(bucket.averagePrice > 0 ? String(format: "$%.2f avg/unit", bucket.averagePrice) : "--")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                    if bucket.id != summary.buckets.first?.id {
                        Divider()
                    }
                }
            }
        }
    }

    private var maintenanceHistoryChartCard: some View {
        let summary = maintenanceSummary

        return Card(title: "\(selectedPeriod.rawValue) History") {
            if summary.buckets.isEmpty {
                Text("No maintenance purchases have been logged for this view yet.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            } else {
                let maxSpend = max(summary.buckets.map(\.totalSpend).max() ?? 1, 1)
                GeometryReader { geo in
                    HStack(alignment: .bottom, spacing: 8) {
                        ForEach(summary.buckets) { bucket in
                            VStack(spacing: 6) {
                                Text(currency(bucket.totalSpend))
                                    .font(.system(size: 10))
                                    .foregroundStyle(.secondary)
                                RoundedRectangle(cornerRadius: 8)
                                    .fill(Color.orange.opacity(0.75))
                                    .frame(
                                        width: max(18, (geo.size.width - CGFloat(max(summary.buckets.count - 1, 0)) * 8) / CGFloat(max(summary.buckets.count, 1))),
                                        height: max(10, 120 * CGFloat(bucket.totalSpend / maxSpend))
                                    )
                                Text(bucket.label)
                                    .font(.system(size: 10))
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottom)
                }
                .frame(height: 170)

                Divider()

                ForEach(summary.buckets.reversed()) { bucket in
                    HStack(alignment: .top) {
                        VStack(alignment: .leading, spacing: 4) {
                            Text(bucket.label).font(.subheadline.bold())
                            Text(bucket.summary)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        Spacer()
                        VStack(alignment: .trailing, spacing: 4) {
                            Text(currency(bucket.totalSpend))
                                .font(.subheadline.bold())
                            Text(bucket.dominantCategory ?? "\(bucket.purchaseCount) entries")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                    if bucket.id != summary.buckets.first?.id {
                        Divider()
                    }
                }
            }
        }
    }

    private var fuelInsightCard: some View {
        let summary = fuelSummary

        return Card(title: "Specific Insights") {
            VStack(alignment: .leading, spacing: 10) {
                if summary.insights.isEmpty {
                    Text("More fill-ups will unlock richer insights for this period.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                } else {
                    ForEach(summary.insights, id: \.self) { insight in
                        Text("• \(insight)")
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                    }
                }
            }
        }
    }

    private var maintenanceInsightCard: some View {
        let summary = maintenanceSummary

        return Card(title: "Specific Insights") {
            VStack(alignment: .leading, spacing: 10) {
                if summary.insights.isEmpty {
                    Text("Add a few maintenance purchases to unlock richer insights for this period.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                } else {
                    ForEach(summary.insights, id: \.self) { insight in
                        Text("• \(insight)")
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                    }
                }
            }
        }
    }

    private var recentFillUpsCard: some View {
        let summary = fuelSummary
        let recentLogs = Array(summary.logs.prefix(6))

        return Card(title: "Latest Fill-Ups In View") {
            if summary.logs.isEmpty {
                Text("No fill-ups are currently captured for this time range.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            } else {
                ForEach(recentLogs) { log in
                    HStack(alignment: .top) {
                        VStack(alignment: .leading, spacing: 4) {
                            Text(log.stationName)
                                .font(.subheadline.bold())
                            Text("\(log.areaLabel) • \(log.fuelProduct.label)")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                            if let promo = log.promoTitle, !promo.isEmpty {
                                Text(promo)
                                    .font(.caption)
                                    .foregroundStyle(.orange)
                            }
                        }
                        Spacer()
                        VStack(alignment: .trailing, spacing: 4) {
                            Text(currency(log.totalCost))
                                .font(.subheadline.bold())
                            Text("\(String(format: "$%.2f", log.pricePerUnit))/unit")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                            Text(log.loggedAt.formatted(date: .abbreviated, time: .omitted))
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                        }
                    }
                    if log.id != recentLogs.last?.id {
                        Divider()
                    }
                }
            }
        }
    }

    private var recentMaintenancePurchasesCard: some View {
        let summary = maintenanceSummary
        let recentExpenses = Array(summary.expenses.prefix(6))

        return Card(title: "Latest Maintenance Purchases In View") {
            if summary.expenses.isEmpty {
                Text("No maintenance purchases are currently captured for this time range.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            } else {
                ForEach(recentExpenses) { expense in
                    HStack(alignment: .top) {
                        VStack(alignment: .leading, spacing: 4) {
                            HStack(spacing: 6) {
                                Image(systemName: expense.category.icon)
                                    .foregroundStyle(.orange)
                                Text(expense.itemName)
                                    .font(.subheadline.bold())
                            }
                            Text("\(expense.category.label) • \(expense.purchaseLocation)")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                            if let notes = expense.notes, !notes.isEmpty {
                                Text(notes)
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }
                        Spacer()
                        VStack(alignment: .trailing, spacing: 4) {
                            Text(currency(expense.totalCost))
                                .font(.subheadline.bold())
                            Text(expense.purchasedAt.formatted(date: .abbreviated, time: .omitted))
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                        }
                    }
                    if expense.id != recentExpenses.last?.id {
                        Divider()
                    }
                }
            }
        }
    }

    private func metricCard(title: String, value: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.caption)
                .foregroundStyle(.secondary)
            Text(value)
                .font(.subheadline.bold())
                .lineLimit(2)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding()
        .background(Color.secondary.opacity(0.08))
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
    }

    private func currency(_ value: Double) -> String {
        String(format: "$%.2f", value)
    }
}

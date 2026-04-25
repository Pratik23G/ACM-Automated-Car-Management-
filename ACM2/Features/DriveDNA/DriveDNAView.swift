import SwiftUI

struct DriveDNAView: View {

    @EnvironmentObject var tripHistory:  TripHistoryStore
    @EnvironmentObject var vehicleStore: VehicleProfileStore

    @State private var insights:       DriveDNAInsights?
    @State private var isLoadingAI     = false
    @State private var aiError:        String?

    private var dna: DriveDNA { DriveDNA(trips: tripHistory.trips) }
    private var hasEnoughData: Bool { tripHistory.trips.count >= 3 }

    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                if tripHistory.trips.isEmpty {
                    emptyState
                } else {
                    fingerprintCard
                    if hasEnoughData {
                        dayBreakdownCard
                        timeBreakdownCard
                        weekdayWeekendCard
                        aiInsightsCard
                    } else {
                        needMoreDataCard
                    }
                }
            }
            .padding()
        }
        .navigationTitle("Drive DNA")
        .navigationBarTitleDisplayMode(.large)
    }

    // MARK: - Empty State

    private var emptyState: some View {
        VStack(spacing: 16) {
            Image(systemName: "dna").font(.system(size: 60)).foregroundStyle(.secondary)
            Text("No Driving Data Yet").font(.title3.bold())
            Text("Save a few trips to start building your Drive DNA fingerprint.")
                .font(.subheadline).foregroundStyle(.secondary).multilineTextAlignment(.center)
                .padding(.horizontal, 32)
        }
        .padding(.top, 60)
    }

    // MARK: - Fingerprint Card

    private var fingerprintCard: some View {
        Card(title: "Your Driving Fingerprint") {
            HStack(spacing: 20) {
                // Style indicator
                ZStack {
                    Circle().stroke(dna.fingerprintColor.opacity(0.2), lineWidth: 14)
                    Circle()
                        .trim(from: 0, to: CGFloat(max(0, 1.0 - (dna.avgAggression / 20.0))))
                        .stroke(dna.fingerprintColor,
                                style: StrokeStyle(lineWidth: 14, lineCap: .round))
                        .rotationEffect(.degrees(-90))
                        .animation(.spring(duration: 1.0), value: dna.avgAggression)
                    VStack(spacing: 2) {
                        Image(systemName: "car.fill")
                            .font(.title2).foregroundStyle(dna.fingerprintColor)
                        Text(dna.fingerprintLabel)
                            .font(.system(size: 11, weight: .bold))
                            .foregroundStyle(dna.fingerprintColor)
                            .multilineTextAlignment(.center)
                    }
                }
                .frame(width: 100, height: 100)

                VStack(alignment: .leading, spacing: 8) {
                    statRow(label: "Trips Analyzed", value: "\(dna.totalTrips)")
                    statRow(label: "Total Miles",    value: String(format: "%.0f mi", dna.totalMiles))
                    statRow(label: "Avg Aggression", value: String(format: "%.1f / trip", dna.avgAggression))
                    statRow(label: "Avg MPG",        value: String(format: "%.1f", dna.avgMpg))
                }
                Spacer()
            }

            Divider().padding(.vertical, 6)

            HStack(spacing: 0) {
                eventCell(icon: "exclamationmark.triangle.fill", color: .red,
                          value: String(format: "%.1f", dna.avgHardBrakesPerTrip),
                          label: "Hard Brakes\n/ trip")
                Divider().frame(height: 44)
                eventCell(icon: "arrow.uturn.right.circle.fill", color: .orange,
                          value: String(format: "%.1f", dna.avgSharpTurnsPerTrip),
                          label: "Sharp Turns\n/ trip")
                Divider().frame(height: 44)
                eventCell(icon: "bolt.fill", color: Color(red: 0.9, green: 0.7, blue: 0.0),
                          value: String(format: "%.1f", dna.avgAggressiveAccelsPerTrip),
                          label: "Hard Accels\n/ trip")
            }
        }
    }

    // MARK: - Day Breakdown Card

    private var dayBreakdownCard: some View {
        Card(title: "Aggression by Day of Week") {
            let maxAgg = dna.byDay.map { $0.avgAggression }.max() ?? 1

            VStack(spacing: 10) {
                ForEach(dna.byDay, id: \.day.id) { stat in
                    HStack(spacing: 10) {
                        Text(stat.day.rawValue)
                            .font(.caption.bold())
                            .frame(width: 30, alignment: .leading)
                            .foregroundStyle(stat.day == dna.worstDay?.day ? .red : .primary)

                        GeometryReader { geo in
                            ZStack(alignment: .leading) {
                                RoundedRectangle(cornerRadius: 5)
                                    .fill(Color.gray.opacity(0.12))
                                    .frame(height: 22)
                                if stat.tripCount > 0 {
                                    RoundedRectangle(cornerRadius: 5)
                                        .fill(barColor(aggression: stat.avgAggression,
                                                       maxValue: maxAgg))
                                        .frame(width: max(4, geo.size.width * CGFloat(stat.avgAggression / max(maxAgg, 1))),
                                               height: 22)
                                        .animation(.spring(duration: 0.6), value: stat.avgAggression)
                                }
                            }
                        }
                        .frame(height: 22)

                        if stat.tripCount > 0 {
                            Text("\(stat.tripCount)t")
                                .font(.caption2).foregroundStyle(.secondary)
                                .frame(width: 24)
                        } else {
                            Text("—").font(.caption2).foregroundStyle(.secondary).frame(width: 24)
                        }
                    }
                }
            }

            if let worst = dna.worstDay, let best = dna.bestDay {
                Divider().padding(.vertical, 4)
                HStack {
                    Label("\(worst.day.rawValue) is your most aggressive day",
                          systemImage: "exclamationmark.triangle.fill")
                        .font(.caption).foregroundStyle(.red)
                    Spacer()
                }
                HStack {
                    Label("\(best.day.rawValue) is your smoothest day",
                          systemImage: "checkmark.shield.fill")
                        .font(.caption).foregroundStyle(.green)
                    Spacer()
                }
            }
        }
    }

    // MARK: - Time Breakdown Card

    private var timeBreakdownCard: some View {
        Card(title: "Driving by Time of Day") {
            let maxAgg = dna.byTime.map { $0.avgAggression }.max() ?? 1

            LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 2), spacing: 12) {
                ForEach(dna.byTime, id: \.slot.id) { stat in
                    timeSlotCell(stat: stat, maxAgg: maxAgg)
                }
            }
        }
    }

    private func timeSlotCell(stat: DriveDNA.TimeStats, maxAgg: Double) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Image(systemName: stat.slot.icon).foregroundStyle(stat.slot.color)
                Text(stat.slot.rawValue).font(.subheadline.bold())
                Spacer()
                Text("\(stat.tripCount) trips").font(.caption).foregroundStyle(.secondary)
            }
            if stat.tripCount > 0 {
                GeometryReader { geo in
                    ZStack(alignment: .leading) {
                        RoundedRectangle(cornerRadius: 4).fill(Color.gray.opacity(0.12)).frame(height: 8)
                        RoundedRectangle(cornerRadius: 4)
                            .fill(barColor(aggression: stat.avgAggression, maxValue: maxAgg))
                            .frame(width: max(4, geo.size.width * CGFloat(stat.avgAggression / max(maxAgg, 1))),
                                   height: 8)
                    }
                }
                .frame(height: 8)
                Text("Aggression: \(String(format: "%.1f", stat.avgAggression))")
                    .font(.caption).foregroundStyle(.secondary)
            } else {
                Text("No data").font(.caption).foregroundStyle(.secondary)
            }
        }
        .padding(10)
        .background(stat.slot.color.opacity(0.07))
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
    }

    // MARK: - Weekday vs Weekend

    private var weekdayWeekendCard: some View {
        let wv = dna.weekendVsWeekdayAggression
        let maxVal = max(wv.weekday, wv.weekend, 1)

        return Card(title: "Weekday vs Weekend") {
            HStack(spacing: 20) {
                comparisonColumn(
                    label: "Weekdays",
                    icon: "briefcase.fill",
                    color: .blue,
                    value: wv.weekday,
                    maxValue: maxVal
                )
                Divider()
                comparisonColumn(
                    label: "Weekends",
                    icon: "figure.outdoor.cycle",
                    color: .orange,
                    value: wv.weekend,
                    maxValue: maxVal
                )
            }
            .padding(.vertical, 4)

            if wv.weekday > 0 && wv.weekend > 0 {
                let diff = abs(wv.weekday - wv.weekend)
                let pct  = Int((diff / max(wv.weekday, wv.weekend)) * 100)
                let moreAgg = wv.weekday > wv.weekend ? "weekdays" : "weekends"
                Text("You drive \(pct)% more aggressively on \(moreAgg).")
                    .font(.footnote).foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.top, 2)
            }
        }
    }

    private func comparisonColumn(label: String, icon: String,
                                   color: Color, value: Double, maxValue: Double) -> some View {
        VStack(spacing: 6) {
            Image(systemName: icon).font(.title2).foregroundStyle(color)
            Text(label).font(.caption.bold())
            Text(String(format: "%.1f", value))
                .font(.title3.bold()).foregroundStyle(color)
            Text("avg aggression").font(.caption2).foregroundStyle(.secondary)
            GeometryReader { geo in
                ZStack(alignment: .bottom) {
                    RoundedRectangle(cornerRadius: 4).fill(color.opacity(0.12)).frame(height: 40)
                    RoundedRectangle(cornerRadius: 4)
                        .fill(color)
                        .frame(height: maxValue > 0 ? 40 * CGFloat(value / maxValue) : 0)
                        .animation(.spring(duration: 0.7), value: value)
                }
            }
            .frame(height: 40)
        }
        .frame(maxWidth: .infinity)
    }

    // MARK: - AI Insights Card

    private var aiInsightsCard: some View {
        Card(title: "AI Insights") {
            if let insights {
                VStack(alignment: .leading, spacing: 14) {
                    // Headline
                    Text("\"\(insights.headline)\"")
                        .font(.headline)
                        .italic()
                        .foregroundStyle(.primary)
                        .padding(12)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(dna.fingerprintColor.opacity(0.1))
                        .clipShape(RoundedRectangle(cornerRadius: 10))

                    insightRow(icon: "chart.bar.fill",      color: .blue,
                               label: "Top Pattern",        text: insights.topPattern)
                    insightRow(icon: "clock.fill",           color: .purple,
                               label: "Time of Day",        text: insights.timeInsight)
                    insightRow(icon: "calendar",             color: .orange,
                               label: "Day of Week",        text: insights.dayInsight)
                    insightRow(icon: "checkmark.seal.fill",  color: .green,
                               label: "Your Strength",      text: insights.strengthNote)
                    insightRow(icon: "arrow.up.circle.fill", color: .red,
                               label: "Top Improvement",    text: insights.improvementTip)
                }
            } else {
                if let aiError {
                    Text("⚠️ \(aiError)").font(.footnote).foregroundStyle(.red)
                }
                Text("Generate a personalized AI analysis of your driving fingerprint.")
                    .font(.footnote).foregroundStyle(.secondary)

                Button {
                    Task { await generateInsights() }
                } label: {
                    Text(isLoadingAI ? "Analyzing your DNA…" : "Generate AI Insights")
                        .frame(maxWidth: .infinity).padding()
                }
                .buttonStyle(.borderedProminent)
                .disabled(isLoadingAI)
            }

            if insights != nil {
                Button {
                    withAnimation { insights = nil }
                } label: {
                    Text("Regenerate").font(.footnote)
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)
            }
        }
    }

    private func insightRow(icon: String, color: Color, label: String, text: String) -> some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: icon).foregroundStyle(color).frame(width: 22)
            VStack(alignment: .leading, spacing: 2) {
                Text(label).font(.caption.bold()).foregroundStyle(color)
                Text(text).font(.footnote).foregroundStyle(.secondary)
            }
        }
    }

    private var needMoreDataCard: some View {
        Card(title: "Building Your Fingerprint") {
            HStack(spacing: 12) {
                Image(systemName: "dna").font(.largeTitle).foregroundStyle(.secondary)
                VStack(alignment: .leading, spacing: 4) {
                    Text("Need \(3 - tripHistory.trips.count) more saved trip\(3 - tripHistory.trips.count == 1 ? "" : "s")")
                        .font(.subheadline.bold())
                    Text("Drive DNA needs at least 3 saved trips to detect patterns.")
                        .font(.caption).foregroundStyle(.secondary)
                }
            }
        }
    }

    // MARK: - AI Call

    private func generateInsights() async {
        isLoadingAI = true; aiError = nil
        do {
            let key    = Bundle.main.object(forInfoDictionaryKey: "OPENAI_API_KEY") as? String ?? ""
            let client = OpenAIClient(apiKey: key)
            insights   = try await client.generateDriveDNA(
                dna: dna, vehicle: vehicleStore.profile)
        } catch { aiError = error.localizedDescription }
        isLoadingAI = false
    }

    // MARK: - Helpers

    private func barColor(aggression: Double, maxValue: Double) -> Color {
        guard maxValue > 0 else { return .green }
        let ratio = aggression / maxValue
        return ratio > 0.75 ? .red : ratio > 0.45 ? .orange : .green
    }

    private func statRow(label: String, value: String) -> some View {
        HStack {
            Text(label).font(.caption).foregroundStyle(.secondary)
            Spacer()
            Text(value).font(.caption.bold())
        }
    }

    private func eventCell(icon: String, color: Color, value: String, label: String) -> some View {
        VStack(spacing: 4) {
            Image(systemName: icon).font(.title3).foregroundStyle(color)
            Text(value).font(.title3.bold()).foregroundStyle(color)
            Text(label).font(.caption2).foregroundStyle(.secondary).multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
    }
}

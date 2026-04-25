import SwiftUI

struct SafetyScoreView: View {

    @EnvironmentObject var tripHistory: TripHistoryStore

    // Pair each saved trip with its computed score
    private var scoredTrips: [(trip: TripResult, score: SafetyScore)] {
        tripHistory.trips.map { ($0, SafetyScore.compute(from: $0)) }
    }

    private var averageScore: Int? {
        guard !scoredTrips.isEmpty else { return nil }
        let total = scoredTrips.map { $0.score.score }.reduce(0, +)
        return total / scoredTrips.count
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 14) {
                overallScoreCard
                scoringRulesCard
                recentTripsCard
            }
            .padding()
        }
        .navigationTitle("Safety Score")
    }

    // MARK: - Overall Score Card

    private var overallScoreCard: some View {
        Card(title: "Overall Score") {
            if let avg = averageScore {
                HStack(spacing: 24) {
                    // Circular gauge
                    ZStack {
                        Circle()
                            .stroke(Color.gray.opacity(0.15), lineWidth: 14)
                        Circle()
                            .trim(from: 0, to: CGFloat(avg) / 100)
                            .stroke(
                                gradeColor(for: avg),
                                style: StrokeStyle(lineWidth: 14, lineCap: .round)
                            )
                            .rotationEffect(.degrees(-90))
                            .animation(.spring(duration: 0.8), value: avg)
                        VStack(spacing: 2) {
                            Text("\(avg)")
                                .font(.system(size: 38, weight: .bold, design: .rounded))
                                .foregroundStyle(gradeColor(for: avg))
                            Text("/ 100")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                    .frame(width: 110, height: 110)

                    VStack(alignment: .leading, spacing: 6) {
                        Text(gradeName(for: avg))
                            .font(.title2.bold())
                            .foregroundStyle(gradeColor(for: avg))
                        Text("Grade \(gradeLetter(for: avg))")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                        Divider()
                        Text(gradeMessage(for: avg))
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                            .fixedSize(horizontal: false, vertical: true)
                        Text("Based on \(scoredTrips.count) saved trip\(scoredTrips.count == 1 ? "" : "s")")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }

                    Spacer()
                }
                .padding(.vertical, 6)

            } else {
                VStack(spacing: 8) {
                    Image(systemName: "shield.slash")
                        .font(.largeTitle)
                        .foregroundStyle(.secondary)
                    Text("Save trips to start tracking your safety score.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 10)
            }
        }
    }

    // MARK: - Scoring Rules Card

    private var scoringRulesCard: some View {
        Card(title: "How Scoring Works") {
            Text("Each trip starts at 100. Points are deducted for risky behaviors:")
                .font(.footnote)
                .foregroundStyle(.secondary)

            VStack(spacing: 6) {
                RuleRow(icon: "exclamationmark.triangle.fill",
                        label: "Hard Brakes",
                        detail: "−8 pts each (max 3)",
                        color: .red)
                RuleRow(icon: "arrow.uturn.right.circle.fill",
                        label: "Sharp Turns",
                        detail: "−5 pts each (max 4)",
                        color: .orange)
                RuleRow(icon: "bolt.fill",
                        label: "Aggressive Accelerations",
                        detail: "−6 pts each (max 3)",
                        color: Color(red: 0.9, green: 0.7, blue: 0.0))
                RuleRow(icon: "speedometer",
                        label: "Avg Speed > 70 mph",
                        detail: "−10 pts",
                        color: .purple)
                RuleRow(icon: "gauge.with.dots.needle.67percent",
                        label: "Max Speed > 90 mph",
                        detail: "−10 pts",
                        color: .red)
            }
            .padding(.top, 2)

            Divider().padding(.vertical, 4)

            // Grade legend
            VStack(alignment: .leading, spacing: 4) {
                Text("Grades")
                    .font(.subheadline.bold())
                HStack(spacing: 6) {
                    ForEach([("A", 95), ("B", 85), ("C", 75), ("D", 65), ("F", 40)], id: \.0) { pair in
                        Text("\(pair.0)")
                            .font(.caption.bold())
                            .foregroundStyle(.white)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(gradeColor(for: pair.1))
                            .clipShape(RoundedRectangle(cornerRadius: 6))
                    }
                }
            }
        }
    }

    // MARK: - Recent Trips Card

    private var recentTripsCard: some View {
        Card(title: "Recent Trips") {
            if scoredTrips.isEmpty {
                Text("No saved trips yet.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            } else {
                let items = Array(scoredTrips.prefix(10))
                VStack(spacing: 0) {
                    ForEach(Array(items.enumerated()), id: \.element.trip.id) { idx, item in
                        TripScoreRow(trip: item.trip, score: item.score)
                        if idx < items.count - 1 {
                            Divider().padding(.vertical, 6)
                        }
                    }
                }
            }
        }
    }

    // MARK: - Grade Helpers

    private func gradeColor(for score: Int) -> Color {
        switch score {
        case 90...100: return .green
        case 80..<90:  return Color(red: 0.2, green: 0.5, blue: 1.0)
        case 70..<80:  return Color(red: 0.9, green: 0.7, blue: 0.0)
        case 60..<70:  return .orange
        default:       return .red
        }
    }

    private func gradeName(for score: Int) -> String {
        switch score {
        case 90...100: return "Excellent"
        case 80..<90:  return "Good"
        case 70..<80:  return "Fair"
        case 60..<70:  return "Poor"
        default:       return "Dangerous"
        }
    }

    private func gradeLetter(for score: Int) -> String {
        switch score {
        case 90...100: return "A"
        case 80..<90:  return "B"
        case 70..<80:  return "C"
        case 60..<70:  return "D"
        default:       return "F"
        }
    }

    private func gradeMessage(for score: Int) -> String {
        switch score {
        case 90...100: return "Outstanding driving habits."
        case 80..<90:  return "Great driving, minor issues."
        case 70..<80:  return "Some habits need improvement."
        case 60..<70:  return "Several risky behaviors detected."
        default:       return "Significant safety concerns."
        }
    }
}

// MARK: - Sub-views

private struct RuleRow: View {
    let icon: String
    let label: String
    let detail: String
    let color: Color

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: icon)
                .foregroundStyle(color)
                .frame(width: 22)
            Text(label)
                .font(.subheadline)
            Spacer()
            Text(detail)
                .font(.caption.bold())
                .foregroundStyle(color)
        }
    }
}

private struct TripScoreRow: View {
    let trip: TripResult
    let score: SafetyScore

    var body: some View {
        HStack(alignment: .center, spacing: 12) {
            // Score badge
            ZStack {
                Circle()
                    .fill(score.grade.color.opacity(0.15))
                Text(score.grade.letter)
                    .font(.system(size: 16, weight: .bold, design: .rounded))
                    .foregroundStyle(score.grade.color)
            }
            .frame(width: 38, height: 38)

            VStack(alignment: .leading, spacing: 2) {
                Text(trip.endedAt.formatted(date: .abbreviated, time: .shortened))
                    .font(.subheadline)

                if score.deductions.isEmpty {
                    Text("Clean drive — no deductions!")
                        .font(.caption)
                        .foregroundStyle(.green)
                } else {
                    Text(score.deductions.map { "−\($0.points) \($0.reason)" }.joined(separator: "  ·  "))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(2)
                }
            }

            Spacer()

            Text("\(score.score)")
                .font(.title3.bold())
                .foregroundStyle(score.grade.color)
        }
        .padding(.vertical, 2)
    }
}

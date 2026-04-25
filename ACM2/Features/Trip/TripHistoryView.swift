import SwiftUI

struct TripHistoryView: View {
    @EnvironmentObject var tripHistory: TripHistoryStore

    var body: some View {
        List {
            if tripHistory.trips.isEmpty {
                Text("No saved trips yet.")
                    .foregroundStyle(.secondary)
            }

            ForEach(tripHistory.trips) { trip in
                VStack(alignment: .leading, spacing: 6) {
                    Text(trip.endedAt.formatted(date: .abbreviated, time: .shortened))
                        .font(.headline)

                    Text("Duration: \(formatTime(trip.durationSeconds)) • MPG: \(String(format: "%.1f", trip.mpg))")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)

                    if let tip = trip.aiOverallTip, !tip.isEmpty {
                        Text(tip)
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                            .lineLimit(2)
                    }
                }
                .padding(.vertical, 6)
            }
            .onDelete(perform: tripHistory.delete)
        }
        .navigationTitle("Trip History")
        .toolbar { EditButton() }
    }

    private func formatTime(_ totalSeconds: Int) -> String {
        let minutes = totalSeconds / 60
        let seconds = totalSeconds % 60
        return String(format: "%02d:%02d", minutes, seconds)
    }
}


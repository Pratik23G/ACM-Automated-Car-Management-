import SwiftUI

/// Persistent banner shown at the top of TripHomeView when DriveDetector or
/// Bluetooth has a PendingAutoTrip waiting for user confirmation.
struct AutoTripConfirmationBanner: View {

    let pending:   PendingAutoTrip
    let onConfirm: () -> Void
    let onDiscard: () -> Void

    @State private var isExpanded = true

    var body: some View {
        VStack(spacing: 0) {
            // Header row
            Button { withAnimation(.spring(duration: 0.3)) { isExpanded.toggle() } } label: {
                HStack(spacing: 10) {
                    ZStack {
                        Circle().fill(Color.blue.opacity(0.15)).frame(width: 38, height: 38)
                        Image(systemName: "car.fill").foregroundStyle(.blue)
                    }
                    VStack(alignment: .leading, spacing: 2) {
                        Text("ACM Detected a Drive")
                            .font(.subheadline.bold())
                        Text(pending.sourceLabel)
                            .font(.caption).foregroundStyle(.secondary)
                    }
                    Spacer()
                    Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                        .font(.caption).foregroundStyle(.secondary)
                }
                .padding(.horizontal, 14).padding(.vertical, 10)
            }
            .buttonStyle(.plain)

            if isExpanded {
                Divider()

                // Trip stats
                HStack(spacing: 0) {
                    statCell(label: "Duration",
                             value: pending.durationFormatted)
                    Divider().frame(height: 36)
                    statCell(label: "Started",
                             value: pending.startedAt.formatted(date: .omitted, time: .shortened))
                    Divider().frame(height: 36)
                    statCell(label: "Ended",
                             value: pending.endedAt.formatted(date: .omitted, time: .shortened))
                }
                .padding(.vertical, 8)

                Divider()

                // Action buttons
                HStack(spacing: 0) {
                    Button(action: onDiscard) {
                        HStack(spacing: 6) {
                            Image(systemName: "xmark.circle")
                            Text("Discard")
                        }
                        .font(.subheadline.bold())
                        .foregroundStyle(.red)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                    }

                    Divider().frame(height: 44)

                    Button(action: onConfirm) {
                        HStack(spacing: 6) {
                            Image(systemName: "checkmark.circle.fill")
                            Text("Save Trip")
                        }
                        .font(.subheadline.bold())
                        .foregroundStyle(.green)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                    }
                }
            }
        }
        .background(.thinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(Color.blue.opacity(0.25), lineWidth: 1)
        )
        .shadow(color: .black.opacity(0.08), radius: 8, y: 3)
        .transition(.move(edge: .top).combined(with: .opacity))
    }

    private func statCell(label: String, value: String) -> some View {
        VStack(spacing: 2) {
            Text(value).font(.subheadline.bold())
            Text(label).font(.caption).foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
    }
}


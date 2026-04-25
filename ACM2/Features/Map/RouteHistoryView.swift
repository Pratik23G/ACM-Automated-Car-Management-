import SwiftUI
import MapKit

struct RouteHistoryView: View {

    @EnvironmentObject var routeStore:  RouteStore
    @EnvironmentObject var tripHistory: TripHistoryStore

    var body: some View {
        NavigationStack {
            Group {
                if routeStore.routes.filter({ $0.endedAt != nil }).isEmpty {
                    emptyState
                } else {
                    routeList
                }
            }
            .navigationTitle("Route History")
        }
    }

    // MARK: - Empty State

    private var emptyState: some View {
        VStack(spacing: 16) {
            Image(systemName: "map.fill")
                .font(.system(size: 60))
                .foregroundStyle(.secondary)
            Text("No Recorded Routes Yet")
                .font(.title3.bold())
            Text("Start a trip and tap the map to begin recording your route.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)
        }
    }

    // MARK: - Route List

    private var routeList: some View {
        List {
            // Stats banner
            Section {
                HStack(spacing: 0) {
                    statCell(label: "Routes",
                             value: "\(routeStore.routes.filter { $0.endedAt != nil }.count)")
                    Divider()
                    statCell(label: "Notes",
                             value: "\(routeStore.routes.flatMap { $0.notes }.count)")
                    Divider()
                    statCell(label: "Reminders",
                             value: "\(routeStore.allReminderNotes.count)")
                }
                .frame(height: 60)
            }

            Section("Your Trips") {
                ForEach(routeStore.routes.filter { $0.endedAt != nil }) { route in
                    NavigationLink(destination: TripRouteDetailView(route: route)) {
                        routeRow(route)
                    }
                }
                .onDelete { offsets in
                    for idx in offsets {
                        let id = routeStore.routes.filter { $0.endedAt != nil }[idx].id
                        routeStore.deleteRoute(id: id)
                    }
                }
            }

            // Reminder notes across all trips
            let reminders = routeStore.allReminderNotes
            if !reminders.isEmpty {
                Section("Active Reminders (\(reminders.count))") {
                    ForEach(reminders) { note in
                        reminderRow(note)
                    }
                }
            }
        }
        .toolbar { EditButton() }
    }

    // MARK: - Row Views

    private func routeRow(_ route: TripRoute) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text(route.startedAt.formatted(date: .abbreviated, time: .shortened))
                    .font(.headline)
                Spacer()
                if route.calculatedDistanceMiles > 0 {
                    Text(String(format: "%.1f mi", route.calculatedDistanceMiles))
                        .font(.subheadline.bold())
                        .foregroundStyle(.blue)
                }
            }

            HStack(spacing: 12) {
                noteCountBadge(count: route.notes.filter { $0.type == .hazard }.count,
                               icon: "exclamationmark.triangle.fill", color: .red)
                noteCountBadge(count: route.notes.filter { $0.type == .food }.count,
                               icon: "fork.knife", color: .orange)
                noteCountBadge(count: route.notes.filter { $0.isReminder }.count,
                               icon: "bell.fill", color: .purple)
                noteCountBadge(count: route.notes.filter { $0.type == .general || $0.type == .roadQuality }.count,
                               icon: "note.text", color: .blue)
            }

            if !route.notes.isEmpty {
                Text(route.notes.prefix(2).map { $0.title }.joined(separator: " · "))
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
        }
        .padding(.vertical, 4)
    }

    private func reminderRow(_ note: RouteNote) -> some View {
        HStack(spacing: 10) {
            Image(systemName: "bell.fill")
                .foregroundStyle(.purple)
                .frame(width: 24)
            VStack(alignment: .leading, spacing: 2) {
                Text(note.title).font(.subheadline)
                if let msg = note.reminderMessage, !msg.isEmpty {
                    Text(msg).font(.caption).foregroundStyle(.secondary).lineLimit(1)
                }
            }
        }
        .padding(.vertical, 2)
    }

    private func noteCountBadge(count: Int, icon: String, color: Color) -> some View {
        Group {
            if count > 0 {
                HStack(spacing: 3) {
                    Image(systemName: icon).font(.caption2)
                    Text("\(count)").font(.caption2.bold())
                }
                .foregroundStyle(color)
                .padding(.horizontal, 6)
                .padding(.vertical, 3)
                .background(color.opacity(0.12))
                .clipShape(Capsule())
            }
        }
    }

    private func statCell(label: String, value: String) -> some View {
        VStack(spacing: 2) {
            Text(value).font(.title3.bold())
            Text(label).font(.caption).foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
    }
}


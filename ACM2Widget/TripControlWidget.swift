import WidgetKit
import SwiftUI
import AppIntents

// MARK: - App Intents (iOS 17 interactive widgets)

struct StartTripIntent: AppIntent {
    static var title: LocalizedStringResource = "Start Trip"
    static var description = IntentDescription("Start an ACM trip")

    func perform() async throws -> some IntentResult {
        SharedDefaults.isTripActive   = true
        SharedDefaults.tripStartedAt  = Date()
        WidgetCenter.shared.reloadAllTimelines()
        return .result()
    }
}

struct StopTripIntent: AppIntent {
    static var title: LocalizedStringResource = "Stop Trip"
    static var description = IntentDescription("Stop the active ACM trip")

    func perform() async throws -> some IntentResult {
        SharedDefaults.isTripActive  = false
        SharedDefaults.tripStartedAt = nil
        WidgetCenter.shared.reloadAllTimelines()
        return .result()
    }
}

// MARK: - Timeline Entry

struct TripWidgetEntry: TimelineEntry {
    let date:         Date
    let isTripActive: Bool
    let startedAt:    Date?
    let vehicleName:  String

    var elapsedSeconds: Int {
        guard isTripActive, let start = startedAt else { return 0 }
        return max(0, Int(date.timeIntervalSince(start)))
    }

    var elapsedFormatted: String {
        let s = elapsedSeconds
        let h = s / 3600
        let m = (s % 3600) / 60
        let sec = s % 60
        if h > 0 { return String(format: "%d:%02d:%02d", h, m, sec) }
        return String(format: "%02d:%02d", m, sec)
    }
}

// MARK: - Provider

struct TripWidgetProvider: TimelineProvider {

    func placeholder(in context: Context) -> TripWidgetEntry {
        TripWidgetEntry(date: Date(), isTripActive: false,
                        startedAt: nil, vehicleName: "My Vehicle")
    }

    func getSnapshot(in context: Context, completion: @escaping (TripWidgetEntry) -> Void) {
        completion(currentEntry())
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<TripWidgetEntry>) -> Void) {
        let entry = currentEntry()
        // Text(.timer) handles live second-by-second updates automatically.
        // We only need to refresh the timeline when trip state changes.
        // Refresh every 5 minutes to stay in sync, or immediately when trip ends.
        let refreshDate = Date().addingTimeInterval(entry.isTripActive ? 300 : 3600)
        completion(Timeline(entries: [entry], policy: .after(refreshDate)))
    }

    private func currentEntry() -> TripWidgetEntry {
        TripWidgetEntry(
            date:         Date(),
            isTripActive: SharedDefaults.isTripActive,
            startedAt:    SharedDefaults.tripStartedAt,
            vehicleName:  SharedDefaults.vehicleDisplayName
        )
    }
}

// MARK: - Widget Views

struct TripWidgetSmallView: View {
    let entry: TripWidgetEntry

    var body: some View {
        ZStack {
            ContainerRelativeShape()
                .fill(entry.isTripActive
                      ? Color(red: 0.05, green: 0.12, blue: 0.25)
                      : Color(red: 0.08, green: 0.08, blue: 0.10))

            VStack(spacing: 10) {
                ZStack {
                    Circle()
                        .fill(entry.isTripActive ? Color.green.opacity(0.2) : Color.blue.opacity(0.15))
                        .frame(width: 44, height: 44)
                    Image(systemName: entry.isTripActive ? "stop.circle.fill" : "play.circle.fill")
                        .font(.system(size: 26))
                        .foregroundStyle(entry.isTripActive ? .green : .blue)
                }

                if entry.isTripActive, let start = entry.startedAt {
                    // Text(.timer) updates every second automatically — no timeline refresh needed
                    Text(start, style: .timer)
                        .font(.system(size: 16, weight: .bold, design: .monospaced))
                        .foregroundStyle(.green)
                    Text("TRIP ACTIVE").font(.system(size: 9)).foregroundStyle(.green.opacity(0.8))
                } else {
                    Text("START").font(.system(size: 13, weight: .bold)).foregroundStyle(.white)
                    Text("TRIP").font(.system(size: 10)).foregroundStyle(.white.opacity(0.6))
                }
            }
        }
        .widgetURL(URL(string: entry.isTripActive ? "acm2://stoptrip" : "acm2://starttrip"))
    }
}

struct TripWidgetMediumView: View {
    let entry: TripWidgetEntry

    var body: some View {
        ZStack {
            ContainerRelativeShape()
                .fill(entry.isTripActive
                      ? Color(red: 0.05, green: 0.12, blue: 0.22)
                      : Color(red: 0.07, green: 0.07, blue: 0.10))

            HStack(spacing: 16) {
                VStack(alignment: .leading, spacing: 6) {
                    HStack(spacing: 6) {
                        Image(systemName: "car.fill").foregroundStyle(.blue).font(.caption)
                        Text(entry.vehicleName)
                            .font(.caption.bold()).foregroundStyle(.white.opacity(0.8))
                            .lineLimit(1)
                    }

                    if entry.isTripActive, let start = entry.startedAt {
                        // Live self-updating timer — no per-second timeline entries needed
                        Text(start, style: .timer)
                            .font(.system(size: 28, weight: .black, design: .monospaced))
                            .foregroundStyle(.green)
                        HStack(spacing: 4) {
                            Circle().fill(.green).frame(width: 6, height: 6)
                            Text("TRIP ACTIVE").font(.system(size: 9)).foregroundStyle(.green.opacity(0.8))
                        }
                    } else {
                        Text("Ready to Drive").font(.title3.bold()).foregroundStyle(.white)
                        Text("Tap to start tracking")
                            .font(.caption).foregroundStyle(.white.opacity(0.5))
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)

                // Right: action button — two separate buttons avoids Swift type-inference error
                if entry.isTripActive {
                    Button(intent: StopTripIntent()) {
                        ZStack {
                            RoundedRectangle(cornerRadius: 14, style: .continuous)
                                .fill(Color.red.opacity(0.85))
                                .frame(width: 70, height: 60)
                            VStack(spacing: 4) {
                                Image(systemName: "stop.fill").font(.title3).foregroundStyle(.white)
                                Text("Stop").font(.caption.bold()).foregroundStyle(.white)
                            }
                        }
                    }
                    .buttonStyle(.plain)
                } else {
                    Button(intent: StartTripIntent()) {
                        ZStack {
                            RoundedRectangle(cornerRadius: 14, style: .continuous)
                                .fill(Color.blue)
                                .frame(width: 70, height: 60)
                            VStack(spacing: 4) {
                                Image(systemName: "play.fill").font(.title3).foregroundStyle(.white)
                                Text("Start").font(.caption.bold()).foregroundStyle(.white)
                            }
                        }
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 16)
        }
    }
}

// MARK: - Widget

struct TripControlWidget: Widget {
    let kind = "TripControlWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: TripWidgetProvider()) { entry in
            Group {
                if #available(iOSApplicationExtension 17.0, *) {
                    TripWidgetMediumView(entry: entry)
                        .containerBackground(for: .widget) {
                            Color(red: 0.07, green: 0.07, blue: 0.10)
                        }
                } else {
                    TripWidgetSmallView(entry: entry)
                }
            }
        }
        .configurationDisplayName("ACM Trip Control")
        .description("Start and stop trip tracking directly from your home screen.")
        .supportedFamilies([.systemSmall, .systemMedium])
    }
}

import SwiftUI
import WeatherKit
import CoreLocation

struct SmartPlaceBriefView: View {

    let place: SavedPlace

    @EnvironmentObject var tripHistory:  TripHistoryStore
    @EnvironmentObject var placesStore:  SavedPlacesStore

    @State private var weather:      CurrentWeather?
    @State private var weatherError: String?
    @State private var isLoadingAI   = false
    @State private var aiBrief:      String?
    @State private var aiError:      String?
    @State private var showAddReminder = false
    @State private var newReminderTitle = ""
    @State private var newReminderBody  = ""

    private var pattern: TripPattern? {
        place.pattern(from: tripHistory.trips)
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                placeHeaderCard
                if let p = pattern {
                    patternCard(p)
                    aggressionCard(p)
                } else {
                    noDataCard
                }
                weatherCard
                remindersCard
                aiBriefCard
            }
            .padding()
        }
        .navigationTitle(place.displayName)
        .navigationBarTitleDisplayMode(.large)
        .task { await loadWeather() }
        .sheet(isPresented: $showAddReminder) {
            addReminderSheet
        }
    }

    // MARK: - Header

    private var placeHeaderCard: some View {
        Card(title: "") {
            HStack(spacing: 16) {
                ZStack {
                    Circle()
                        .fill(place.category.color.opacity(0.15))
                        .frame(width: 64, height: 64)
                    Image(systemName: place.category.icon)
                        .font(.title).foregroundStyle(place.category.color)
                }
                VStack(alignment: .leading, spacing: 4) {
                    Text(place.displayName).font(.title2.bold())
                    Text(place.category.label).font(.subheadline).foregroundStyle(.secondary)
                    if let visited = place.lastVisited {
                        Text("Last visited \(visited.formatted(date: .abbreviated, time: .omitted))")
                            .font(.caption).foregroundStyle(.secondary)
                    }
                }
                Spacer()
                VStack(spacing: 2) {
                    Text("\(place.tripCount)").font(.title.bold()).foregroundStyle(place.category.color)
                    Text("trips").font(.caption).foregroundStyle(.secondary)
                }
            }
        }
    }

    // MARK: - Pattern Card

    private func patternCard(_ p: TripPattern) -> some View {
        Card(title: "Your Pattern to \(place.displayName)") {
            HStack(spacing: 0) {
                patternStat(label: "Avg Duration",
                            value: p.avgDurationFormatted,
                            icon: "clock.fill", color: .blue)
                Divider().frame(height: 50)
                patternStat(label: "Avg Distance",
                            value: String(format: "%.1f mi", p.avgDistanceMiles),
                            icon: "arrow.triangle.swap", color: .purple)
                Divider().frame(height: 50)
                patternStat(label: "Avg Fuel Cost",
                            value: String(format: "$%.2f", p.avgFuelCost),
                            icon: "fuelpump.fill", color: .orange)
            }

            if let hour = p.busiestHourFormatted, let day = p.busiestDay {
                Divider().padding(.vertical, 6)
                HStack(spacing: 6) {
                    Image(systemName: "clock.badge.checkmark.fill").foregroundStyle(.green)
                    Text("You usually go on **\(day)s around \(hour)**")
                        .font(.subheadline)
                }
            }
        }
    }

    // MARK: - Aggression Card

    private func aggressionCard(_ p: TripPattern) -> some View {
        let level: String
        let color: Color
        let tip: String

        switch p.avgAggression {
        case 0..<2:
            level = "Smooth"
            color = .green
            tip   = "You drive very smoothly on this route — keep it up."
        case 2..<5:
            level = "Moderate"
            color = .blue
            tip   = "A few hard brakes or sharp turns on this route. Watch your following distance."
        case 5..<10:
            level = "Aggressive"
            color = .orange
            tip   = "This route tends to bring out aggressive habits. Try leaving a few minutes earlier."
        default:
            level = "Very Aggressive"
            color = .red
            tip   = "Your hardest driving happens on this route. Consider the cost to your brakes and tires."
        }

        return Card(title: "Driving Behavior on This Route") {
            HStack(spacing: 14) {
                ZStack {
                    Circle().fill(color.opacity(0.12)).frame(width: 52, height: 52)
                    Image(systemName: "gauge.with.needle.fill")
                        .font(.title2).foregroundStyle(color)
                }
                VStack(alignment: .leading, spacing: 4) {
                    Text(level).font(.headline).foregroundStyle(color)
                    Text(tip).font(.footnote).foregroundStyle(.secondary)
                }
            }
        }
    }

    // MARK: - No Data Card

    private var noDataCard: some View {
        Card(title: "No Pattern Yet") {
            HStack(spacing: 12) {
                Image(systemName: "chart.line.uptrend.xyaxis")
                    .font(.title2).foregroundStyle(.secondary)
                VStack(alignment: .leading, spacing: 4) {
                    Text("Save a few trips here to unlock patterns")
                        .font(.subheadline.bold())
                    Text("After 3+ trips ACM will show your avg duration, cost, and driving behavior on this route.")
                        .font(.caption).foregroundStyle(.secondary)
                }
            }
        }
    }

    // MARK: - Weather Card

    private var weatherCard: some View {
        Card(title: "Current Conditions") {
            if let w = weather {
                HStack(spacing: 16) {
                    VStack(spacing: 4) {
                        Image(systemName: w.symbolName)
                            .font(.system(size: 40))
                            .foregroundStyle(weatherColor(w))
                        Text(w.condition.description)
                            .font(.caption).foregroundStyle(.secondary)
                            .multilineTextAlignment(.center)
                    }
                    .frame(width: 80)

                    VStack(alignment: .leading, spacing: 6) {
                        weatherRow(icon: "thermometer.medium",
                                   label: "Temperature",
                                   value: String(format: "%.0f°F", w.temperature.converted(to: .fahrenheit).value))
                        weatherRow(icon: "humidity.fill",
                                   label: "Humidity",
                                   value: String(format: "%.0f%%", w.humidity * 100))
                        weatherRow(icon: "wind",
                                   label: "Wind",
                                   value: String(format: "%.0f mph", w.wind.speed.converted(to: .milesPerHour).value))
                        weatherRow(icon: "eye.fill",
                                   label: "Visibility",
                                   value: String(format: "%.1f mi", w.visibility.converted(to: .miles).value))
                    }
                }

                if let alert = drivingWeatherAlert(w) {
                    Divider().padding(.vertical, 6)
                    HStack(spacing: 8) {
                        Image(systemName: "exclamationmark.triangle.fill").foregroundStyle(.orange)
                        Text(alert).font(.footnote).foregroundStyle(.secondary)
                    }
                }
            } else if let err = weatherError {
                HStack {
                    Image(systemName: "cloud.slash").foregroundStyle(.secondary)
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Weather unavailable").font(.subheadline)
                        Text(err).font(.caption).foregroundStyle(.secondary)
                    }
                }
            } else {
                HStack {
                    ProgressView().padding(.trailing, 4)
                    Text("Loading weather…").font(.subheadline).foregroundStyle(.secondary)
                }
            }
        }
    }

    // MARK: - Reminders Card

    private var remindersCard: some View {
        Card(title: "Reminders for This Place") {
            if place.reminders.isEmpty {
                HStack(spacing: 10) {
                    Image(systemName: "bell.slash").foregroundStyle(.secondary)
                    Text("No reminders yet. Add notes like traffic times, parking tips, or anything to remember.")
                        .font(.caption).foregroundStyle(.secondary)
                }
            } else {
                ForEach(place.reminders) { reminder in
                    HStack(alignment: .top, spacing: 10) {
                        Image(systemName: reminder.isActive ? "bell.fill" : "bell.slash")
                            .foregroundStyle(reminder.isActive ? .blue : .secondary)
                            .frame(width: 18)
                        VStack(alignment: .leading, spacing: 2) {
                            Text(reminder.title).font(.subheadline.bold())
                            if !reminder.body.isEmpty {
                                Text(reminder.body).font(.caption).foregroundStyle(.secondary)
                            }
                        }
                        Spacer()
                        Button {
                            placesStore.toggleReminder(reminderId: reminder.id, inPlace: place.id)
                        } label: {
                            Text(reminder.isActive ? "On" : "Off")
                                .font(.caption.bold())
                                .foregroundStyle(reminder.isActive ? .blue : .secondary)
                        }
                    }
                    .padding(.vertical, 2)
                    Divider()
                }
            }

            Button {
                showAddReminder = true
            } label: {
                Label("Add Reminder", systemImage: "plus.circle.fill")
                    .font(.subheadline).foregroundStyle(.blue)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            .padding(.top, 4)
        }
    }

    // MARK: - AI Brief Card

    private var aiBriefCard: some View {
        Card(title: "AI Trip Brief") {
            if let brief = aiBrief {
                Text(brief)
                    .font(.subheadline).foregroundStyle(.secondary)
                    .padding(12)
                    .background(place.category.color.opacity(0.06))
                    .clipShape(RoundedRectangle(cornerRadius: 10))

                Button {
                    withAnimation { aiBrief = nil }
                } label: {
                    Text("Refresh").font(.footnote)
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered).padding(.top, 4)

            } else {
                if let err = aiError {
                    Text("⚠️ \(err)").font(.caption).foregroundStyle(.red)
                }
                Text("Get a personalized AI briefing based on your trip history, current weather, and reminders for this place.")
                    .font(.footnote).foregroundStyle(.secondary)

                Button {
                    Task { await generateBrief() }
                } label: {
                    HStack {
                        Image(systemName: "brain.head.profile")
                        Text(isLoadingAI ? "Generating…" : "Brief Me for \(place.displayName)")
                    }
                    .frame(maxWidth: .infinity).padding()
                }
                .buttonStyle(.borderedProminent)
                .disabled(isLoadingAI)
            }
        }
    }

    // MARK: - Add Reminder Sheet

    private var addReminderSheet: some View {
        NavigationStack {
            Form {
                Section("Reminder Title") {
                    TextField("e.g. Heavy traffic after 5pm", text: $newReminderTitle)
                }
                Section("Notes (optional)") {
                    TextField("e.g. Take Oak Ave instead of Main St", text: $newReminderBody, axis: .vertical)
                        .lineLimit(3...5)
                }
            }
            .navigationTitle("Add Reminder")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Cancel") { showAddReminder = false }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Save") {
                        let title = newReminderTitle.trimmingCharacters(in: .whitespacesAndNewlines)
                        guard !title.isEmpty else { return }
                        let reminder = PlaceReminder(title: title, body: newReminderBody)
                        placesStore.addReminder(reminder, toPlace: place.id)
                        newReminderTitle = ""
                        newReminderBody  = ""
                        showAddReminder  = false
                    }
                    .disabled(newReminderTitle.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                    .font(.headline)
                }
            }
        }
        .presentationDetents([.medium])
    }

    // MARK: - Weather Loading

    private func loadWeather() async {
        // Use a generic city-center coordinate since we don't store place coordinates yet.
        // When GPS is available from trip history, use the last known position.
        // For now use device location via CoreLocation.
        do {
            let service = WeatherService.shared
            // San Francisco as fallback — in production, use CLLocationManager.location
            let location = CLLocation(latitude: 37.7749, longitude: -122.4194)
            let w = try await service.weather(for: location)
            await MainActor.run { weather = w.currentWeather }
        } catch {
            await MainActor.run {
                weatherError = "Enable WeatherKit in Xcode Signing & Capabilities."
            }
        }
    }

    // MARK: - AI Brief

    private func generateBrief() async {
        isLoadingAI = true; aiError = nil
        let p = pattern
        let reminderTitles = place.reminders.filter { $0.isActive }.map { $0.title }.joined(separator: ", ")
        let weatherDesc = weather.map {
            "Currently \($0.condition.description), \(String(format: "%.0f°F", $0.temperature.converted(to: .fahrenheit).value))"
        } ?? "Weather unavailable"

        var prompt = "Generate a short pre-trip briefing (2-3 sentences max) for someone heading to \(place.displayName) (\(place.category.label))."
        if let p {
            prompt += " Their avg trip takes \(p.avgDurationFormatted), costs $\(String(format: "%.2f", p.avgFuelCost)) in fuel, and they usually go on \(p.busiestDay ?? "weekdays") around \(p.busiestHourFormatted ?? "morning")."
            prompt += " Their driving style on this route is \(p.avgAggression < 3 ? "smooth" : p.avgAggression < 7 ? "moderate" : "aggressive")."
        }
        if !reminderTitles.isEmpty { prompt += " Active reminders: \(reminderTitles)." }
        prompt += " Weather: \(weatherDesc). Be direct and specific. No fluff."

        do {
            let key = Bundle.main.object(forInfoDictionaryKey: "OPENAI_API_KEY") as? String ?? ""
            aiBrief = try await OpenAIClient(apiKey: key).generatePlaceBrief(prompt: prompt)
        } catch {
            aiError = error.localizedDescription
        }
        isLoadingAI = false
    }

    // MARK: - Helpers

    private func weatherColor(_ w: CurrentWeather) -> Color {
        switch w.condition {
        case .rain, .drizzle, .heavyRain: return .blue
        case .snow, .sleet, .blizzard:    return .cyan
        case .thunderstorms:              return .purple
        case .clear:                      return .yellow
        default:                          return .gray
        }
    }

    private func drivingWeatherAlert(_ w: CurrentWeather) -> String? {
        let temp = w.temperature.converted(to: .fahrenheit).value
        let wind = w.wind.speed.converted(to: .milesPerHour).value
        switch w.condition {
        case .rain, .drizzle, .heavyRain:
            return "Wet roads — increase following distance and brake earlier."
        case .snow, .sleet, .blizzard:
            return "Snow or ice possible — allow extra time and drive cautiously."
        case .thunderstorms:
            return "Thunderstorms — consider delaying your trip if possible."
        default:
            if wind > 35 { return "High winds (\(Int(wind)) mph) — watch for debris and keep both hands on the wheel." }
            if temp < 32 { return "Freezing temperatures — watch for black ice, especially on bridges." }
            return nil
        }
    }

    private func weatherRow(icon: String, label: String, value: String) -> some View {
        HStack(spacing: 6) {
            Image(systemName: icon).font(.caption).foregroundStyle(.secondary).frame(width: 16)
            Text(label).font(.caption).foregroundStyle(.secondary)
            Spacer()
            Text(value).font(.caption.bold())
        }
    }

    private func patternStat(label: String, value: String, icon: String, color: Color) -> some View {
        VStack(spacing: 4) {
            Image(systemName: icon).foregroundStyle(color)
            Text(value).font(.subheadline.bold()).foregroundStyle(color)
            Text(label).font(.caption2).foregroundStyle(.secondary).multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
    }
}

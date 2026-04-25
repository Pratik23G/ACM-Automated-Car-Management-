import SwiftUI

struct PreTripView: View {

    @EnvironmentObject var tripHistory:  TripHistoryStore
    @EnvironmentObject var vehicleStore: VehicleProfileStore
    @EnvironmentObject var routeStore:   RouteStore

    @State private var destination:   String = ""
    @State private var brief:         PreTripBrief?
    @State private var isLoading      = false
    @State private var aiError:       String?

    // Current time slot label
    private var currentTimeSlot: String {
        let hour = Calendar.current.component(.hour, from: Date())
        return DriveDNA.TimeSlot.classify(hour: hour).rawValue
    }

    // All reminder + hazard notes from past routes
    private var relevantNotes: [RouteNote] {
        routeStore.routes.flatMap { $0.notes }
            .filter { $0.type == .hazard || $0.type == .reminder }
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                headerCard
                if let brief {
                    briefCards(brief)
                    regenerateButton
                } else {
                    inputCard
                }
            }
            .padding()
        }
        .navigationTitle("Pre-Trip Intel")
        .navigationBarTitleDisplayMode(.large)
    }

    // MARK: - Header

    private var headerCard: some View {
        Card(title: "Your Co-Pilot") {
            HStack(spacing: 14) {
                ZStack {
                    Circle().fill(Color.blue.opacity(0.12)).frame(width: 54, height: 54)
                    Image(systemName: "brain.head.profile").font(.title2).foregroundStyle(.blue)
                }
                VStack(alignment: .leading, spacing: 3) {
                    Text("Good \(timeGreeting()), \(currentTimeSlot.lowercased()) driver.")
                        .font(.subheadline.bold())
                    Text("Tell me where you're going and I'll brief you before you leave.")
                        .font(.caption).foregroundStyle(.secondary)
                }
                Spacer()
            }
        }
    }

    // MARK: - Input Card

    private var inputCard: some View {
        Card(title: "Where Are You Heading?") {
            TextField("e.g. Santa Cruz via Hwy 17, Work, Airport…",
                      text: $destination, axis: .vertical)
                .textFieldStyle(.roundedBorder)
                .lineLimit(2...3)

            // Context preview
            VStack(alignment: .leading, spacing: 6) {
                Text("I'll check:")
                    .font(.caption.bold()).foregroundStyle(.secondary)
                contextItem(icon: "clock", text: "Your \(currentTimeSlot.lowercased()) driving habits")
                contextItem(icon: "exclamationmark.triangle", text: "\(relevantNotes.count) saved hazard & reminder note\(relevantNotes.count == 1 ? "" : "s")")
                contextItem(icon: "car", text: "\(tripHistory.trips.count) past trips for patterns")
                if let v = vehicleStore.profile {
                    contextItem(icon: "fuelpump", text: "\(v.displayName) fuel estimate")
                }
            }
            .padding(.top, 4)

            if let aiError {
                Text("⚠️ \(aiError)").font(.footnote).foregroundStyle(.red)
            }

            Button { Task { await generateBrief() } } label: {
                HStack(spacing: 8) {
                    Image(systemName: "brain.head.profile")
                    Text(isLoading ? "Analyzing…" : "Brief Me")
                        .font(.headline)
                }
                .frame(maxWidth: .infinity).padding(.vertical, 14)
                .background(destination.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || isLoading
                            ? Color.gray : Color.blue)
                .foregroundStyle(.white)
                .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
            }
            .disabled(destination.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || isLoading)
        }
    }

    // MARK: - Brief Cards

    @ViewBuilder
    private func briefCards(_ brief: PreTripBrief) -> some View {

        // Summary banner
        Card(title: "Trip Brief: \(destination)") {
            Text(brief.summary)
                .font(.subheadline)
                .padding(12)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Color.blue.opacity(0.08))
                .clipShape(RoundedRectangle(cornerRadius: 10))
        }

        // Behavior warning
        if !brief.behaviorWarning.isEmpty {
            Card(title: "⚠️ Your Driving Habit Alert") {
                HStack(alignment: .top, spacing: 10) {
                    Image(systemName: "person.fill.viewfinder").font(.title2).foregroundStyle(.orange)
                    Text(brief.behaviorWarning).font(.subheadline).foregroundStyle(.secondary)
                }
            }
        }

        // Known hazards
        if !brief.knownHazards.isEmpty {
            Card(title: "Known Hazards on Route") {
                VStack(alignment: .leading, spacing: 8) {
                    ForEach(Array(brief.knownHazards.enumerated()), id: \.offset) { _, hazard in
                        HStack(alignment: .top, spacing: 8) {
                            Image(systemName: "exclamationmark.triangle.fill")
                                .foregroundStyle(.red).font(.caption)
                                .padding(.top, 2)
                            Text(hazard).font(.subheadline)
                        }
                    }
                }
            }
        }

        // Fuel estimate
        Card(title: "💰 Estimated Trip Cost") {
            HStack(spacing: 14) {
                Image(systemName: "fuelpump.fill").font(.title2).foregroundStyle(.orange)
                Text(brief.fuelEstimate).font(.subheadline).foregroundStyle(.secondary)
            }
        }

        // Tip
        Card(title: "Today's Tip") {
            HStack(alignment: .top, spacing: 10) {
                Image(systemName: "lightbulb.fill").font(.title2).foregroundStyle(.yellow)
                Text(brief.tip).font(.subheadline).foregroundStyle(.secondary)
            }
        }
    }

    private var regenerateButton: some View {
        Button {
            withAnimation { brief = nil }
        } label: {
            Label("New Destination", systemImage: "arrow.uturn.left")
                .frame(maxWidth: .infinity).padding()
        }
        .buttonStyle(.bordered)
    }

    // MARK: - AI Call

    private func generateBrief() async {
        isLoading = true; aiError = nil
        let dna = DriveDNA(trips: tripHistory.trips)
        do {
            let key    = Bundle.main.object(forInfoDictionaryKey: "OPENAI_API_KEY") as? String ?? ""
            let client = OpenAIClient(apiKey: key)
            brief = try await client.generatePreTripBrief(
                destination:   destination,
                timeSlot:      currentTimeSlot,
                dna:           dna,
                routeNotes:    relevantNotes,
                vehicle:       vehicleStore.profile
            )
        } catch { aiError = error.localizedDescription }
        isLoading = false
    }

    // MARK: - Helpers

    private func timeGreeting() -> String {
        let h = Calendar.current.component(.hour, from: Date())
        switch h {
        case 5..<12:  return "morning"
        case 12..<17: return "afternoon"
        case 17..<21: return "evening"
        default:      return "night"
        }
    }

    private func contextItem(icon: String, text: String) -> some View {
        HStack(spacing: 6) {
            Image(systemName: icon).font(.caption).foregroundStyle(.secondary).frame(width: 16)
            Text(text).font(.caption).foregroundStyle(.secondary)
        }
    }
}


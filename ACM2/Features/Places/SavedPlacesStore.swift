import Foundation
import Combine

@MainActor
final class SavedPlacesStore: ObservableObject {

    @Published private(set) var places: [SavedPlace] = []

    private let fileURL: URL = {
        let docs = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
        return docs.appendingPathComponent("saved_places.json")
    }()

    init() {
        load()
        // Seed default places if none exist
        if places.isEmpty { seedDefaults() }
    }

    // MARK: - Public API

    func add(_ place: SavedPlace) {
        places.append(place)
        save()
    }

    func update(_ place: SavedPlace) {
        guard let idx = places.firstIndex(where: { $0.id == place.id }) else { return }
        places[idx] = place
        save()
    }

    func delete(id: UUID) {
        places.removeAll { $0.id == id }
        save()
    }

    /// Associate a TripResult with a place.
    func assignTrip(tripId: UUID, toPlace placeId: UUID) {
        guard let idx = places.firstIndex(where: { $0.id == placeId }) else { return }
        if !places[idx].tripIds.contains(tripId) {
            places[idx].tripIds.append(tripId)
            places[idx].lastVisited = Date()
        }
        save()
    }

    func removeTrip(tripId: UUID, fromPlace placeId: UUID) {
        guard let idx = places.firstIndex(where: { $0.id == placeId }) else { return }
        places[idx].tripIds.removeAll { $0 == tripId }
        save()
    }

    func addReminder(_ reminder: PlaceReminder, toPlace placeId: UUID) {
        guard let idx = places.firstIndex(where: { $0.id == placeId }) else { return }
        places[idx].reminders.append(reminder)
        save()
    }

    func deleteReminder(reminderId: UUID, fromPlace placeId: UUID) {
        guard let idx = places.firstIndex(where: { $0.id == placeId }) else { return }
        places[idx].reminders.removeAll { $0.id == reminderId }
        save()
    }

    func toggleReminder(reminderId: UUID, inPlace placeId: UUID) {
        guard let pIdx = places.firstIndex(where: { $0.id == placeId }),
              let rIdx = places[pIdx].reminders.firstIndex(where: { $0.id == reminderId })
        else { return }
        places[pIdx].reminders[rIdx].isActive.toggle()
        save()
    }

    /// Which place does this trip belong to (if any)?
    func place(forTrip tripId: UUID) -> SavedPlace? {
        places.first { $0.tripIds.contains(tripId) }
    }

    // MARK: - Seed defaults

    private func seedDefaults() {
        let defaults: [(String, PlaceCategory)] = [
            ("Home", .home),
            ("Work", .work),
            ("School", .school)
        ]
        for (name, category) in defaults {
            var place = SavedPlace(name: name, category: category)
            place.customLabel = name
            places.append(place)
        }
        save()
    }

    // MARK: - Persistence

    private func save() {
        do {
            let encoder = JSONEncoder()
            encoder.outputFormatting = .prettyPrinted
            encoder.dateEncodingStrategy = .iso8601
            try encoder.encode(places).write(to: fileURL, options: .atomic)
        } catch {
            print("❌ SavedPlacesStore save error:", error)
        }
    }

    private func load() {
        guard FileManager.default.fileExists(atPath: fileURL.path) else { return }
        do {
            let decoder = JSONDecoder()
            decoder.dateDecodingStrategy = .iso8601
            places = try decoder.decode([SavedPlace].self, from: Data(contentsOf: fileURL))
        } catch {
            print("❌ SavedPlacesStore load error:", error)
        }
    }
}

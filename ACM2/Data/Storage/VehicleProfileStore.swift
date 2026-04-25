import Foundation
import Combine

@MainActor
final class VehicleProfileStore: ObservableObject {

    @Published private(set) var profiles:       [VehicleProfile] = []
    @Published private(set) var activeProfileId: UUID?

    // MARK: - Computed (backward-compat shims used throughout the rest of the app)

    var profile:    VehicleProfile? { profiles.first { $0.id == activeProfileId } }
    var hasProfile: Bool { !profiles.isEmpty }

    // MARK: - Persistence URLs

    private let profilesURL: URL = {
        let docs = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
        return docs.appendingPathComponent("vehicle_profiles.json")
    }()
    private let activeURL: URL = {
        let docs = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
        return docs.appendingPathComponent("active_vehicle.json")
    }()

    // MARK: - Init

    init() { load() }

    // MARK: - Public API

    /// Add a brand-new profile and make it active.
    func add(_ p: VehicleProfile) {
        profiles.append(p)
        if activeProfileId == nil { activeProfileId = p.id }
        persist()
    }

    /// Update an existing profile in-place.
    func update(_ p: VehicleProfile) {
        guard let idx = profiles.firstIndex(where: { $0.id == p.id }) else { return }
        profiles[idx] = p
        persist()
    }

    /// Convenience: add-or-update (used by VehicleSetupView).
    func save(_ p: VehicleProfile) {
        if profiles.contains(where: { $0.id == p.id }) { update(p) } else { add(p) }
    }

    func setActive(id: UUID) {
        guard profiles.contains(where: { $0.id == id }) else { return }
        activeProfileId = id
        persist()
    }

    func delete(id: UUID) {
        profiles.removeAll { $0.id == id }
        if activeProfileId == id { activeProfileId = profiles.first?.id }
        persist()
    }

    // MARK: - Helpers

    /// True if changing to `new` represents a different car (triggers maintenance warning).
    func isVehicleTypeChange(from old: VehicleProfile, to new: VehicleProfile) -> Bool {
        old.make != new.make || old.model != new.model
    }

    // MARK: - Persistence

    private func persist() {
        do {
            let enc = JSONEncoder()
            enc.dateEncodingStrategy = .iso8601
            try enc.encode(profiles).write(to: profilesURL, options: .atomic)
            if let id = activeProfileId {
                try enc.encode(id).write(to: activeURL, options: .atomic)
            }
        } catch { print("VehicleProfileStore persist error:", error) }
    }

    private func load() {
        // Load profiles array
        if let data = try? Data(contentsOf: profilesURL) {
            let dec = JSONDecoder(); dec.dateDecodingStrategy = .iso8601
            profiles = (try? dec.decode([VehicleProfile].self, from: data)) ?? []
        }

        // Migrate: try old single-profile file
        if profiles.isEmpty {
            let oldURL = FileManager.default.urls(for: .documentDirectory,
                                                   in: .userDomainMask).first!
                .appendingPathComponent("vehicle_profile.json")
            if let data = try? Data(contentsOf: oldURL) {
                let dec = JSONDecoder(); dec.dateDecodingStrategy = .iso8601
                if var old = try? dec.decode(VehicleProfile.self, from: data) {
                    if old.id == UUID(uuidString: "00000000-0000-0000-0000-000000000000") {
                        old.id = UUID()
                    }
                    profiles = [old]
                }
            }
        }

        // Load active id
        if let data = try? Data(contentsOf: activeURL),
           let id = try? JSONDecoder().decode(UUID.self, from: data) {
            activeProfileId = id
        } else {
            activeProfileId = profiles.first?.id
        }
    }
}

import Foundation

struct FuelAgentClient {
    private let backend: BackendClient

    init(backend: BackendClient = BackendClient()) {
        self.backend = backend
    }

    func fetchSummary(
        userId: String,
        profile: VehicleProfile,
        trips: [TripResult],
        fuelLogs: [FuelLog]
    ) async throws -> FuelSummary {
        try await backend.post(
            "/fuel/summary",
            body: FuelSummaryRequest(userId: userId, profile: profile, trips: trips, fuelLogs: fuelLogs)
        )
    }
}

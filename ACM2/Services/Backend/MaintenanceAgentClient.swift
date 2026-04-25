import Foundation

struct MaintenanceAgentClient {
    private let backend: BackendClient

    init(backend: BackendClient = BackendClient()) {
        self.backend = backend
    }

    func analyze(
        userId: String,
        profile: VehicleProfile,
        reminders: [MaintenanceReminder],
        trips: [TripResult],
        expenses: [MaintenanceExpense]
    ) async throws -> MaintenanceAnalysis {
        try await backend.post(
            "/maintenance/analyze",
            body: MaintenanceAnalyzeRequest(
                userId: userId,
                profile: profile,
                reminders: reminders,
                trips: trips,
                expenses: expenses
            )
        )
    }
}

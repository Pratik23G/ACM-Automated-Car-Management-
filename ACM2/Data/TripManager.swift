import Foundation
import Combine
import WidgetKit

@MainActor
final class TripManager: ObservableObject {

    @Published var isTripActive:       Bool       = false
    @Published var elapsedSeconds:     Int        = 0
    @Published var completedTrip:      TripResult? = nil
    @Published var showingTripSummary: Bool        = false

    private(set) var activeTripId: UUID?
    let simulationMode = true
    private var timer: Timer?

    // MARK: - Manual Trip Control

    func startTrip() {
        guard !isTripActive else { return }
        activeTripId       = UUID()
        isTripActive       = true
        elapsedSeconds     = 0
        completedTrip      = nil
        showingTripSummary = false
        startTimer()
        syncToWidget(active: true)
    }

    /// Called when app opens and finds widget already started a trip.
    func resumeFromWidget(startedAt: Date) {
        guard !isTripActive else { return }
        activeTripId       = UUID()
        isTripActive       = true
        completedTrip      = nil
        showingTripSummary = false
        // Recover elapsed seconds from actual start time
        elapsedSeconds     = max(0, Int(Date().timeIntervalSince(startedAt)))
        startTimer()
        // Don't call syncToWidget — SharedDefaults already has correct state
    }

    func stopTrip(vehicle: VehicleProfile) {
        isTripActive = false
        timer?.invalidate(); timer = nil
        buildCompletedTrip(vehicle: vehicle, tripId: activeTripId ?? UUID(),
                           durationOverride: nil)
        syncToWidget(active: false)
        showingTripSummary = true
    }

    // MARK: - Auto Trip: confirm a PendingAutoTrip

    /// Called when user taps "Save Trip" on the AutoTripConfirmationBanner.
    func confirmAutoTrip(_ pending: PendingAutoTrip, vehicle: VehicleProfile) {
        let tripId = pending.id
        activeTripId = tripId

        buildCompletedTrip(vehicle: vehicle, tripId: tripId,
                           durationOverride: pending.durationSeconds,
                           distanceOverride: pending.estimatedDistanceMiles,
                           avgSpeedOverride:  pending.estimatedAvgSpeedMph)

        SharedDefaults.pendingAutoTrip = nil
        showingTripSummary = true
    }

    func dismissTripSummary() { showingTripSummary = false }

    // MARK: - Private

    private func startTimer() {
        timer?.invalidate()
        timer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            guard let self else { return }
            Task { @MainActor in
                self.elapsedSeconds += 1
                SharedDefaults.elapsedSeconds = self.elapsedSeconds
                WidgetCenter.shared.reloadTimelines(ofKind: "TripControlWidget")
            }
        }
    }

    private func syncToWidget(active: Bool) {
        SharedDefaults.isTripActive = active
        if active {
            SharedDefaults.tripStartedAt = Date()
        } else {
            SharedDefaults.tripStartedAt = nil
            SharedDefaults.elapsedSeconds = 0
        }
        WidgetCenter.shared.reloadTimelines(ofKind: "TripControlWidget")
    }

    private func buildCompletedTrip(vehicle: VehicleProfile,
                                     tripId: UUID,
                                     durationOverride: Int?,
                                     distanceOverride: Double? = nil,
                                     avgSpeedOverride: Double? = nil) {
        let duration = durationOverride ?? elapsedSeconds

        let distanceMiles: Double? = distanceOverride
            ?? (simulationMode ? Double.random(in: 1.0...12.0) : nil)
        let avgSpeedMph: Double?   = avgSpeedOverride
            ?? (simulationMode ? Double.random(in: 18.0...55.0) : nil)
        let maxSpeedMph: Double?   = simulationMode
            ? (avgSpeedMph ?? 30) + Double.random(in: 10...25) : nil
        let hardBrakes       = simulationMode ? Int.random(in: 0...3) : 0
        let sharpTurns       = simulationMode ? Int.random(in: 0...4) : 0
        let aggressiveAccels = simulationMode ? Int.random(in: 0...3) : 0
        let bumpsDetected    = simulationMode ? Int.random(in: 0...6) : 0
        let mpg              = vehicle.mpg ?? 27.0
        let gallons: Double? = distanceMiles.map { $0 / mpg }
        let fuelCost: Double? = gallons.map { $0 * 4.50 }

        completedTrip = TripResult(
            id: tripId, durationSeconds: duration,
            distanceMiles: distanceMiles, avgSpeedMph: avgSpeedMph, maxSpeedMph: maxSpeedMph,
            hardBrakes: hardBrakes, sharpTurns: sharpTurns, aggressiveAccels: aggressiveAccels,
            bumpsDetected: bumpsDetected, mpg: mpg,
            estimatedGallons: gallons, estimatedFuelCost: fuelCost
        )
    }
}

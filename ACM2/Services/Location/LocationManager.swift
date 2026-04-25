import Foundation
import CoreLocation
import Combine

@MainActor
final class LocationManager: NSObject, ObservableObject {

    @Published var authorizationStatus: CLAuthorizationStatus = .notDetermined
    @Published var currentLocation: CLLocation?
    @Published var isTracking: Bool = false
    @Published var errorMessage: String?

    /// When true, new location updates are delivered but NOT forwarded to the
    /// route-building callback. Use this to freeze the blue line while the
    /// Record sheet is open.
    var isPaused: Bool = false

    var onLocationUpdate: ((CLLocation) -> Void)?

    private let manager = CLLocationManager()

    override init() {
        super.init()
        manager.delegate          = self
        manager.desiredAccuracy   = kCLLocationAccuracyBest
        manager.distanceFilter    = 10
        manager.allowsBackgroundLocationUpdates    = true
        manager.pausesLocationUpdatesAutomatically = false
        authorizationStatus = manager.authorizationStatus
    }

    func requestPermission() { manager.requestWhenInUseAuthorization() }

    func startTracking() {
        guard authorizationStatus == .authorizedWhenInUse ||
              authorizationStatus == .authorizedAlways else {
            requestPermission(); return
        }
        isTracking = true
        manager.startUpdatingLocation()
        manager.startUpdatingHeading()
    }

    func stopTracking() {
        isTracking = false
        manager.stopUpdatingLocation()
        manager.stopUpdatingHeading()
    }

    func requestCurrentLocationOnce() { manager.requestLocation() }
}

extension LocationManager: CLLocationManagerDelegate {

    nonisolated func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        Task { @MainActor in
            self.authorizationStatus = manager.authorizationStatus
            if (manager.authorizationStatus == .authorizedWhenInUse ||
                manager.authorizationStatus == .authorizedAlways) && self.isTracking {
                manager.startUpdatingLocation()
            }
        }
    }

    nonisolated func locationManager(_ manager: CLLocationManager,
                                     didUpdateLocations locations: [CLLocation]) {
        guard let loc = locations.last else { return }
        Task { @MainActor in
            self.currentLocation = loc
            self.errorMessage    = nil
            if !self.isPaused {
                self.onLocationUpdate?(loc)
            }
        }
    }

    nonisolated func locationManager(_ manager: CLLocationManager,
                                     didFailWithError error: Error) {
        Task { @MainActor in self.errorMessage = error.localizedDescription }
    }
}


import Foundation
import MapKit

struct DemoRouteGeometry {
    let coordinates: [SerializableCoordinate]
    let distanceMiles: Double
    let expectedTravelTime: TimeInterval
}

enum DemoRouteGeometryBuilder {
    static func palaceToBerryessaRoundTrip() async throws -> (forward: DemoRouteGeometry, reverse: DemoRouteGeometry) {
        async let forward = automobileRoute(
            from: CLLocationCoordinate2D(latitude: 37.8024, longitude: -122.4485),
            to: CLLocationCoordinate2D(latitude: 37.3681, longitude: -121.8746)
        )
        async let reverse = automobileRoute(
            from: CLLocationCoordinate2D(latitude: 37.3681, longitude: -121.8746),
            to: CLLocationCoordinate2D(latitude: 37.8024, longitude: -122.4485)
        )

        return try await (forward, reverse)
    }

    static func automobileRoute(from origin: CLLocationCoordinate2D,
                                to destination: CLLocationCoordinate2D) async throws -> DemoRouteGeometry {
        let request = MKDirections.Request()
        request.source = MKMapItem(placemark: MKPlacemark(coordinate: origin))
        request.destination = MKMapItem(placemark: MKPlacemark(coordinate: destination))
        request.transportType = .automobile
        request.requestsAlternateRoutes = false

        let response = try await MKDirections(request: request).calculate()
        guard let route = response.routes.first else {
            throw DemoRouteGeometryError.routeNotFound
        }

        let coordinates = route.polyline.coordinates.map(SerializableCoordinate.init)
        return DemoRouteGeometry(
            coordinates: coordinates,
            distanceMiles: route.distance / 1609.34,
            expectedTravelTime: route.expectedTravelTime
        )
    }
}

private extension MKPolyline {
    var coordinates: [CLLocationCoordinate2D] {
        var coords = Array(
            repeating: CLLocationCoordinate2D(latitude: 0, longitude: 0),
            count: pointCount
        )
        getCoordinates(&coords, range: NSRange(location: 0, length: pointCount))
        return coords
    }
}

enum DemoRouteGeometryError: LocalizedError {
    case routeNotFound

    var errorDescription: String? {
        switch self {
        case .routeNotFound:
            return "Apple Maps could not generate a driving route for the demo history."
        }
    }
}

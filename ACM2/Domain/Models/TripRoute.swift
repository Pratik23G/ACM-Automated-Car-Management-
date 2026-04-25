import Foundation

/// Full recorded path for one trip — GPS breadcrumbs + all notes dropped during that trip.
struct TripRoute: Identifiable, Codable {
    var id:          UUID   = UUID()        // matches TripResult.id
    var startedAt:   Date   = Date()
    var endedAt:     Date?
    var coordinates: [SerializableCoordinate] = []
    var notes:       [RouteNote]           = []

    // MARK: - Helpers

    /// Total distance in miles derived from the breadcrumb trail.
    var calculatedDistanceMiles: Double {
        guard coordinates.count > 1 else { return 0 }
        var total = 0.0
        for i in 1..<coordinates.count {
            total += coordinates[i - 1].distance(to: coordinates[i])
        }
        return total / 1609.34
    }

    /// Bounding box for framing the map camera.
    var boundingRegion: (center: SerializableCoordinate,
                         latDelta: Double, lngDelta: Double)? {
        guard !coordinates.isEmpty else { return nil }
        let lats = coordinates.map { $0.latitude }
        let lngs = coordinates.map { $0.longitude }
        let minLat = lats.min()!, maxLat = lats.max()!
        let minLng = lngs.min()!, maxLng = lngs.max()!
        let center = SerializableCoordinate(latitude: (minLat + maxLat) / 2,
                                            longitude: (minLng + maxLng) / 2)
        let latDelta = max((maxLat - minLat) * 1.4, 0.01)
        let lngDelta = max((maxLng - minLng) * 1.4, 0.01)
        return (center, latDelta, lngDelta)
    }
}


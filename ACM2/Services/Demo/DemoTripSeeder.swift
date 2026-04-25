import Foundation
import CoreLocation

struct DemoTripSeedResult {
    let tripCount: Int
    let placeCount: Int
    let vehicleName: String
}

struct DemoTripSeedPayload {
    let vehicle: VehicleProfile
    let trips: [TripResult]
    let routes: [TripRoute]
    let places: [SavedPlace]
}

@MainActor
enum DemoTripSeeder {
    static func seedRichBayAreaHistory(vehicleStore: VehicleProfileStore,
                                       tripHistory: TripHistoryStore,
                                       routeStore: RouteStore,
                                       placesStore: SavedPlacesStore) async throws -> DemoTripSeedResult {
        let payload = try await buildRichBayAreaHistory(referenceDate: Date())

        vehicleStore.save(payload.vehicle)
        vehicleStore.setActive(id: payload.vehicle.id)

        for trip in payload.trips.sorted(by: { $0.endedAt < $1.endedAt }) {
            let existing = tripHistory.trips.first(where: { $0.id == trip.id })
            tripHistory.add(mergeTrip(seedTrip: trip, existingTrip: existing))
        }

        for route in payload.routes.sorted(by: { ($0.endedAt ?? .distantPast) < ($1.endedAt ?? .distantPast) }) {
            let existing = routeStore.route(for: route.id)
            routeStore.upsert(mergeRoute(seedRoute: route, existingRoute: existing))
        }

        for place in payload.places {
            let existing = placesStore.places.first(where: { $0.id == place.id })
            upsert(place: mergePlace(seedPlace: place, existingPlace: existing), into: placesStore)
        }

        return DemoTripSeedResult(
            tripCount: payload.trips.count,
            placeCount: payload.places.count,
            vehicleName: payload.vehicle.displayName
        )
    }

    static func buildRichBayAreaHistory(referenceDate: Date = Date()) async throws -> DemoTripSeedPayload {
        let vehicle = buildDemoVehicle()
        let routeLibrary = try await buildRouteLibrary()
        let seededTrips = buildTripSeeds(
            referenceDate: referenceDate,
            mpg: vehicle.mpg ?? 44,
            routeLibrary: routeLibrary
        )

        return DemoTripSeedPayload(
            vehicle: vehicle,
            trips: seededTrips.map(\.trip),
            routes: seededTrips.map(\.route),
            places: buildPlaces(using: seededTrips, referenceDate: referenceDate)
        )
    }
}

private extension DemoTripSeeder {
    struct SeededTrip {
        let destinationPlaceId: UUID
        let trip: TripResult
        let route: TripRoute
    }

    enum RouteKey: String {
        case palaceToBerryessa
        case berryessaToPalace
        case palaceToFerryBuilding
        case ferryBuildingToPalace
        case palaceToBerkeleyBowl
        case berryessaToSantanaRow
        case palaceToStanford

        var label: String {
            switch self {
            case .palaceToBerryessa:
                return "Palace of Fine Arts to Berryessa BART"
            case .berryessaToPalace:
                return "Berryessa BART to Palace of Fine Arts"
            case .palaceToFerryBuilding:
                return "Palace of Fine Arts to Ferry Building"
            case .ferryBuildingToPalace:
                return "Ferry Building to Palace of Fine Arts"
            case .palaceToBerkeleyBowl:
                return "Palace of Fine Arts to Berkeley Bowl West"
            case .berryessaToSantanaRow:
                return "Berryessa BART to Santana Row"
            case .palaceToStanford:
                return "Palace of Fine Arts to Stanford Shopping Center"
            }
        }

        var defaultMaxSpeed: Double {
            switch self {
            case .palaceToBerryessa, .berryessaToPalace, .palaceToStanford:
                return 72
            case .palaceToBerkeleyBowl, .berryessaToSantanaRow:
                return 66
            case .palaceToFerryBuilding, .ferryBuildingToPalace:
                return 48
            }
        }
    }

    struct TripBlueprint {
        let sequence: Int
        let daysAgo: Int
        let hour: Int
        let minute: Int
        let routeKey: RouteKey
        let durationSeconds: Int
        let hardBrakes: Int
        let sharpTurns: Int
        let aggressiveAccels: Int
        let bumpsDetected: Int
        let pricePerGallon: Double
        let destinationPlaceId: UUID
        let noteVariant: Int
        let summary: String
        let overallTip: String
    }

    struct NoteBlueprint {
        let fraction: Double
        let type: RouteNote.NoteType
        let title: String
        let body: String
        let isReminder: Bool
        let reminderMessage: String?
    }

    struct PlaceReminderBlueprint {
        let sequence: Int
        let title: String
        let body: String
    }

    struct DemoPlaceSpec {
        let order: Int
        let id: UUID
        let name: String
        let category: PlaceCategory
        let customLabel: String
        let reminders: [PlaceReminderBlueprint]
    }

    static let demoVehicleId = UUID(uuidString: "F1000000-0000-0000-0000-000000000001")!

    static let palacePlaceId = UUID(uuidString: "F1000000-0000-0000-0000-000000000101")!
    static let berryessaPlaceId = UUID(uuidString: "F1000000-0000-0000-0000-000000000102")!
    static let ferryBuildingPlaceId = UUID(uuidString: "F1000000-0000-0000-0000-000000000103")!
    static let berkeleyBowlPlaceId = UUID(uuidString: "F1000000-0000-0000-0000-000000000104")!
    static let santanaRowPlaceId = UUID(uuidString: "F1000000-0000-0000-0000-000000000105")!
    static let stanfordPlaceId = UUID(uuidString: "F1000000-0000-0000-0000-000000000106")!

    static let palaceCoordinate = CLLocationCoordinate2D(latitude: 37.8024, longitude: -122.4485)
    static let berryessaCoordinate = CLLocationCoordinate2D(latitude: 37.3681, longitude: -121.8746)
    static let ferryBuildingCoordinate = CLLocationCoordinate2D(latitude: 37.7955, longitude: -122.3937)
    static let berkeleyBowlCoordinate = CLLocationCoordinate2D(latitude: 37.8516, longitude: -122.2892)
    static let santanaRowCoordinate = CLLocationCoordinate2D(latitude: 37.3212, longitude: -121.9476)
    static let stanfordCoordinate = CLLocationCoordinate2D(latitude: 37.4437, longitude: -122.1715)

    static func buildDemoVehicle() -> VehicleProfile {
        VehicleProfile(
            id: demoVehicleId,
            make: "Toyota",
            model: "Camry Hybrid Demo",
            year: 2022,
            fuelType: .hybrid,
            mpg: 44.0,
            miPerKwh: nil,
            brakePadsInstalledAt: Calendar.current.date(byAdding: .month, value: -7, to: Date()),
            currentOdometerMiles: 28410,
            bluetoothDeviceUUID: nil,
            bluetoothDeviceName: nil,
            motionAutoDetectEnabled: true
        )
    }

    static func buildRouteLibrary() async throws -> [RouteKey: DemoRouteGeometry] {
        async let palaceToBerryessa = DemoRouteGeometryBuilder.automobileRoute(
            from: palaceCoordinate,
            to: berryessaCoordinate
        )
        async let berryessaToPalace = DemoRouteGeometryBuilder.automobileRoute(
            from: berryessaCoordinate,
            to: palaceCoordinate
        )
        async let palaceToFerry = DemoRouteGeometryBuilder.automobileRoute(
            from: palaceCoordinate,
            to: ferryBuildingCoordinate
        )
        async let ferryToPalace = DemoRouteGeometryBuilder.automobileRoute(
            from: ferryBuildingCoordinate,
            to: palaceCoordinate
        )
        async let palaceToBerkeley = DemoRouteGeometryBuilder.automobileRoute(
            from: palaceCoordinate,
            to: berkeleyBowlCoordinate
        )
        async let berryessaToSantana = DemoRouteGeometryBuilder.automobileRoute(
            from: berryessaCoordinate,
            to: santanaRowCoordinate
        )
        async let palaceToStanford = DemoRouteGeometryBuilder.automobileRoute(
            from: palaceCoordinate,
            to: stanfordCoordinate
        )

        return [
            .palaceToBerryessa: try await palaceToBerryessa,
            .berryessaToPalace: try await berryessaToPalace,
            .palaceToFerryBuilding: try await palaceToFerry,
            .ferryBuildingToPalace: try await ferryToPalace,
            .palaceToBerkeleyBowl: try await palaceToBerkeley,
            .berryessaToSantanaRow: try await berryessaToSantana,
            .palaceToStanford: try await palaceToStanford
        ]
    }

    static func buildTripSeeds(referenceDate: Date,
                               mpg: Double,
                               routeLibrary: [RouteKey: DemoRouteGeometry]) -> [SeededTrip] {
        let calendar = Calendar.current

        let blueprints: [TripBlueprint] = [
            TripBlueprint(
                sequence: 1000,
                daysAgo: 17,
                hour: 8,
                minute: 10,
                routeKey: .palaceToBerryessa,
                durationSeconds: 4380,
                hardBrakes: 2,
                sharpTurns: 1,
                aggressiveAccels: 1,
                bumpsDetected: 1,
                pricePerGallon: 4.62,
                destinationPlaceId: berryessaPlaceId,
                noteVariant: 0,
                summary: "Morning commute to Berryessa BART stayed steady with only one real slowdown near Candlestick.",
                overallTip: "If you repeat this commute tomorrow, fuel up south of the city instead of near the Marina."
            ),
            TripBlueprint(
                sequence: 1001,
                daysAgo: 17,
                hour: 18,
                minute: 5,
                routeKey: .berryessaToPalace,
                durationSeconds: 4620,
                hardBrakes: 3,
                sharpTurns: 2,
                aggressiveAccels: 1,
                bumpsDetected: 1,
                pricePerGallon: 4.62,
                destinationPlaceId: palacePlaceId,
                noteVariant: 0,
                summary: "The evening return was a little heavier through 880, but the Palace finish still stayed under 80 minutes.",
                overallTip: "A Milpitas gas stop on the way out beats refueling once you are back in SF."
            ),
            TripBlueprint(
                sequence: 1002,
                daysAgo: 14,
                hour: 8,
                minute: 0,
                routeKey: .palaceToBerryessa,
                durationSeconds: 4500,
                hardBrakes: 2,
                sharpTurns: 2,
                aggressiveAccels: 2,
                bumpsDetected: 2,
                pricePerGallon: 4.58,
                destinationPlaceId: berryessaPlaceId,
                noteVariant: 1,
                summary: "This run started a touch slower, but traffic opened after San Mateo and the pace normalized quickly.",
                overallTip: "Leave five minutes earlier on midweek mornings and you will dodge the thickest bridge queue."
            ),
            TripBlueprint(
                sequence: 1003,
                daysAgo: 14,
                hour: 18,
                minute: 20,
                routeKey: .berryessaToPalace,
                durationSeconds: 4680,
                hardBrakes: 4,
                sharpTurns: 2,
                aggressiveAccels: 1,
                bumpsDetected: 2,
                pricePerGallon: 4.58,
                destinationPlaceId: palacePlaceId,
                noteVariant: 1,
                summary: "The ride back from Berryessa had the usual evening compression near Oyster Point but otherwise felt routine.",
                overallTip: "Treat this route as a washer-fluid and windshield check night when the forecast is hazy."
            ),
            TripBlueprint(
                sequence: 1004,
                daysAgo: 10,
                hour: 7,
                minute: 55,
                routeKey: .palaceToBerryessa,
                durationSeconds: 4320,
                hardBrakes: 1,
                sharpTurns: 1,
                aggressiveAccels: 1,
                bumpsDetected: 1,
                pricePerGallon: 4.54,
                destinationPlaceId: berryessaPlaceId,
                noteVariant: 2,
                summary: "This was one of the cleaner Berryessa mornings with smooth pacing and very few hard inputs.",
                overallTip: "Keep sunglasses in reach on this one because the final 880 stretch gets bright fast."
            ),
            TripBlueprint(
                sequence: 1005,
                daysAgo: 10,
                hour: 18,
                minute: 15,
                routeKey: .berryessaToPalace,
                durationSeconds: 4740,
                hardBrakes: 3,
                sharpTurns: 2,
                aggressiveAccels: 2,
                bumpsDetected: 1,
                pricePerGallon: 4.54,
                destinationPlaceId: palacePlaceId,
                noteVariant: 2,
                summary: "The trip home ran heavier near Candlestick, but you still kept the drive composed through the final city stretch.",
                overallTip: "If you need a cheaper fill-up, Brokaw is still the better bet before crossing back toward SF."
            ),
            TripBlueprint(
                sequence: 1006,
                daysAgo: 7,
                hour: 8,
                minute: 5,
                routeKey: .palaceToBerryessa,
                durationSeconds: 4560,
                hardBrakes: 2,
                sharpTurns: 1,
                aggressiveAccels: 2,
                bumpsDetected: 2,
                pricePerGallon: 4.49,
                destinationPlaceId: berryessaPlaceId,
                noteVariant: 0,
                summary: "Traffic was thicker than average, but the route still landed close to your normal Berryessa timing.",
                overallTip: "Use the Airport Boulevard stop only when you actually need gas; otherwise stay moving through the corridor."
            ),
            TripBlueprint(
                sequence: 1007,
                daysAgo: 7,
                hour: 18,
                minute: 10,
                routeKey: .berryessaToPalace,
                durationSeconds: 4800,
                hardBrakes: 3,
                sharpTurns: 2,
                aggressiveAccels: 2,
                bumpsDetected: 2,
                pricePerGallon: 4.49,
                destinationPlaceId: palacePlaceId,
                noteVariant: 0,
                summary: "Evening congestion added a few minutes, though the route stayed predictable once you cleared SFO traffic.",
                overallTip: "Keep a little extra following distance on the 880 to 101 transition and this return drive feels much calmer."
            ),
            TripBlueprint(
                sequence: 1008,
                daysAgo: 3,
                hour: 8,
                minute: 0,
                routeKey: .palaceToBerryessa,
                durationSeconds: 4440,
                hardBrakes: 2,
                sharpTurns: 1,
                aggressiveAccels: 1,
                bumpsDetected: 1,
                pricePerGallon: 4.45,
                destinationPlaceId: berryessaPlaceId,
                noteVariant: 1,
                summary: "This recent morning trip tracked almost exactly with your typical Berryessa pace and fuel use.",
                overallTip: "The middle lanes have been more consistent lately than hugging the left through San Mateo."
            ),
            TripBlueprint(
                sequence: 1009,
                daysAgo: 3,
                hour: 18,
                minute: 25,
                routeKey: .berryessaToPalace,
                durationSeconds: 4860,
                hardBrakes: 4,
                sharpTurns: 2,
                aggressiveAccels: 2,
                bumpsDetected: 2,
                pricePerGallon: 4.45,
                destinationPlaceId: palacePlaceId,
                noteVariant: 1,
                summary: "The most recent return had the usual evening friction, but it still settled into a manageable flow by South SF.",
                overallTip: "Top off washer fluid and snacks after this route so the next morning start is easier."
            ),
            TripBlueprint(
                sequence: 1010,
                daysAgo: 12,
                hour: 12,
                minute: 10,
                routeKey: .palaceToFerryBuilding,
                durationSeconds: 1680,
                hardBrakes: 1,
                sharpTurns: 3,
                aggressiveAccels: 1,
                bumpsDetected: 0,
                pricePerGallon: 4.56,
                destinationPlaceId: ferryBuildingPlaceId,
                noteVariant: 0,
                summary: "A short lunch run downtown with light driving events and mostly city-speed traffic.",
                overallTip: "Downtown is easiest when you park early and walk the last block instead of circling Embarcadero."
            ),
            TripBlueprint(
                sequence: 1011,
                daysAgo: 12,
                hour: 15,
                minute: 5,
                routeKey: .ferryBuildingToPalace,
                durationSeconds: 1860,
                hardBrakes: 2,
                sharpTurns: 3,
                aggressiveAccels: 1,
                bumpsDetected: 1,
                pricePerGallon: 4.56,
                destinationPlaceId: palacePlaceId,
                noteVariant: 0,
                summary: "The ride back west stayed compact and city-heavy, with a couple stop-and-go pockets around Van Ness.",
                overallTip: "Use the Fort Mason side if Lombard looks stacked."
            ),
            TripBlueprint(
                sequence: 1012,
                daysAgo: 9,
                hour: 18,
                minute: 40,
                routeKey: .palaceToBerkeleyBowl,
                durationSeconds: 2580,
                hardBrakes: 2,
                sharpTurns: 2,
                aggressiveAccels: 1,
                bumpsDetected: 1,
                pricePerGallon: 4.52,
                destinationPlaceId: berkeleyBowlPlaceId,
                noteVariant: 0,
                summary: "This cross-bay grocery trip was efficient aside from the usual metering before the bridge.",
                overallTip: "Bring insulated bags and skip the last-minute gas stations right off the bridge."
            ),
            TripBlueprint(
                sequence: 1013,
                daysAgo: 5,
                hour: 19,
                minute: 20,
                routeKey: .berryessaToSantanaRow,
                durationSeconds: 1560,
                hardBrakes: 2,
                sharpTurns: 2,
                aggressiveAccels: 2,
                bumpsDetected: 1,
                pricePerGallon: 4.36,
                destinationPlaceId: santanaRowPlaceId,
                noteVariant: 0,
                summary: "A compact South Bay dinner run with a busy interchange but otherwise easy mileage.",
                overallTip: "Head straight for a garage at Santana Row instead of trying to hunt curb parking."
            ),
            TripBlueprint(
                sequence: 1014,
                daysAgo: 1,
                hour: 11,
                minute: 15,
                routeKey: .palaceToStanford,
                durationSeconds: 3240,
                hardBrakes: 1,
                sharpTurns: 2,
                aggressiveAccels: 1,
                bumpsDetected: 2,
                pricePerGallon: 4.41,
                destinationPlaceId: stanfordPlaceId,
                noteVariant: 0,
                summary: "A smooth peninsula shopping run with only minor pavement chatter southbound.",
                overallTip: "Pay for parking before you wander and refuel outside SF on the way back."
            )
        ]

        return blueprints.compactMap { blueprint in
            guard let tripId = tripUUID(for: blueprint.sequence),
                  let geometry = routeLibrary[blueprint.routeKey] else {
                return nil
            }

            let baseDate = calendar.date(byAdding: .day, value: -blueprint.daysAgo, to: referenceDate) ?? referenceDate
            let endedAt = calendar.date(
                bySettingHour: blueprint.hour,
                minute: blueprint.minute,
                second: 0,
                of: baseDate
            ) ?? baseDate
            let startedAt = endedAt.addingTimeInterval(TimeInterval(-blueprint.durationSeconds))
            let distanceMiles = geometry.distanceMiles
            let gallons = distanceMiles / mpg
            let fuelCost = gallons * blueprint.pricePerGallon
            let avgSpeed = distanceMiles / (Double(blueprint.durationSeconds) / 3600)
            let notes = buildRouteNotes(
                tripId: tripId,
                tripSequence: blueprint.sequence,
                startedAt: startedAt,
                durationSeconds: blueprint.durationSeconds,
                route: geometry,
                routeKey: blueprint.routeKey,
                variant: blueprint.noteVariant
            )

            let roadCallout = notes.first(where: { $0.type == .hazard || $0.type == .roadQuality })?.title
                ?? "a few minor rough spots"

            let trip = TripResult(
                id: tripId,
                endedAt: endedAt,
                durationSeconds: blueprint.durationSeconds,
                distanceMiles: distanceMiles,
                avgSpeedMph: avgSpeed,
                maxSpeedMph: blueprint.routeKey.defaultMaxSpeed,
                hardBrakes: blueprint.hardBrakes,
                sharpTurns: blueprint.sharpTurns,
                aggressiveAccels: blueprint.aggressiveAccels,
                bumpsDetected: blueprint.bumpsDetected,
                mpg: mpg,
                estimatedGallons: gallons,
                estimatedFuelCost: fuelCost,
                aiTripSummary: blueprint.summary,
                aiDrivingBehavior: drivingBehaviorText(for: blueprint),
                aiFuelInsight: fuelInsightText(
                    for: blueprint,
                    mpg: mpg,
                    gallons: gallons,
                    fuelCost: fuelCost
                ),
                aiRoadImpact: roadImpactText(for: blueprint, roadCallout: roadCallout),
                aiBrakeWear: brakeWearText(for: blueprint),
                aiOverallTip: blueprint.overallTip
            )

            let route = TripRoute(
                id: tripId,
                startedAt: startedAt,
                endedAt: endedAt,
                coordinates: geometry.coordinates,
                notes: notes
            )

            return SeededTrip(
                destinationPlaceId: blueprint.destinationPlaceId,
                trip: trip,
                route: route
            )
        }
    }

    static func buildPlaces(using seeds: [SeededTrip], referenceDate: Date) -> [SavedPlace] {
        let calendar = Calendar.current

        return placeSpecs()
            .sorted { $0.order < $1.order }
            .map { spec in
                let tripIds = seeds
                    .filter { $0.destinationPlaceId == spec.id }
                    .map(\.trip.id)
                    .sorted { $0.uuidString < $1.uuidString }

                let lastVisited = seeds
                    .filter { $0.destinationPlaceId == spec.id }
                    .map(\.trip.endedAt)
                    .max()

                let reminders = spec.reminders.map { reminder in
                    PlaceReminder(
                        id: placeReminderUUID(for: reminder.sequence),
                        title: reminder.title,
                        body: reminder.body,
                        isActive: true,
                        createdAt: calendar.date(byAdding: .day, value: -21 + reminder.sequence, to: referenceDate) ?? referenceDate
                    )
                }

                return SavedPlace(
                    id: spec.id,
                    name: spec.name,
                    category: spec.category,
                    customLabel: spec.customLabel,
                    tripIds: tripIds,
                    reminders: reminders,
                    createdAt: calendar.date(byAdding: .month, value: -3, to: referenceDate) ?? referenceDate,
                    lastVisited: lastVisited
                )
            }
    }

    static func placeSpecs() -> [DemoPlaceSpec] {
        [
            DemoPlaceSpec(
                order: 0,
                id: palacePlaceId,
                name: "Palace of Fine Arts",
                category: .other,
                customLabel: "Palace of Fine Arts",
                reminders: [
                    PlaceReminderBlueprint(
                        sequence: 1,
                        title: "Check weekend closures",
                        body: "Event setups near the Palace can make parking tighter than usual."
                    )
                ]
            ),
            DemoPlaceSpec(
                order: 1,
                id: berryessaPlaceId,
                name: "Berryessa BART",
                category: .other,
                customLabel: "Berryessa BART",
                reminders: [
                    PlaceReminderBlueprint(
                        sequence: 2,
                        title: "Reload Clipper on Sunday",
                        body: "Quick Sunday night check so the Monday platform walk stays smooth."
                    )
                ]
            ),
            DemoPlaceSpec(
                order: 2,
                id: ferryBuildingPlaceId,
                name: "Ferry Building",
                category: .other,
                customLabel: "Ferry Building",
                reminders: [
                    PlaceReminderBlueprint(
                        sequence: 3,
                        title: "Reserve lunch parking early",
                        body: "Garage pricing gets steeper after noon around the Ferry Building."
                    )
                ]
            ),
            DemoPlaceSpec(
                order: 3,
                id: berkeleyBowlPlaceId,
                name: "Berkeley Bowl West",
                category: .other,
                customLabel: "Berkeley Bowl West",
                reminders: [
                    PlaceReminderBlueprint(
                        sequence: 4,
                        title: "Bring insulated bags",
                        body: "Helpful for produce and frozen food on the cross-bay return."
                    )
                ]
            ),
            DemoPlaceSpec(
                order: 4,
                id: santanaRowPlaceId,
                name: "Santana Row",
                category: .other,
                customLabel: "Santana Row",
                reminders: [
                    PlaceReminderBlueprint(
                        sequence: 5,
                        title: "Use the Winchester garage",
                        body: "It is usually easier than circling the curb lanes during dinner hours."
                    )
                ]
            ),
            DemoPlaceSpec(
                order: 5,
                id: stanfordPlaceId,
                name: "Stanford Shopping Center",
                category: .other,
                customLabel: "Stanford Shopping Center",
                reminders: [
                    PlaceReminderBlueprint(
                        sequence: 6,
                        title: "Note your parking section",
                        body: "The garages look similar when the lots are busy in the afternoon."
                    )
                ]
            )
        ]
    }

    static func buildRouteNotes(tripId: UUID,
                                tripSequence: Int,
                                startedAt: Date,
                                durationSeconds: Int,
                                route: DemoRouteGeometry,
                                routeKey: RouteKey,
                                variant: Int) -> [RouteNote] {
        noteBlueprints(for: routeKey, variant: variant).enumerated().map { index, blueprint in
            RouteNote(
                id: noteUUID(for: tripSequence, noteIndex: index),
                tripId: tripId,
                coordinate: coordinate(at: blueprint.fraction, in: route.coordinates),
                type: blueprint.type,
                title: blueprint.title,
                body: blueprint.body,
                isReminder: blueprint.isReminder,
                reminderMessage: blueprint.reminderMessage,
                createdAt: startedAt.addingTimeInterval(TimeInterval(durationSeconds) * blueprint.fraction)
            )
        }
    }

    static func noteBlueprints(for routeKey: RouteKey, variant: Int) -> [NoteBlueprint] {
        switch routeKey {
        case .palaceToBerryessa:
            let packs: [[NoteBlueprint]] = [
                [
                    NoteBlueprint(
                        fraction: 0.23,
                        type: .food,
                        title: "Costco gas near Airport Blvd",
                        body: "Worth the short detour on heavier commute days when you need a cheaper fill-up.",
                        isReminder: false,
                        reminderMessage: nil
                    ),
                    NoteBlueprint(
                        fraction: 0.58,
                        type: .hazard,
                        title: "Candlestick merge slows suddenly",
                        body: "Southbound 101 compresses quickly after the bend, so leave extra braking room here.",
                        isReminder: false,
                        reminderMessage: nil
                    ),
                    NoteBlueprint(
                        fraction: 0.91,
                        type: .reminder,
                        title: "Reload Clipper before parking",
                        body: "Easy checkpoint before you walk into Berryessa.",
                        isReminder: true,
                        reminderMessage: "Top off Clipper and grab your work badge."
                    )
                ],
                [
                    NoteBlueprint(
                        fraction: 0.18,
                        type: .food,
                        title: "Andytown coffee detour stays quick",
                        body: "A fast pre-bridge stop when you leave before the heaviest rush.",
                        isReminder: false,
                        reminderMessage: nil
                    ),
                    NoteBlueprint(
                        fraction: 0.42,
                        type: .roadQuality,
                        title: "Bridge joints get choppy here",
                        body: "The expansion joints can trigger a couple bump events on rougher mornings.",
                        isReminder: false,
                        reminderMessage: nil
                    ),
                    NoteBlueprint(
                        fraction: 0.73,
                        type: .general,
                        title: "Middle lanes open up after San Mateo",
                        body: "This stretch has been smoother than hugging the left lane lately.",
                        isReminder: false,
                        reminderMessage: nil
                    )
                ],
                [
                    NoteBlueprint(
                        fraction: 0.22,
                        type: .food,
                        title: "Old Bayshore Arco beats Marina prices",
                        body: "Usually one of the better-value gas options before the South Bay push.",
                        isReminder: false,
                        reminderMessage: nil
                    ),
                    NoteBlueprint(
                        fraction: 0.64,
                        type: .hazard,
                        title: "Watch braking near the 92 connector",
                        body: "Traffic stacks quickly when the connector backs onto 101.",
                        isReminder: false,
                        reminderMessage: nil
                    ),
                    NoteBlueprint(
                        fraction: 0.88,
                        type: .reminder,
                        title: "Grab sunglasses for the final stretch",
                        body: "The light gets bright on the last push toward Berryessa.",
                        isReminder: true,
                        reminderMessage: "Keep shades handy before the final 10 minutes."
                    )
                ]
            ]
            return packs[variant % packs.count]

        case .berryessaToPalace:
            let packs: [[NoteBlueprint]] = [
                [
                    NoteBlueprint(
                        fraction: 0.16,
                        type: .food,
                        title: "Chevron by McKee is an easy top-off",
                        body: "A practical gas stop before you head back toward the higher SF prices.",
                        isReminder: false,
                        reminderMessage: nil
                    ),
                    NoteBlueprint(
                        fraction: 0.34,
                        type: .hazard,
                        title: "880 to 101 west backs up fast",
                        body: "This merge goes from flowing to stop-and-go very quickly during the evening rush.",
                        isReminder: false,
                        reminderMessage: nil
                    ),
                    NoteBlueprint(
                        fraction: 0.82,
                        type: .general,
                        title: "Fort Mason side streets stay calmer",
                        body: "If Lombard looks stacked, the quieter westbound grid can be less stressful.",
                        isReminder: false,
                        reminderMessage: nil
                    )
                ],
                [
                    NoteBlueprint(
                        fraction: 0.21,
                        type: .food,
                        title: "Millbrae dinner stop stays easy",
                        body: "This is a reliable quick-food stop when the return drive is dragging on.",
                        isReminder: false,
                        reminderMessage: nil
                    ),
                    NoteBlueprint(
                        fraction: 0.53,
                        type: .roadQuality,
                        title: "Oyster Point lane seams feel rough",
                        body: "The patched pavement and seams here explain most of the bumps on this return.",
                        isReminder: false,
                        reminderMessage: nil
                    ),
                    NoteBlueprint(
                        fraction: 0.87,
                        type: .reminder,
                        title: "Refill washer fluid tonight",
                        body: "A quick evening maintenance reset before the next early trip.",
                        isReminder: true,
                        reminderMessage: "Refill washer fluid and clear the windshield before tomorrow morning."
                    )
                ],
                [
                    NoteBlueprint(
                        fraction: 0.17,
                        type: .food,
                        title: "Shell on Brokaw runs cheaper than SF",
                        body: "If you need gas, this is still a better-value stop than waiting until the city.",
                        isReminder: false,
                        reminderMessage: nil
                    ),
                    NoteBlueprint(
                        fraction: 0.63,
                        type: .hazard,
                        title: "Candlestick crosswinds tug the car",
                        body: "Even when traffic is light, this section can feel twitchy in the evening.",
                        isReminder: false,
                        reminderMessage: nil
                    ),
                    NoteBlueprint(
                        fraction: 0.93,
                        type: .general,
                        title: "Palace parking fills up around sunset",
                        body: "Good to know if you are meeting someone here at the end of the drive.",
                        isReminder: false,
                        reminderMessage: nil
                    )
                ]
            ]
            return packs[variant % packs.count]

        case .palaceToFerryBuilding:
            return [
                NoteBlueprint(
                    fraction: 0.34,
                    type: .food,
                    title: "Blue Bottle pickup window here",
                    body: "Easy lunch or coffee stop once you are near the Ferry Building.",
                    isReminder: false,
                    reminderMessage: nil
                ),
                NoteBlueprint(
                    fraction: 0.67,
                    type: .hazard,
                    title: "Watch cyclists on the Embarcadero",
                    body: "Delivery vans and bike traffic squeeze the curb lane here.",
                    isReminder: false,
                    reminderMessage: nil
                ),
                NoteBlueprint(
                    fraction: 0.86,
                    type: .reminder,
                    title: "Garage rates jump after noon",
                    body: "If you are parking here, lock in a spot early.",
                    isReminder: true,
                    reminderMessage: "Park early or use the pier lot before lunchtime pricing kicks in."
                )
            ]

        case .ferryBuildingToPalace:
            return [
                NoteBlueprint(
                    fraction: 0.28,
                    type: .food,
                    title: "Van Ness fuel stop is less painful",
                    body: "If you need gas on the city side, this is less chaotic than the waterfront choices.",
                    isReminder: false,
                    reminderMessage: nil
                ),
                NoteBlueprint(
                    fraction: 0.47,
                    type: .roadQuality,
                    title: "Bus lane shifts on Van Ness",
                    body: "Lane changes happen quickly here, and the pavement can feel uneven.",
                    isReminder: false,
                    reminderMessage: nil
                ),
                NoteBlueprint(
                    fraction: 0.78,
                    type: .general,
                    title: "Fort Mason detour is calmer than Lombard",
                    body: "A good backup when tourist traffic starts stacking westbound.",
                    isReminder: false,
                    reminderMessage: nil
                )
            ]

        case .palaceToBerkeleyBowl:
            return [
                NoteBlueprint(
                    fraction: 0.25,
                    type: .food,
                    title: "San Pablo gas is cheaper than bridge exits",
                    body: "Better value once you are off the bridge than grabbing gas right before it.",
                    isReminder: false,
                    reminderMessage: nil
                ),
                NoteBlueprint(
                    fraction: 0.49,
                    type: .hazard,
                    title: "Bay Bridge metering stacks up here",
                    body: "This queue forms quickly in the late afternoon and can trigger stop-and-go braking.",
                    isReminder: false,
                    reminderMessage: nil
                ),
                NoteBlueprint(
                    fraction: 0.88,
                    type: .reminder,
                    title: "Bring insulated bags for produce",
                    body: "Helpful for keeping groceries in better shape on the way home.",
                    isReminder: true,
                    reminderMessage: "Grab the insulated bags before you head inside Berkeley Bowl."
                )
            ]

        case .berryessaToSantanaRow:
            return [
                NoteBlueprint(
                    fraction: 0.32,
                    type: .food,
                    title: "Santana Row dinner waits spike after 7",
                    body: "If you are hungry, reserve or choose a quick-stop place before arrival.",
                    isReminder: false,
                    reminderMessage: nil
                ),
                NoteBlueprint(
                    fraction: 0.55,
                    type: .hazard,
                    title: "880 and 17 compress fast",
                    body: "This interchange gets short-notice stop-and-go traffic even on lighter nights.",
                    isReminder: false,
                    reminderMessage: nil
                ),
                NoteBlueprint(
                    fraction: 0.9,
                    type: .general,
                    title: "Use Winchester garage to skip curb chaos",
                    body: "It is the easiest way to avoid the slow curb lane at dinner time.",
                    isReminder: false,
                    reminderMessage: nil
                )
            ]

        case .palaceToStanford:
            return [
                NoteBlueprint(
                    fraction: 0.36,
                    type: .food,
                    title: "Philz Palo Alto is a clean stretch stop",
                    body: "A useful coffee break if you are making a longer peninsula errand run.",
                    isReminder: false,
                    reminderMessage: nil
                ),
                NoteBlueprint(
                    fraction: 0.58,
                    type: .roadQuality,
                    title: "Patched pavement near 3rd Street",
                    body: "This section explains most of the extra bump activity on the southbound leg.",
                    isReminder: false,
                    reminderMessage: nil
                ),
                NoteBlueprint(
                    fraction: 0.86,
                    type: .reminder,
                    title: "Start parking payment before walking away",
                    body: "Easy to forget when the lots are busy near Stanford.",
                    isReminder: true,
                    reminderMessage: "Open your parking app before you leave the car."
                )
            ]
        }
    }

    static func coordinate(at fraction: Double, in coordinates: [SerializableCoordinate]) -> SerializableCoordinate {
        guard !coordinates.isEmpty else {
            return SerializableCoordinate(latitude: palaceCoordinate.latitude, longitude: palaceCoordinate.longitude)
        }

        let clampedFraction = min(max(fraction, 0), 1)
        let index = min(
            max(Int((Double(coordinates.count - 1) * clampedFraction).rounded()), 0),
            coordinates.count - 1
        )
        return coordinates[index]
    }

    static func tripUUID(for sequence: Int) -> UUID? {
        UUID(uuidString: String(format: "F1000000-0000-0000-0000-%012d", sequence))
    }

    static func noteUUID(for tripSequence: Int, noteIndex: Int) -> UUID {
        UUID(uuidString: String(format: "F2000000-0000-0000-0000-%012d", tripSequence * 10 + noteIndex + 1))!
    }

    static func placeReminderUUID(for sequence: Int) -> UUID {
        UUID(uuidString: String(format: "F3000000-0000-0000-0000-%012d", sequence))!
    }

    static func drivingBehaviorText(for blueprint: TripBlueprint) -> String {
        let totalEvents = blueprint.hardBrakes + blueprint.sharpTurns + blueprint.aggressiveAccels

        if totalEvents <= 4 {
            return "Inputs stayed calm overall, with only minor corrections around busy merge points."
        }

        if totalEvents <= 7 {
            return "A couple of merges forced more steering and braking than ideal, but the drive still looked controlled."
        }

        return "Traffic pressure pushed braking and lane-change effort higher than usual, especially through the busiest interchange sections."
    }

    static func fuelInsightText(for blueprint: TripBlueprint,
                                mpg: Double,
                                gallons: Double,
                                fuelCost: Double) -> String {
        String(
            format: "At %.1f MPG, this %@ used about %.2f gallons. With local fuel near $%.2f/gal, that works out to roughly $%.2f.",
            mpg,
            blueprint.routeKey.label.lowercased(),
            gallons,
            blueprint.pricePerGallon,
            fuelCost
        )
    }

    static func roadImpactText(for blueprint: TripBlueprint, roadCallout: String) -> String {
        if blueprint.bumpsDetected == 0 {
            return "Road quality stayed smooth for most of this drive, with no notable bump spikes."
        }

        if blueprint.bumpsDetected == 1 {
            return "Only minor road-surface noise showed up, mostly around \(roadCallout.lowercased())."
        }

        return "Most of the rough-road signal came from \(roadCallout.lowercased()), which matches the saved route notes."
    }

    static func brakeWearText(for blueprint: TripBlueprint) -> String {
        if blueprint.hardBrakes <= 1 {
            return "Brake load looked light on this trip."
        }

        if blueprint.hardBrakes <= 3 {
            return "Nothing alarming here, but the repeated slowdowns added a little extra brake heat."
        }

        return "This drive leaned harder on the brakes than your calmer trips, so it is worth keeping an eye on pad wear over time."
    }

    static func mergeTrip(seedTrip: TripResult, existingTrip: TripResult?) -> TripResult {
        guard let existingTrip else { return seedTrip }

        var merged = seedTrip
        merged.aiTripSummary = nonEmpty(existingTrip.aiTripSummary) ?? seedTrip.aiTripSummary
        merged.aiDrivingBehavior = nonEmpty(existingTrip.aiDrivingBehavior) ?? seedTrip.aiDrivingBehavior
        merged.aiFuelInsight = nonEmpty(existingTrip.aiFuelInsight) ?? seedTrip.aiFuelInsight
        merged.aiRoadImpact = nonEmpty(existingTrip.aiRoadImpact) ?? seedTrip.aiRoadImpact
        merged.aiBrakeWear = nonEmpty(existingTrip.aiBrakeWear) ?? seedTrip.aiBrakeWear
        merged.aiOverallTip = nonEmpty(existingTrip.aiOverallTip) ?? seedTrip.aiOverallTip
        return merged
    }

    static func mergeRoute(seedRoute: TripRoute, existingRoute: TripRoute?) -> TripRoute {
        guard let existingRoute else { return seedRoute }

        var merged = seedRoute
        merged.notes = mergeRouteNotes(seedNotes: seedRoute.notes, existingNotes: existingRoute.notes)
        return merged
    }

    static func mergePlace(seedPlace: SavedPlace, existingPlace: SavedPlace?) -> SavedPlace {
        guard let existingPlace else { return seedPlace }

        var merged = seedPlace
        merged.name = existingPlace.name
        merged.category = existingPlace.category
        merged.customLabel = existingPlace.customLabel ?? seedPlace.customLabel
        merged.tripIds = Array(Set(seedPlace.tripIds + existingPlace.tripIds)).sorted { $0.uuidString < $1.uuidString }
        merged.reminders = mergePlaceReminders(seedReminders: seedPlace.reminders, existingReminders: existingPlace.reminders)
        merged.createdAt = min(seedPlace.createdAt, existingPlace.createdAt)
        merged.lastVisited = [seedPlace.lastVisited, existingPlace.lastVisited].compactMap { $0 }.max()
        return merged
    }

    static func mergeRouteNotes(seedNotes: [RouteNote], existingNotes: [RouteNote]) -> [RouteNote] {
        var mergedById = Dictionary(uniqueKeysWithValues: seedNotes.map { ($0.id, $0) })

        for note in existingNotes where mergedById[note.id] == nil {
            mergedById[note.id] = note
        }

        return mergedById.values.sorted { $0.createdAt < $1.createdAt }
    }

    static func mergePlaceReminders(seedReminders: [PlaceReminder], existingReminders: [PlaceReminder]) -> [PlaceReminder] {
        var mergedById = Dictionary(uniqueKeysWithValues: seedReminders.map { ($0.id, $0) })

        for reminder in existingReminders {
            mergedById[reminder.id] = reminder
        }

        return mergedById.values.sorted { $0.createdAt < $1.createdAt }
    }

    static func nonEmpty(_ value: String?) -> String? {
        guard let trimmed = value?.trimmingCharacters(in: .whitespacesAndNewlines), !trimmed.isEmpty else {
            return nil
        }
        return trimmed
    }

    static func upsert(place: SavedPlace, into store: SavedPlacesStore) {
        if store.places.contains(where: { $0.id == place.id }) {
            store.update(place)
        } else {
            store.add(place)
        }
    }
}

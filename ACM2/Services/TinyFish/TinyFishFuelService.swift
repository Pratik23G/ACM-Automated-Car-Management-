import Foundation
import CoreLocation

struct TinyFishFuelService {
    let apiKey: String

    func buildReport(vehicle: VehicleProfile?,
                     trips: [TripResult],
                     routes: [TripRoute],
                     places: [SavedPlace],
                     priorSnapshots: [FuelPriceSnapshot]) async throws -> FuelIntelligenceReport {
        let cleanedKey = apiKey.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !cleanedKey.isEmpty, cleanedKey != "ADD_YOUR_KEY_LOCALLY" else {
            throw TinyFishFuelError.missingAPIKey
        }

        guard let vehicle else {
            throw TinyFishFuelError.noVehicleProfile
        }

        guard vehicle.fuelType != .electric else {
            throw TinyFishFuelError.electricVehicleNotSupported
        }

        let mpg = vehicle.mpg ?? recentAverageMPG(from: trips)
        guard mpg > 0 else {
            throw TinyFishFuelError.missingEfficiency
        }

        let completedRoutes = routes.filter { $0.endedAt != nil && !$0.coordinates.isEmpty }
        guard !completedRoutes.isEmpty else {
            throw TinyFishFuelError.noRouteData
        }

        let center = drivingZoneCenter(from: completedRoutes)
        let areaLabel = await areaLabel(near: center)
        let commonRoutes = commonRouteSummaries(from: places, trips: trips)
        let weeklyMileage = recentWeeklyMileage(from: trips)
        let query = buildSearchQuery(areaLabel: areaLabel, routeHints: commonRoutes)

        let searchResponse = try await search(query: query, apiKey: cleanedKey)
        let candidates = prioritizedCandidates(from: searchResponse.results)
        guard !candidates.isEmpty else {
            throw TinyFishFuelError.noSearchResults
        }

        var extractedStations: [FuelStationPrice] = []
        var winningSourceURL: String?

        for candidate in candidates.prefix(3) {
            if let extraction = try await extractStations(from: candidate.url, areaLabel: areaLabel, apiKey: cleanedKey) {
                extractedStations = await fillMissingDistances(in: extraction.stations, relativeTo: center)
                winningSourceURL = candidate.url
                if !extractedStations.isEmpty { break }
            }
        }

        guard !extractedStations.isEmpty, let sourceURL = winningSourceURL else {
            throw TinyFishFuelError.noStationPricesFound
        }

        let sortedStations = extractedStations.sorted { $0.pricePerGallon < $1.pricePerGallon }
        guard let cheapestStation = sortedStations.first else {
            throw TinyFishFuelError.noStationPricesFound
        }

        let localAverage = sortedStations.map(\.pricePerGallon).reduce(0, +) / Double(sortedStations.count)
        let snapshot = FuelPriceSnapshot(
            capturedAt: Date(),
            areaLabel: areaLabel,
            query: query,
            sourceURL: sourceURL,
            stations: sortedStations,
            localAveragePrice: localAverage
        )

        let previousSnapshot = mostRecentComparableSnapshot(for: areaLabel, from: priorSnapshots)
        let deltaVsPrevious = previousSnapshot.map { localAverage - $0.localAveragePrice }
        let averageProjection = buildProjection(weeklyMileage: weeklyMileage, pricePerGallon: localAverage, mpg: mpg)
        let cheapestProjection = buildProjection(weeklyMileage: weeklyMileage, pricePerGallon: cheapestStation.pricePerGallon, mpg: mpg)

        let priceTrendSummary = buildTrendSummary(
            areaLabel: areaLabel,
            localAverage: localAverage,
            deltaVsPrevious: deltaVsPrevious,
            previousSnapshot: previousSnapshot
        )
        let savingsEstimate = buildSavingsEstimate(
            cheapestStation: cheapestStation,
            localAverage: localAverage,
            weeklyMileage: weeklyMileage,
            mpg: mpg
        )
        let recommendation = buildRecommendation(
            cheapestStation: cheapestStation,
            stations: sortedStations,
            localAverage: localAverage,
            deltaVsPrevious: deltaVsPrevious,
            weeklyMileage: weeklyMileage,
            mpg: mpg
        )
        let spokenBrief = buildSpokenBrief(
            areaLabel: areaLabel,
            priceTrendSummary: priceTrendSummary,
            recommendation: recommendation,
            savingsEstimate: savingsEstimate
        )

        return FuelIntelligenceReport(
            areaLabel: areaLabel,
            query: query,
            commonRoutes: commonRoutes,
            recentWeeklyMileage: weeklyMileage,
            sourceURL: sourceURL,
            sources: Array(candidates.prefix(5)),
            snapshot: snapshot,
            cheapestStation: cheapestStation,
            localAveragePrice: localAverage,
            deltaVsPreviousSnapshot: deltaVsPrevious,
            priceTrendSummary: priceTrendSummary,
            recommendation: recommendation,
            savingsEstimate: savingsEstimate,
            spokenBrief: spokenBrief,
            averageProjection: averageProjection,
            cheapestProjection: cheapestProjection
        )
    }
}

private extension TinyFishFuelService {
    struct TinyFishSearchResponse: Decodable {
        let query: String
        let results: [TinyFishSearchResult]
    }

    struct TinyFishSearchResult: Decodable {
        let siteName: String
        let title: String
        let snippet: String
        let url: String
    }

    struct TinyFishAutomationResponse: Decodable {
        let status: String?
        let result: TinyFishStationExtraction?
        let error: TinyFishAutomationErrorPayload?
    }

    struct TinyFishAutomationErrorPayload: Decodable {
        let code: String?
        let message: String?
    }

    struct TinyFishStationExtraction: Decodable {
        let areaSummary: String?
        let stations: [TinyFishStation]
    }

    struct TinyFishStation: Decodable {
        let name: String
        let brand: String?
        let address: String?
        let pricePerGallon: Double?
        let priceDisplay: String?
        let distanceMiles: Double?
        let sourceNote: String?
    }

    func search(query: String, apiKey: String) async throws -> TinyFishSearchResponse {
        guard var components = URLComponents(string: "https://api.search.tinyfish.ai") else {
            throw TinyFishFuelError.invalidSearchURL
        }
        components.queryItems = [
            URLQueryItem(name: "query", value: query),
            URLQueryItem(name: "location", value: "US"),
            URLQueryItem(name: "language", value: "en")
        ]

        guard let url = components.url else {
            throw TinyFishFuelError.invalidSearchURL
        }

        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.setValue(apiKey, forHTTPHeaderField: "X-API-Key")

        let (data, response) = try await URLSession.shared.data(for: request)
        try validateHTTP(response: response, data: data, serviceName: "TinyFish Search")

        let decoder = JSONDecoder()
        decoder.keyDecodingStrategy = .convertFromSnakeCase
        return try decoder.decode(TinyFishSearchResponse.self, from: data)
    }

    func extractStations(from urlString: String,
                         areaLabel: String,
                         apiKey: String) async throws -> TinyFishStationExtraction? {
        guard let url = URL(string: "https://agent.tinyfish.ai/v1/automation/run") else {
            throw TinyFishFuelError.invalidAgentURL
        }

        let goal = """
        Extract up to 8 nearby gas stations relevant to drivers in \(areaLabel).
        Return ONLY JSON using this exact shape:
        {
          "area_summary": "string",
          "stations": [
            {
              "name": "string",
              "brand": "string",
              "address": "string",
              "price_per_gallon": number,
              "price_display": "string",
              "distance_miles": number or null,
              "source_note": "string"
            }
          ]
        }
        Rules:
        - Only include stations with a visible current regular gasoline price.
        - Ignore premium, diesel, EV charging, membership ads, and missing-price rows.
        - Convert prices like $4.89 into 4.89 for price_per_gallon.
        - Use null for distance_miles when the page does not show distance.
        - Use empty strings for missing text fields.
        """

        let payload: [String: Any] = [
            "url": urlString,
            "goal": goal,
            "browser_profile": "lite",
            "api_integration": "codex-fuel-demo",
            "agent_config": [
                "mode": "strict",
                "max_steps": 35
            ],
            "proxy_config": [
                "enabled": true,
                "type": "tetra",
                "country_code": "US"
            ]
        ]

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue(apiKey, forHTTPHeaderField: "X-API-Key")
        request.httpBody = try JSONSerialization.data(withJSONObject: payload, options: [])

        let (data, response) = try await URLSession.shared.data(for: request)
        try validateHTTP(response: response, data: data, serviceName: "TinyFish Agent")

        let decoder = JSONDecoder()
        decoder.keyDecodingStrategy = .convertFromSnakeCase
        let decoded = try decoder.decode(TinyFishAutomationResponse.self, from: data)

        if let errorMessage = decoded.error?.message, !errorMessage.isEmpty {
            throw TinyFishFuelError.agentFailure(errorMessage)
        }

        guard let extraction = decoded.result else { return nil }

        let mappedStations = extraction.stations.compactMap { station -> FuelStationPrice? in
            guard let price = station.pricePerGallon, price > 0 else { return nil }
            return FuelStationPrice(
                name: station.name.trimmingCharacters(in: .whitespacesAndNewlines).nilIfEmpty ?? "Unknown Station",
                brand: station.brand?.trimmingCharacters(in: .whitespacesAndNewlines) ?? "",
                address: station.address?.trimmingCharacters(in: .whitespacesAndNewlines) ?? "",
                pricePerGallon: price,
                priceDisplay: station.priceDisplay?.trimmingCharacters(in: .whitespacesAndNewlines) ?? String(format: "$%.2f", price),
                distanceMiles: station.distanceMiles,
                sourceNote: station.sourceNote?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
            )
        }

        return TinyFishStationExtraction(areaSummary: extraction.areaSummary, stations: mappedStations.map {
            TinyFishStation(
                name: $0.name,
                brand: $0.brand,
                address: $0.address,
                pricePerGallon: $0.pricePerGallon,
                priceDisplay: $0.priceDisplay,
                distanceMiles: $0.distanceMiles,
                sourceNote: $0.sourceNote
            )
        })
    }

    func prioritizedCandidates(from results: [TinyFishSearchResult]) -> [FuelSourceResult] {
        let priorities = ["gasbuddy.com", "mapquest.com", "autoblog.com", "aaa.com", "way.com"]

        return results
            .map {
                FuelSourceResult(
                    title: $0.title,
                    url: $0.url,
                    snippet: $0.snippet,
                    siteName: $0.siteName
                )
            }
            .sorted { lhs, rhs in
                let leftRank = priorities.firstIndex(where: { lhs.url.contains($0) }) ?? priorities.count
                let rightRank = priorities.firstIndex(where: { rhs.url.contains($0) }) ?? priorities.count
                if leftRank == rightRank {
                    return lhs.title < rhs.title
                }
                return leftRank < rightRank
            }
    }

    func validateHTTP(response: URLResponse, data: Data, serviceName: String) throws {
        guard let http = response as? HTTPURLResponse else {
            throw TinyFishFuelError.invalidHTTPResponse
        }

        guard (200...299).contains(http.statusCode) else {
            let body = String(data: data, encoding: .utf8) ?? ""
            throw TinyFishFuelError.httpError(service: serviceName, status: http.statusCode, body: body)
        }
    }

    func recentAverageMPG(from trips: [TripResult]) -> Double {
        let values = trips.prefix(8).map(\.mpg).filter { $0 > 0 }
        guard !values.isEmpty else { return 0 }
        return values.reduce(0, +) / Double(values.count)
    }

    func drivingZoneCenter(from routes: [TripRoute]) -> SerializableCoordinate {
        let allCoordinates = routes
            .sorted {
                ($0.endedAt ?? $0.startedAt) > ($1.endedAt ?? $1.startedAt)
            }
            .prefix(12)
            .flatMap(\.coordinates)

        let sampled = stride(from: 0, to: allCoordinates.count, by: max(1, allCoordinates.count / 80)).map {
            allCoordinates[$0]
        }

        let count = max(Double(sampled.count), 1)
        let avgLat = sampled.map(\.latitude).reduce(0, +) / count
        let avgLon = sampled.map(\.longitude).reduce(0, +) / count
        return SerializableCoordinate(latitude: avgLat, longitude: avgLon)
    }

    func areaLabel(near center: SerializableCoordinate) async -> String {
        let location = CLLocation(latitude: center.latitude, longitude: center.longitude)
        let geocoder = CLGeocoder()

        do {
            let placemarks = try await reverseGeocode(location, geocoder: geocoder)
            if let place = placemarks.first {
                let city = place.locality ?? place.subLocality
                let state = place.administrativeArea
                if let city, let state {
                    return "\(city), \(state)"
                }
                if let city { return city }
            }
        } catch {
            print("⚠️ TinyFishFuelService reverse geocode failed:", error)
        }

        return String(format: "%.3f, %.3f", center.latitude, center.longitude)
    }

    func reverseGeocode(_ location: CLLocation, geocoder: CLGeocoder) async throws -> [CLPlacemark] {
        try await withCheckedThrowingContinuation { continuation in
            geocoder.reverseGeocodeLocation(location) { placemarks, error in
                if let error {
                    continuation.resume(throwing: error)
                } else {
                    continuation.resume(returning: placemarks ?? [])
                }
            }
        }
    }

    func geocodeAddress(_ address: String) async -> CLLocation? {
        let geocoder = CLGeocoder()
        return await withCheckedContinuation { continuation in
            geocoder.geocodeAddressString(address) { placemarks, _ in
                continuation.resume(returning: placemarks?.first?.location)
            }
        }
    }

    func fillMissingDistances(in stations: [TinyFishStation], relativeTo center: SerializableCoordinate) async -> [FuelStationPrice] {
        var filled: [FuelStationPrice] = []

        for rawStation in stations {
            guard let price = rawStation.pricePerGallon, price > 0 else { continue }

            let trimmedName = rawStation.name.trimmingCharacters(in: .whitespacesAndNewlines).nilIfEmpty ?? "Unknown Station"
            let address = rawStation.address?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
            var distance = rawStation.distanceMiles

            if distance == nil, !address.isEmpty, let location = await geocodeAddress(address) {
                let stationCoordinate = SerializableCoordinate(location.coordinate)
                distance = center.distance(to: stationCoordinate) / 1609.34
            }

            filled.append(
                FuelStationPrice(
                    name: trimmedName,
                    brand: rawStation.brand?.trimmingCharacters(in: .whitespacesAndNewlines) ?? "",
                    address: address,
                    pricePerGallon: price,
                    priceDisplay: rawStation.priceDisplay?.trimmingCharacters(in: .whitespacesAndNewlines) ?? String(format: "$%.2f", price),
                    distanceMiles: distance,
                    sourceNote: rawStation.sourceNote?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
                )
            )
        }

        return filled
    }

    func commonRouteSummaries(from places: [SavedPlace], trips: [TripResult]) -> [String] {
        let placeDriven = places
            .compactMap { place -> (String, Int)? in
                guard let pattern = place.pattern(from: trips), pattern.tripCount > 0 else { return nil }
                return ("\(place.displayName) (\(pattern.tripCount) trips)", pattern.tripCount)
            }
            .sorted { $0.1 > $1.1 }
            .prefix(3)
            .map(\.0)

        if !placeDriven.isEmpty {
            return placeDriven
        }

        let recentTrips = trips.prefix(3).compactMap { trip -> String? in
            guard let distance = trip.distanceMiles else { return nil }
            return String(format: "%.0f mi route", distance)
        }
        return Array(recentTrips)
    }

    func recentWeeklyMileage(from trips: [TripResult]) -> Double {
        let recent = trips.filter {
            guard let thirtyDaysAgo = Calendar.current.date(byAdding: .day, value: -30, to: Date()) else { return true }
            return $0.endedAt >= thirtyDaysAgo
        }

        let miles = recent.compactMap(\.distanceMiles).reduce(0, +)
        if miles > 0 {
            return miles / 4.2857
        }

        let fallback = trips.prefix(8).compactMap(\.distanceMiles).reduce(0, +)
        return fallback / max(Double(min(trips.prefix(8).count, 4)), 1)
    }

    func buildSearchQuery(areaLabel: String, routeHints: [String]) -> String {
        let cleanedHints = routeHints
            .prefix(2)
            .map {
                $0.replacingOccurrences(
                    of: #"\s*\(\d+\s+trips\)"#,
                    with: "",
                    options: .regularExpression
                )
            }

        if cleanedHints.count >= 2 {
            return "cheap gas prices along route between \(cleanedHints[0]) and \(cleanedHints[1]) near \(areaLabel)"
        }

        if let hint = cleanedHints.first, !hint.isEmpty {
            return "cheap gas prices near \(areaLabel) \(hint)"
        }

        let routePart = cleanedHints.joined(separator: ", ")
        if routePart.isEmpty {
            return "cheap gas prices near \(areaLabel)"
        }
        return "cheap gas prices near \(areaLabel) \(routePart)"
    }

    func mostRecentComparableSnapshot(for areaLabel: String, from snapshots: [FuelPriceSnapshot]) -> FuelPriceSnapshot? {
        snapshots
            .filter { $0.areaLabel == areaLabel }
            .sorted { $0.capturedAt > $1.capturedAt }
            .first
    }

    func buildProjection(weeklyMileage: Double, pricePerGallon: Double, mpg: Double) -> FuelCostProjection? {
        guard weeklyMileage > 0, pricePerGallon > 0, mpg > 0 else { return nil }
        let weeklyGallons = weeklyMileage / mpg
        return FuelCostProjection(
            weekly: weeklyGallons * pricePerGallon,
            monthly: weeklyGallons * pricePerGallon * 4.33,
            yearly: weeklyGallons * pricePerGallon * 52
        )
    }

    func buildTrendSummary(areaLabel: String,
                           localAverage: Double,
                           deltaVsPrevious: Double?,
                           previousSnapshot: FuelPriceSnapshot?) -> String {
        guard let deltaVsPrevious, let previousSnapshot else {
            return "Today’s sample in your \(areaLabel) driving zone averages \(currency(localAverage))/gal across nearby stations."
        }

        let cents = Int((abs(deltaVsPrevious) * 100).rounded())
        let direction = deltaVsPrevious >= 0 ? "up" : "down"
        let relativeDate = relativeSnapshotDate(previousSnapshot.capturedAt)
        return "In your usual \(areaLabel) driving zone, prices are \(direction) \(cents)¢/gal vs \(relativeDate)."
    }

    func buildSavingsEstimate(cheapestStation: FuelStationPrice,
                              localAverage: Double,
                              weeklyMileage: Double,
                              mpg: Double) -> String {
        let savingsPerGallon = max(localAverage - cheapestStation.pricePerGallon, 0)
        let weeklySavings = (weeklyMileage / mpg) * savingsPerGallon
        let monthlySavings = weeklySavings * 4.33

        if savingsPerGallon <= 0.01 {
            return "Your sampled stations are tightly clustered today, so there’s little savings gap versus the local average."
        }

        let cents = Int((savingsPerGallon * 100).rounded())
        return "The cheapest station in range is \(cents)¢/gal below your sampled local average, worth about \(currency(monthlySavings))/month at your recent mileage."
    }

    func buildRecommendation(cheapestStation: FuelStationPrice,
                             stations: [FuelStationPrice],
                             localAverage: Double,
                             deltaVsPrevious: Double?,
                             weeklyMileage: Double,
                             mpg: Double) -> String {
        let savingsPerGallon = max(localAverage - cheapestStation.pricePerGallon, 0)
        let monthlySavings = (weeklyMileage / mpg) * savingsPerGallon * 4.33
        let priciest = stations.max(by: { $0.pricePerGallon < $1.pricePerGallon })

        if let deltaVsPrevious, deltaVsPrevious >= 0.15 {
            return "Fill tonight if you need gas soon. Your area’s average is climbing, and \(cheapestStation.name) is currently the best-priced option."
        }

        if savingsPerGallon >= 0.20 {
            return "Avoid the pricier stations in your usual area. Switching to \(cheapestStation.name) could trim roughly \(currency(monthlySavings)) off this month."
        }

        if let priciest, priciest.pricePerGallon - cheapestStation.pricePerGallon >= 0.25 {
            return "Skip the expensive outliers on this route. \(cheapestStation.name) is meaningfully cheaper than the highest-priced nearby option today."
        }

        return "No rush to fill immediately. Prices are fairly stable right now, but \(cheapestStation.name) is still the best current stop."
    }

    func buildSpokenBrief(areaLabel: String,
                          priceTrendSummary: String,
                          recommendation: String,
                          savingsEstimate: String) -> String {
        "\(priceTrendSummary) \(recommendation) \(savingsEstimate)"
    }

    func relativeSnapshotDate(_ date: Date) -> String {
        if Calendar.current.isDateInToday(date) {
            return "earlier today"
        }
        if Calendar.current.isDateInYesterday(date) {
            return "yesterday"
        }

        let days = Calendar.current.dateComponents([.day], from: date, to: Date()).day ?? 0
        if days <= 7 {
            return "\(days) days ago"
        }

        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        return formatter.string(from: date)
    }

    func currency(_ value: Double) -> String {
        String(format: "$%.2f", value)
    }
}

enum TinyFishFuelError: LocalizedError {
    case missingAPIKey
    case noVehicleProfile
    case electricVehicleNotSupported
    case missingEfficiency
    case noRouteData
    case noSearchResults
    case noStationPricesFound
    case invalidSearchURL
    case invalidAgentURL
    case invalidHTTPResponse
    case httpError(service: String, status: Int, body: String)
    case agentFailure(String)

    var errorDescription: String? {
        switch self {
        case .missingAPIKey:
            return "Missing TinyFish API key (TINYFISH_API_KEY)."
        case .noVehicleProfile:
            return "Add a vehicle before running fuel intelligence."
        case .electricVehicleNotSupported:
            return "This first TinyFish demo is wired for gasoline, diesel, and hybrid vehicles. EV charging support is the next step."
        case .missingEfficiency:
            return "Set your vehicle MPG before running the fuel demo."
        case .noRouteData:
            return "Record at least one route so the demo can infer your real driving area."
        case .noSearchResults:
            return "TinyFish Search didn’t return a usable local fuel source."
        case .noStationPricesFound:
            return "TinyFish found sources, but none produced current station prices."
        case .invalidSearchURL:
            return "TinyFish Search URL could not be built."
        case .invalidAgentURL:
            return "TinyFish Agent URL could not be built."
        case .invalidHTTPResponse:
            return "TinyFish returned an invalid HTTP response."
        case .httpError(let service, let status, let body):
            return "\(service) HTTP \(status): \(body)"
        case .agentFailure(let message):
            return "TinyFish Agent failed: \(message)"
        }
    }
}

private extension String {
    var nilIfEmpty: String? {
        isEmpty ? nil : self
    }
}

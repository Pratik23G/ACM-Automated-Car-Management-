import Foundation

struct OpenAIClient {
    let apiKey: String
    var model: String = "gpt-4o-mini"

    // MARK: - Public API

    func generateTripSummary(trip: TripResult, vehicle: VehicleProfile?, recentTrips: [TripResult]) async throws -> TripAISummary {
        let system = """
        You are an automotive + driving analytics assistant.
        Return ONLY valid JSON that matches the provided schema. No extra keys. No markdown.
        """

        let user = buildTripPrompt(trip: trip, vehicle: vehicle, recentTrips: Array(recentTrips.suffix(5)))

        let schema: [String: Any] = [
            "type": "object",
            "additionalProperties": false,
            "properties": [
                "tripSummary":      ["type": "string"],
                "drivingBehavior":  ["type": "string"],
                "fuelInsight":      ["type": "string"],
                "roadImpact":       ["type": "string"],
                "brakeWear":        ["type": "string"],
                "overallTip":       ["type": "string"]
            ],
            "required": ["tripSummary", "drivingBehavior", "fuelInsight", "roadImpact", "brakeWear", "overallTip"]
        ]

        return try await requestJSONSchema(
            schemaName: "TripAISummary",
            schema: schema,
            system: system,
            user: user,
            maxOutputTokens: 900
        )
    }

    // Back-compat name (if you called it before)
    func generateSummary(trip: TripResult, vehicle: VehicleProfile?, recentTrips: [TripResult]) async throws -> TripAISummary {
        try await generateTripSummary(trip: trip, vehicle: vehicle, recentTrips: recentTrips)
    }

    func triageCarIssue(issueText: String, vehicle: VehicleProfile?) async throws -> CarIssueTriage {
        let system = """
        You are a car issue triage assistant.
        Ask ZERO follow-up questions. Use the provided info only.
        Return ONLY valid JSON that matches the provided schema. No extra keys. No markdown.
        """

        let user = buildCarIssuePrompt(issueText: issueText, vehicle: vehicle)

        let schema: [String: Any] = [
            "type": "object",
            "additionalProperties": false,
            "properties": [
                "title":         ["type": "string"],
                "urgency":       ["type": "string"],
                "likelyCauses":  ["type": "array", "items": ["type": "string"]],
                "checksYouCanDo":["type": "array", "items": ["type": "string"]],
                "nextSteps":     ["type": "array", "items": ["type": "string"]],
                "safetyNotes":   ["type": "array", "items": ["type": "string"]]
            ],
            "required": ["title","urgency","likelyCauses","checksYouCanDo","nextSteps","safetyNotes"]
        ]

        return try await requestJSONSchema(
            schemaName: "CarIssueTriage",
            schema: schema,
            system: system,
            user: user,
            maxOutputTokens: 900
        )
    }

    // Back-compat label variants
    func triageCarIssue(issue: String, vehicle: VehicleProfile?) async throws -> CarIssueTriage {
        try await triageCarIssue(issueText: issue, vehicle: vehicle)
    }

    // MARK: - Fuel Coach

    func generateFuelCoachBrief(
        question: String,
        vehicle: VehicleProfile?,
        trips: [TripResult],
        fuelLogs: [FuelLog],
        marketUpdates: [FuelMarketUpdate]
    ) async throws -> FuelCoachBrief {
        let system = """
        You are a fuel savings and driving-cost co-pilot.
        Return ONLY valid JSON matching the provided schema. No markdown. No extra keys.
        Keep the advice specific, practical, and grounded in the supplied driving and fuel data.
        """

        let schema: [String: Any] = [
            "type": "object",
            "additionalProperties": false,
            "properties": [
                "summary": ["type": "string"],
                "pricingOutlook": ["type": "string"],
                "efficiencyDiagnosis": ["type": "string"],
                "actionPlan": ["type": "array", "items": ["type": "string"]]
            ],
            "required": ["summary", "pricingOutlook", "efficiencyDiagnosis", "actionPlan"]
        ]

        return try await requestJSONSchema(
            schemaName: "FuelCoachBrief",
            schema: schema,
            system: system,
            user: buildFuelCoachPrompt(
                question: question,
                vehicle: vehicle,
                trips: trips,
                fuelLogs: fuelLogs,
                marketUpdates: marketUpdates
            ),
            maxOutputTokens: 900
        )
    }

    // MARK: - Drive DNA

    func generateDriveDNA(dna: DriveDNA, vehicle: VehicleProfile?) async throws -> DriveDNAInsights {
        let system = """
        You are an automotive driving behavior analyst.
        Return ONLY valid JSON matching the provided schema. No markdown. No extra keys.
        Write in second person ("You tend to…"). Be specific, honest, and concise (1-2 sentences per field).
        """
        let user = dna.buildPrompt(vehicle: vehicle)
        let schema: [String: Any] = [
            "type": "object",
            "additionalProperties": false,
            "properties": [
                "headline":       ["type": "string"],
                "topPattern":     ["type": "string"],
                "timeInsight":    ["type": "string"],
                "dayInsight":     ["type": "string"],
                "strengthNote":   ["type": "string"],
                "improvementTip": ["type": "string"]
            ],
            "required": ["headline","topPattern","timeInsight","dayInsight","strengthNote","improvementTip"]
        ]
        return try await requestJSONSchema(
            schemaName: "DriveDNAInsights", schema: schema,
            system: system, user: user, maxOutputTokens: 700)
    }

    // MARK: - Pre-Trip Brief

    func generatePreTripBrief(destination: String, timeSlot: String,
                               dna: DriveDNA, routeNotes: [RouteNote],
                               vehicle: VehicleProfile?) async throws -> PreTripBrief {
        let system = """
        You are a driving co-pilot assistant. Give a concise, practical pre-trip briefing.
        Return ONLY valid JSON matching the provided schema. No markdown. No extra keys.
        Be specific to the driver's actual data. Keep each field to 1-2 sentences max.
        """

        var lines: [String] = []
        lines.append("Driver is heading to: \(destination)")
        lines.append("Current time of day: \(timeSlot)")

        if let v = vehicle {
            lines.append("Vehicle: \(v.displayName), \(v.fuelType.label)")
            if let mpg = v.mpg { lines.append("MPG: \(String(format: "%.1f", mpg))") }
        }

        lines.append("\nDriver stats:")
        lines.append("- Driving style: \(dna.fingerprintLabel)")
        lines.append("- Avg aggression/trip: \(String(format: "%.1f", dna.avgAggression))")
        lines.append("- Avg hard brakes/trip: \(String(format: "%.1f", dna.avgHardBrakesPerTrip))")
        lines.append("- Avg aggressive accels/trip: \(String(format: "%.1f", dna.avgAggressiveAccelsPerTrip))")
        lines.append("- Worst driving time: \(dna.byTime.filter { $0.tripCount > 0 }.max(by: { $0.avgAggression < $1.avgAggression })?.slot.rawValue ?? "unknown")")

        if !routeNotes.isEmpty {
            lines.append("\nSaved hazards and reminders from past trips:")
            for note in routeNotes.prefix(8) {
                lines.append("- [\(note.type.label)] \(note.title): \(note.body)")
            }
        } else {
            lines.append("\nNo saved hazards on record.")
        }

        lines.append("\nFor fuelEstimate: estimate cost for a typical trip to this destination (assume 15-30 miles if unknown). Use vehicle MPG and $4.50/gallon if gasoline.")
        lines.append("For knownHazards: list only hazards relevant to the destination/route from the saved notes. Empty array if none.")
        lines.append("For behaviorWarning: reference the driver's specific habits (hard brakes, time of day) as they apply to this trip.")

        let schema: [String: Any] = [
            "type": "object",
            "additionalProperties": false,
            "properties": [
                "summary":         ["type": "string"],
                "behaviorWarning": ["type": "string"],
                "knownHazards":    ["type": "array", "items": ["type": "string"]],
                "fuelEstimate":    ["type": "string"],
                "tip":             ["type": "string"]
            ],
            "required": ["summary","behaviorWarning","knownHazards","fuelEstimate","tip"]
        ]

        return try await requestJSONSchema(
            schemaName: "PreTripBrief", schema: schema,
            system: system, user: lines.joined(separator: "\n"), maxOutputTokens: 700)
    }

    // MARK: - Core request (Responses API + Structured Outputs)

    private func requestJSONSchema<T: Decodable>(
        schemaName: String,
        schema: [String: Any],
        system: String,
        user: String,
        maxOutputTokens: Int
    ) async throws -> T {
        guard !apiKey.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            throw OpenAIClientError.missingAPIKey
        }

        let url = URL(string: "https://api.openai.com/v1/responses")!

        let body: [String: Any] = [
            "model": model,
            "max_output_tokens": maxOutputTokens,
            "input": [
                ["role": "system", "content": system],
                ["role": "user", "content": user]
            ],
            "text": [
                "format": [
                    "type": "json_schema",
                    "name": schemaName,
                    "schema": schema,
                    "strict": true
                ]
            ]
        ]

        let data = try JSONSerialization.data(withJSONObject: body, options: [])

        var req = URLRequest(url: url)
        req.httpMethod = "POST"
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        req.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        req.httpBody = data

        let (respData, resp) = try await URLSession.shared.data(for: req)

        guard let http = resp as? HTTPURLResponse else {
            throw OpenAIClientError.invalidHTTPResponse
        }

        // If OpenAI returns an error JSON, surface it
        if !(200...299).contains(http.statusCode) {
            let raw = String(data: respData, encoding: .utf8) ?? ""
            let message = decodeAPIErrorMessage(from: respData) ?? raw
            throw OpenAIClientError.httpError(status: http.statusCode, message: message)
        }

        let rawString = String(data: respData, encoding: .utf8) ?? ""

        let decoded = try JSONDecoder().decode(ResponsesAPIResponse.self, from: respData)

        if let apiError = decoded.error?.message, !apiError.isEmpty {
            throw OpenAIClientError.apiError(apiError)
        }

        guard let text = decoded.firstOutputText(), !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            throw OpenAIClientError.emptyAssistantContent(raw: rawString)
        }

        // First attempt: direct decode
        if let obj = try? JSONDecoder().decode(T.self, from: Data(text.utf8)) {
            return obj
        }

        // Fallback: extract first {...} block
        if let extracted = extractJSONObject(from: text),
           let obj2 = try? JSONDecoder().decode(T.self, from: Data(extracted.utf8)) {
            return obj2
        }

        throw OpenAIClientError.jsonDecodeFailed(content: text, raw: rawString)
    }

    private func decodeAPIErrorMessage(from data: Data) -> String? {
        if let decoded = try? JSONDecoder().decode(OpenAIErrorEnvelope.self, from: data) {
            return decoded.error.message
        }
        return nil
    }

    private func extractJSONObject(from text: String) -> String? {
        guard let start = text.firstIndex(of: "{"),
              let end = text.lastIndex(of: "}") else { return nil }
        return String(text[start...end])
    }

    // MARK: - Prompt builders

    private func buildTripPrompt(trip: TripResult, vehicle: VehicleProfile?, recentTrips: [TripResult]) -> String {
        var lines: [String] = []

        lines.append("Create a post-drive summary using ONLY the data below.")
        lines.append("")
        lines.append("TRIP DATA:")
        lines.append("- durationSeconds: \(trip.durationSeconds)")
        lines.append("- distanceMiles: \(trip.distanceMiles.map { String(format: "%.2f", $0) } ?? "nil")")
        lines.append("- avgSpeedMph: \(trip.avgSpeedMph.map { String(format: "%.1f", $0) } ?? "nil")")
        lines.append("- maxSpeedMph: \(trip.maxSpeedMph.map { String(format: "%.1f", $0) } ?? "nil")")
        lines.append("- hardBrakes: \(trip.hardBrakes)")
        lines.append("- sharpTurns: \(trip.sharpTurns)")
        lines.append("- aggressiveAccels: \(trip.aggressiveAccels)")
        lines.append("- bumpsDetected: \(trip.bumpsDetected)")
        lines.append("- mpg: \(String(format: "%.1f", trip.mpg))")
        lines.append("- estimatedGallons: \(trip.estimatedGallons.map { String(format: "%.3f", $0) } ?? "nil")")
        lines.append("- estimatedFuelCost: \(trip.estimatedFuelCost.map { String(format: "%.2f", $0) } ?? "nil")")
        lines.append("")

        lines.append("VEHICLE PROFILE (may be empty):")
        if let vehicle {
            lines.append("- make: \(vehicle.make)")
            lines.append("- model: \(vehicle.model)")
            lines.append("- year: \(vehicle.year)")
            lines.append("- fuelType: \(vehicle.fuelType.rawValue)")
            lines.append("- mpg: \(vehicle.mpg.map { String(format: "%.1f", $0) } ?? "nil")")
            lines.append("- miPerKwh: \(vehicle.miPerKwh.map { String(format: "%.2f", $0) } ?? "nil")")
            if let d = vehicle.brakePadsInstalledAt {
                lines.append("- brakePadsInstalledAt: \(d.ISO8601Format())")
            } else {
                lines.append("- brakePadsInstalledAt: nil")
            }
        } else {
            lines.append("nil")
        }

        if !recentTrips.isEmpty {
            lines.append("")
            lines.append("RECENT TRIPS (most recent first, up to 5):")
            for (i, t) in recentTrips.enumerated() {
                let dist = t.distanceMiles.map { String(format: "%.2f", $0) } ?? "nil"
                lines.append("\(i+1)) distance=\(dist) mi, hardBrakes=\(t.hardBrakes), sharpTurns=\(t.sharpTurns), bumps=\(t.bumpsDetected)")
            }
        }

        lines.append("")
        lines.append("STYLE:")
        lines.append("- Be concise, practical, and realistic.")
        lines.append("- If something is missing, don’t invent it—just speak generally.")
        lines.append("- Mention braking/turning smoothness if events indicate it.")
        lines.append("- For brakeWear: estimate risk/extra wear based on hard braking + sharp turns and the brake pad install date (if provided).")

        return lines.joined(separator: "\n")
    }

    private func buildCarIssuePrompt(issueText: String, vehicle: VehicleProfile?) -> String {
        var lines: [String] = []
        lines.append("User issue description:")
        lines.append(issueText)
        lines.append("")
        lines.append("Vehicle profile (may be empty):")
        if let v = vehicle {
            lines.append("- make: \(v.make)")
            lines.append("- model: \(v.model)")
            lines.append("- year: \(v.year)")
            lines.append("- fuelType: \(v.fuelType.rawValue)")
            if let mpg = v.mpg { lines.append("- mpg: \(String(format: "%.1f", mpg))") }
            if let mi = v.miPerKwh { lines.append("- miPerKwh: \(String(format: "%.2f", mi))") }
        } else {
            lines.append("nil")
        }

        lines.append("")
        lines.append("Output:")
        lines.append("- urgency should be one of: Low / Medium / High / Stop Driving")
        lines.append("- likelyCauses: 3–6 items")
        lines.append("- checksYouCanDo: 3–6 quick checks")
        lines.append("- nextSteps: 3–6 steps")
        lines.append("- safetyNotes: 1–4 items")

        return lines.joined(separator: "\n")
    }

    private func buildFuelCoachPrompt(
        question: String,
        vehicle: VehicleProfile?,
        trips: [TripResult],
        fuelLogs: [FuelLog],
        marketUpdates: [FuelMarketUpdate]
    ) -> String {
        var lines: [String] = []
        lines.append("User question:")
        lines.append(question)
        lines.append("")
        lines.append("Vehicle profile:")
        if let v = vehicle {
            lines.append("- vehicle: \(v.displayName)")
            lines.append("- fuelType: \(v.fuelType.label)")
            lines.append("- preferredFuelProduct: \(v.preferredFuelProduct.label)")
            lines.append("- stationPreference: \(v.stationPreference.label)")
            lines.append("- homeArea: \(v.homeArea ?? "unknown")")
            if let mpg = v.mpg { lines.append("- mpg: \(String(format: "%.1f", mpg))") }
            if let miPerKwh = v.miPerKwh { lines.append("- miPerKwh: \(String(format: "%.1f", miPerKwh))") }
        } else {
            lines.append("nil")
        }

        lines.append("")
        lines.append("Recent fuel logs:")
        if fuelLogs.isEmpty {
            lines.append("- none")
        } else {
            for log in fuelLogs.prefix(8) {
                lines.append("- \(log.loggedAt.ISO8601Format()): \(log.stationName), \(log.fuelProduct.label), \(String(format: "$%.2f", log.pricePerUnit))/unit, amount \(String(format: "%.2f", log.amount)), total \(String(format: "$%.2f", log.totalCost))")
            }
        }

        lines.append("")
        lines.append("Recent trips:")
        if trips.isEmpty {
            lines.append("- none")
        } else {
            for trip in trips.prefix(8) {
                lines.append("- trip distance=\(trip.distanceMiles.map { String(format: "%.1f", $0) } ?? "nil") mi, hardBrakes=\(trip.hardBrakes), sharpTurns=\(trip.sharpTurns), aggressiveAccels=\(trip.aggressiveAccels), estimatedFuelCost=\(trip.estimatedFuelCost.map { String(format: "$%.2f", $0) } ?? "nil")")
            }
        }

        lines.append("")
        lines.append("Market updates:")
        if marketUpdates.isEmpty {
            lines.append("- none")
        } else {
            for update in marketUpdates {
                lines.append("- \(update.headline): \(update.summary) [\(update.direction.rawValue)]")
            }
        }

        lines.append("")
        lines.append("Output rules:")
        lines.append("- Explain both pricing and driving-behavior contributors when relevant.")
        lines.append("- actionPlan should contain 2-4 concise steps.")
        lines.append("- If the data is thin, say so directly and recommend logging more station stops.")
        return lines.joined(separator: "\n")
    }

    // MARK: - Place Brief

    func generatePlaceBrief(prompt: String) async throws -> String {
        guard !apiKey.isEmpty else { throw OpenAIClientError.missingAPIKey }
        let url = URL(string: "https://api.openai.com/v1/chat/completions")!
        let system = """
        You are a driving assistant giving a brief before someone leaves for a familiar destination.
        Be direct and practical — 2-3 sentences max.
        Reference their specific data (trip time, cost, driving style, reminders, weather).
        Do NOT use bullet points. Write in plain conversational sentences.
        """
        let payload: [String: Any] = [
            "model": "gpt-4o-mini",
            "max_tokens": 200,
            "messages": [
                ["role": "system", "content": system],
                ["role": "user",   "content": prompt]
            ]
        ]
        var req = URLRequest(url: url)
        req.httpMethod = "POST"
        req.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        req.httpBody = try JSONSerialization.data(withJSONObject: payload)
        let (data, _) = try await URLSession.shared.data(for: req)
        struct Resp: Decodable {
            struct Choice: Decodable {
                struct Msg: Decodable { let content: String }
                let message: Msg
            }
            let choices: [Choice]
        }
        let resp = try JSONDecoder().decode(Resp.self, from: data)
        return resp.choices.first?.message.content
            .trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
    }
}

// MARK: - Decoding helpers

private struct ResponsesAPIResponse: Decodable {
    struct OutputItem: Decodable {
        struct ContentItem: Decodable {
            let type: String
            let text: String?
        }
        let type: String
        let role: String?
        let content: [ContentItem]?
    }

    struct APIError: Decodable {
        let message: String?
    }

    let status: String?
    let error: APIError?
    let output: [OutputItem]?

    func firstOutputText() -> String? {
        guard let output else { return nil }
        for item in output where item.type == "message" {
            if let content = item.content {
                for c in content where c.type == "output_text" {
                    if let t = c.text { return t }
                }
            }
        }
        return nil
    }
}

private struct OpenAIErrorEnvelope: Decodable {
    struct Inner: Decodable {
        let message: String
    }
    let error: Inner
}

enum OpenAIClientError: LocalizedError {
    case missingAPIKey
    case invalidHTTPResponse
    case httpError(status: Int, message: String)
    case apiError(String)
    case emptyAssistantContent(raw: String)
    case jsonDecodeFailed(content: String, raw: String)

    var errorDescription: String? {
        switch self {
        case .missingAPIKey:
            return "Missing OpenAI API key (OPENAI_API_KEY)."
        case .invalidHTTPResponse:
            return "Invalid HTTP response."
        case .httpError(let status, let message):
            return "OpenAI HTTP \(status): \(message)"
        case .apiError(let message):
            return "OpenAI error: \(message)"
        case .emptyAssistantContent:
            return "OpenAI returned empty assistant content."
        case .jsonDecodeFailed:
            return "JSON decode failed."
        }
    }
}

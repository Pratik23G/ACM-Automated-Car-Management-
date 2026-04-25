import Foundation

struct FuelAgentService {

    func buildDashboard(
        profile: VehicleProfile?,
        trips: [TripResult],
        fuelLogs: [FuelLog]
    ) -> FuelDashboard {
        let updates = makeMarketUpdates(profile: profile, trips: trips, fuelLogs: fuelLogs)
        let spendSnapshot = makeSpendSnapshot(from: fuelLogs)

        return FuelDashboard(
            stationInsights: makeStationInsights(profile: profile, fuelLogs: fuelLogs),
            marketUpdates: updates,
            spendSnapshot: spendSnapshot,
            profileSummary: makeProfileSummary(profile),
            efficiencyHeadline: makeEfficiencyHeadline(trips: trips, fuelLogs: fuelLogs),
            suggestedQuestions: makeSuggestedQuestions(profile: profile),
            projectionSummary: makeProjectionSummary(marketUpdates: updates, spendSnapshot: spendSnapshot),
            coordinationNotes: makeCoordinationNotes(profile: profile, trips: trips, fuelLogs: fuelLogs)
        )
    }

    func buildCostSummary(
        period: FuelCostPeriod,
        fuelLogs: [FuelLog]
    ) -> FuelCostSummary {
        guard !fuelLogs.isEmpty else {
            return FuelCostSummary(
                period: period,
                headline: "No fill-up history yet",
                totalSpend: 0,
                fillUpCount: 0,
                averageFillCost: 0,
                averagePricePerUnit: 0,
                dominantStation: nil,
                dominantArea: nil,
                comparisonText: "Use the map logger to start building real cost history.",
                summary: "Once you log a few fill-ups, this tab will turn them into daily, weekly, monthly, and yearly fuel narratives.",
                insights: [
                    "Save station, price, fuel product, and amount after each stop.",
                    "Use promos consistently so the tracker can show when discounts actually changed your costs."
                ],
                buckets: [],
                logs: []
            )
        }

        let grouped = Dictionary(grouping: fuelLogs, by: { bucketStart(for: $0.loggedAt, period: period) })
        let buckets = grouped.map { startDate, logs in
            makeBucket(startDate: startDate, logs: logs, period: period)
        }
        .sorted { $0.startDate < $1.startDate }

        let visibleBuckets = Array(buckets.suffix(period.historyWindow))
        guard let currentBucket = visibleBuckets.last else {
            return buildCostSummary(period: period, fuelLogs: [])
        }

        let currentLogs = grouped[currentBucket.startDate, default: []]
            .sorted { $0.loggedAt > $1.loggedAt }
        let previousBucket = visibleBuckets.dropLast().last
        let totalSpend = currentLogs.reduce(0) { $0 + $1.totalCost }
        let averageFillCost = currentLogs.isEmpty ? 0 : totalSpend / Double(currentLogs.count)
        let averagePrice = averagePricePerUnit(in: currentLogs)
        let dominantStation = mostCommonString(in: currentLogs.map(\.stationName))
        let dominantArea = mostCommonString(in: currentLogs.map(\.areaLabel))

        return FuelCostSummary(
            period: period,
            headline: currentHeadline(for: period, bucket: currentBucket),
            totalSpend: totalSpend,
            fillUpCount: currentLogs.count,
            averageFillCost: averageFillCost,
            averagePricePerUnit: averagePrice,
            dominantStation: dominantStation,
            dominantArea: dominantArea,
            comparisonText: comparisonText(current: currentBucket, previous: previousBucket, period: period),
            summary: periodSummary(period: period, bucket: currentBucket, logs: currentLogs),
            insights: buildCostInsights(logs: currentLogs, bucket: currentBucket),
            buckets: visibleBuckets,
            logs: currentLogs
        )
    }

    func buildMaintenanceCostSummary(
        period: FuelCostPeriod,
        expenses: [MaintenanceExpense]
    ) -> MaintenanceCostSummary {
        guard !expenses.isEmpty else {
            return MaintenanceCostSummary(
                period: period,
                headline: "No maintenance costs logged yet",
                totalSpend: 0,
                entryCount: 0,
                averageEntryCost: 0,
                dominantCategory: nil,
                dominantLocation: nil,
                comparisonText: "Manual maintenance purchases will show up here once you add them.",
                summary: "Use maintenance mode to log oil, tires, filters, and parts with date, location, price, and notes.",
                insights: [
                    "Track where you bought each part or service so the maintenance agent can compare shop patterns over time.",
                    "Add a short note for why you bought it, so future maintenance summaries can connect cost with wear or reminders."
                ],
                buckets: [],
                expenses: []
            )
        }

        let grouped = Dictionary(grouping: expenses, by: { bucketStart(for: $0.purchasedAt, period: period) })
        let buckets = grouped.map { startDate, expenses in
            makeMaintenanceBucket(startDate: startDate, expenses: expenses, period: period)
        }
        .sorted { $0.startDate < $1.startDate }

        let visibleBuckets = Array(buckets.suffix(period.historyWindow))
        guard let currentBucket = visibleBuckets.last else {
            return buildMaintenanceCostSummary(period: period, expenses: [])
        }

        let currentExpenses = grouped[currentBucket.startDate, default: []]
            .sorted { $0.purchasedAt > $1.purchasedAt }
        let previousBucket = visibleBuckets.dropLast().last
        let totalSpend = currentExpenses.reduce(0) { $0 + $1.totalCost }
        let averageEntryCost = currentExpenses.isEmpty ? 0 : totalSpend / Double(currentExpenses.count)
        let dominantCategory = mostCommonString(in: currentExpenses.map { $0.category.label })
        let dominantLocation = mostCommonString(in: currentExpenses.map(\.purchaseLocation))

        return MaintenanceCostSummary(
            period: period,
            headline: currentMaintenanceHeadline(for: period, bucket: currentBucket),
            totalSpend: totalSpend,
            entryCount: currentExpenses.count,
            averageEntryCost: averageEntryCost,
            dominantCategory: dominantCategory,
            dominantLocation: dominantLocation,
            comparisonText: maintenanceComparisonText(current: currentBucket, previous: previousBucket, period: period),
            summary: maintenancePeriodSummary(period: period, bucket: currentBucket, expenses: currentExpenses),
            insights: buildMaintenanceCostInsights(expenses: currentExpenses, bucket: currentBucket),
            buckets: visibleBuckets,
            expenses: currentExpenses
        )
    }

    func fallbackCoachBrief(
        question: String,
        profile: VehicleProfile?,
        trips: [TripResult],
        fuelLogs: [FuelLog],
        marketUpdates: [FuelMarketUpdate]
    ) -> FuelCoachBrief {
        let hardBrakes = trips.map(\.hardBrakes).reduce(0, +)
        let aggressiveAccels = trips.map(\.aggressiveAccels).reduce(0, +)
        let avgFillCost = fuelLogs.isEmpty ? 0 : fuelLogs.reduce(0) { $0 + $1.totalCost } / Double(fuelLogs.count)
        let trend = marketUpdates.first?.direction ?? .steady
        let frequentStation = mostCommonString(in: fuelLogs.map(\.stationName))
        let fuelProduct = mostCommonString(in: fuelLogs.map { $0.fuelProduct.label })

        let pricingOutlook: String
        switch trend {
        case .down:
            pricingOutlook = "The local price pulse is easing, so waiting for promo days or early-week fill-ups may help next week."
        case .steady:
            pricingOutlook = "Local prices look fairly stable, so your savings will come more from station choice and promos than timing."
        case .up:
            pricingOutlook = "The local price pulse is climbing, so filling earlier and leaning on promo stations should help."
        }

        let diagnosis: String
        if aggressiveAccels > hardBrakes {
            diagnosis = "Your faster fuel burn likely comes more from hard acceleration than braking, especially on stop-and-go routes."
        } else if hardBrakes > 0 {
            diagnosis = "Braking late and re-accelerating often is probably adding avoidable fuel waste on short trips."
        } else if let frequentStation, let fuelProduct {
            diagnosis = "Your most common fill-up pattern is \(fuelProduct.lowercased()) at \(frequentStation), so station quality and promo consistency matter more than driving events right now."
        } else {
            diagnosis = "Based on the data saved so far, route mix and station pricing look like bigger drivers than aggressive events."
        }

        let profileLine = profile?.homeArea?.nilIfBlank != nil
            ? "Your profile is centered on \(profile?.homeArea ?? "your area")."
            : "Add your home area in the driver profile to localize station and outlook recommendations."

        return FuelCoachBrief(
            summary: "For “\(question)”, your current fuel pattern averages about \(currency(avgFillCost)) per fill-up. \(profileLine)",
            pricingOutlook: pricingOutlook,
            efficiencyDiagnosis: diagnosis,
            actionPlan: [
                "Use the map fuel logger after each stop so weekly and monthly spend becomes accurate.",
                "Compare promo stations against your preferred fuel product before defaulting to the nearest stop.",
                "Keep feeding Tinyfish station data into the insight tab so quality and price recommendations stay live."
            ]
        )
    }

    private func makeSpendSnapshot(from fuelLogs: [FuelLog]) -> FuelSpendSnapshot {
        let calendar = Calendar.current
        let now = Date()
        let weekStart = calendar.date(byAdding: .day, value: -6, to: now) ?? now
        let monthStart = calendar.date(from: calendar.dateComponents([.year, .month], from: now)) ?? now
        let yearStart = calendar.date(from: calendar.dateComponents([.year], from: now)) ?? now

        let weekly = cost(from: fuelLogs, since: weekStart)
        let monthly = cost(from: fuelLogs, since: monthStart)
        let yearly = cost(from: fuelLogs, since: yearStart)
        let dailyAverage = weekly / 7
        let projectedYearly = yearly > 0 ? yearly : dailyAverage * 365

        return FuelSpendSnapshot(
            dailyAverage: dailyAverage,
            weeklyTotal: weekly,
            monthlyTotal: monthly,
            yearlyProjection: projectedYearly
        )
    }

    private func makeStationInsights(profile: VehicleProfile?, fuelLogs: [FuelLog]) -> [FuelStationInsight] {
        let fallbackArea = profile?.homeArea?.nilIfBlank ?? fuelLogs.first?.areaLabel ?? "your area"

        guard !fuelLogs.isEmpty else {
            let product = profile?.preferredFuelProduct.label ?? "fuel"
            let preference = profile?.stationPreference ?? .balanced
            return [
                FuelStationInsight(
                    highlight: .cheapest,
                    stationName: "Value Stop",
                    areaLabel: fallbackArea,
                    priceText: "$3.89/gal",
                    detail: "Best low-price placeholder for \(product.lowercased()) in \(fallbackArea). Replace with Tinyfish live station ranking."
                ),
                FuelStationInsight(
                    highlight: .premiumPick,
                    stationName: preference == .premiumQuality ? "Prime Fuel" : "Top Tier Plus",
                    areaLabel: fallbackArea,
                    priceText: "$4.49/gal",
                    detail: "Higher-cost option meant for premium quality and cleaner additive packages."
                ),
                FuelStationInsight(
                    highlight: .bestPromo,
                    stationName: "Rewards Pump",
                    areaLabel: fallbackArea,
                    priceText: "$4.05/gal",
                    detail: "Best promo placeholder. Later this should combine Tinyfish prices with retailer reward logic."
                )
            ]
        }

        let cheapestLog = fuelLogs.min { $0.pricePerUnit < $1.pricePerUnit } ?? fuelLogs[0]
        let highestQualityLog = fuelLogs
            .filter { $0.fuelProduct == .premium || $0.fuelProduct == .midgrade }
            .max { $0.pricePerUnit < $1.pricePerUnit }
            ?? fuelLogs.max { $0.pricePerUnit < $1.pricePerUnit }
            ?? fuelLogs[0]
        let promoLog = fuelLogs.first { ($0.promoTitle?.isEmpty == false) } ?? fuelLogs[0]

        return [
            FuelStationInsight(
                highlight: .cheapest,
                stationName: cheapestLog.stationName,
                areaLabel: cheapestLog.areaLabel,
                priceText: pricePerUnitText(for: cheapestLog),
                detail: "Cheapest logged stop so far. Once Tinyfish is connected, this should update with nearby real-time station rankings."
            ),
            FuelStationInsight(
                highlight: .premiumPick,
                stationName: highestQualityLog.stationName,
                areaLabel: highestQualityLog.areaLabel,
                priceText: pricePerUnitText(for: highestQualityLog),
                detail: "Best high-quality signal from your logs based on product type and price tier."
            ),
            FuelStationInsight(
                highlight: .bestPromo,
                stationName: promoLog.stationName,
                areaLabel: promoLog.areaLabel,
                priceText: pricePerUnitText(for: promoLog),
                detail: promoLog.promoTitle ?? "No promo note captured yet. Plug Tinyfish and retailer promos in here."
            )
        ]
    }

    private func makeMarketUpdates(
        profile: VehicleProfile?,
        trips: [TripResult],
        fuelLogs: [FuelLog]
    ) -> [FuelMarketUpdate] {
        let area = profile?.homeArea?.nilIfBlank ?? "your local area"
        let aggressiveAccels = trips.map(\.aggressiveAccels).reduce(0, +)
        let averagePrice = averagePricePerUnit(in: fuelLogs)

        let firstDirection: FuelTrendDirection = averagePrice > 4.30 ? .up : .steady

        return [
            FuelMarketUpdate(
                headline: "Projected Price Move",
                summary: "Current placeholder outlook for \(area). Feed this from Tinyfish plus AWS news processing so this becomes your next-7-day gas projection.",
                direction: firstDirection
            ),
            FuelMarketUpdate(
                headline: "Promo Window",
                summary: "Reward-linked stations should surface here when card discounts or loyalty promos make them worth switching to.",
                direction: .down
            ),
            FuelMarketUpdate(
                headline: "Driving Pressure",
                summary: aggressiveAccels > 5
                    ? "Your acceleration trend is strong enough that personal driving behavior may move your real fuel costs faster than market news."
                    : "Your driving trend looks relatively stable, so station quality and price timing may matter more this week.",
                direction: aggressiveAccels > 5 ? .up : .steady
            )
        ]
    }

    private func makeProfileSummary(_ profile: VehicleProfile?) -> String {
        guard let profile else {
            return "Add a home area and fuel preferences to personalize local station picks and projected gas-price outlooks."
        }

        let area = profile.homeArea?.nilIfBlank ?? "home area not set"
        return "\(profile.displayName) • \(area) • \(profile.preferredFuelProduct.label) • \(profile.stationPreference.label)"
    }

    private func makeEfficiencyHeadline(trips: [TripResult], fuelLogs: [FuelLog]) -> String {
        let hardBrakes = trips.map(\.hardBrakes).reduce(0, +)
        let aggressiveAccels = trips.map(\.aggressiveAccels).reduce(0, +)

        if aggressiveAccels >= 6 {
            return "Acceleration habits look like the biggest lever on your fuel costs right now."
        }
        if hardBrakes >= 6 {
            return "Late braking is likely increasing wasted momentum on repeat routes."
        }
        if fuelLogs.count < 3 {
            return "Log a few real fuel stops to unlock sharper weekly projections and station quality insights."
        }
        return "Your fill-up history is rich enough to compare market news against your actual station choices."
    }

    private func makeSuggestedQuestions(profile: VehicleProfile?) -> [String] {
        [
            "Why did my fuel estimate change this week?",
            "Based on where I fill up most, is it high-quality gas?",
            "Which nearby station fits my \(profile?.stationPreference.label.lowercased() ?? "fuel") preference?"
        ]
    }

    private func makeProjectionSummary(
        marketUpdates: [FuelMarketUpdate],
        spendSnapshot: FuelSpendSnapshot
    ) -> String {
        guard let lead = marketUpdates.first else {
            return "No market projection available yet."
        }

        switch lead.direction {
        case .up:
            return "Projected gas pressure is up. If your pace holds, you’re trending toward \(currency(spendSnapshot.monthlyTotal)) this month."
        case .steady:
            return "Projected gas pressure is steady. Station selection and promos should matter more than timing right now."
        case .down:
            return "Projected gas pressure is easing. Watch for lower-price fill windows and stacked promos this week."
        }
    }

    private func makeCoordinationNotes(
        profile: VehicleProfile?,
        trips: [TripResult],
        fuelLogs: [FuelLog]
    ) -> [FuelAgentCoordinationNote] {
        let dominantStation = mostCommonString(in: fuelLogs.map(\.stationName)) ?? "your logged stations"
        let dominantProduct = mostCommonString(in: fuelLogs.map { $0.fuelProduct.label }) ?? (profile?.preferredFuelProduct.label ?? "your fuel choice")
        let aggressiveAccels = trips.map(\.aggressiveAccels).reduce(0, +)
        let promoCount = fuelLogs.filter { $0.promoTitle?.isEmpty == false }.count

        return [
            FuelAgentCoordinationNote(
                source: .marketNews,
                title: "News + Projection Agent",
                summary: "This lane should blend price-moving news with market projection logic before surfacing alert-worthy fuel insights."
            ),
            FuelAgentCoordinationNote(
                source: .fillHistory,
                title: "Fill-Up History Agent",
                summary: "Your strongest current fill-up signal is \(dominantProduct.lowercased()) around \(dominantStation). This is where station quality comparisons should land."
            ),
            FuelAgentCoordinationNote(
                source: .drivingBehavior,
                title: "Driving Pattern Agent",
                summary: aggressiveAccels > 5
                    ? "Driving behavior is materially affecting your refill timing, so this agent should keep feeding context into fuel answers."
                    : "Driving behavior looks stable enough that pricing and station decisions should lead the fuel story."
            ),
            FuelAgentCoordinationNote(
                source: .agentBridge,
                title: "Cross-Agent Handoff",
                summary: promoCount > 0
                    ? "Promo history is already showing up in your logs, so backend agents can combine station price, promo, and driving context in one answer."
                    : "Once Tinyfish, Redis, and Vapi are live, this handoff can merge live price intel, habits, and voice questions in one place."
            )
        ]
    }

    private func buildCostInsights(logs: [FuelLog], bucket: FuelCostBucket) -> [String] {
        guard !logs.isEmpty else { return [] }

        var insights: [String] = []

        if let dominantStation = bucket.dominantStation {
            insights.append("Most common station this period: \(dominantStation).")
        }

        let promoCount = logs.filter { $0.promoTitle?.isEmpty == false }.count
        if promoCount > 0 {
            insights.append("Promo or rewards notes showed up on \(promoCount) of \(logs.count) fill-ups.")
        } else {
            insights.append("No promo usage was logged this period, so savings opportunities may be getting missed.")
        }

        if let averageGap = averageDaysBetweenFillUps(in: logs) {
            insights.append(String(format: "You averaged %.1f days between fill-ups in this period.", averageGap))
        }

        let dominantProduct = mostCommonString(in: logs.map { $0.fuelProduct.label }) ?? "fuel"
        insights.append("Your dominant fill-up product was \(dominantProduct.lowercased()).")

        return insights
    }

    private func buildMaintenanceCostInsights(
        expenses: [MaintenanceExpense],
        bucket: MaintenanceCostBucket
    ) -> [String] {
        guard !expenses.isEmpty else { return [] }

        var insights: [String] = []

        if let dominantCategory = bucket.dominantCategory {
            insights.append("Most common maintenance category this period: \(dominantCategory).")
        }

        if let dominantLocation = bucket.dominantLocation {
            insights.append("You most often bought parts or service at \(dominantLocation) in this period.")
        }

        if let largestExpense = expenses.max(by: { $0.totalCost < $1.totalCost }) {
            insights.append("Largest maintenance purchase was \(largestExpense.itemName) for \(currency(largestExpense.totalCost)).")
        }

        let notedCount = expenses.filter { $0.notes?.nilIfBlank != nil }.count
        if notedCount > 0 {
            insights.append("Notes were saved on \(notedCount) of \(expenses.count) entries, giving the maintenance agent more context.")
        } else {
            insights.append("No notes were saved this period, so add quick context when you buy a part or service.")
        }

        if let averageGap = averageDaysBetweenPurchases(in: expenses) {
            insights.append(String(format: "You averaged %.1f days between maintenance purchases in this period.", averageGap))
        }

        return insights
    }

    private func makeBucket(startDate: Date, logs: [FuelLog], period: FuelCostPeriod) -> FuelCostBucket {
        let totalSpend = logs.reduce(0) { $0 + $1.totalCost }
        let averagePrice = averagePricePerUnit(in: logs)
        let fillUpCount = logs.count
        let dominantStation = mostCommonString(in: logs.map(\.stationName))
        let label = bucketLabel(for: startDate, period: period)

        return FuelCostBucket(
            label: label,
            startDate: startDate,
            totalSpend: totalSpend,
            fillUpCount: fillUpCount,
            averagePrice: averagePrice,
            dominantStation: dominantStation,
            summary: "\(fillUpCount) fill-up\(fillUpCount == 1 ? "" : "s") • \(currency(totalSpend))"
        )
    }

    private func makeMaintenanceBucket(
        startDate: Date,
        expenses: [MaintenanceExpense],
        period: FuelCostPeriod
    ) -> MaintenanceCostBucket {
        let totalSpend = expenses.reduce(0) { $0 + $1.totalCost }
        let purchaseCount = expenses.count
        let dominantCategory = mostCommonString(in: expenses.map { $0.category.label })
        let dominantLocation = mostCommonString(in: expenses.map(\.purchaseLocation))
        let label = bucketLabel(for: startDate, period: period)

        return MaintenanceCostBucket(
            label: label,
            startDate: startDate,
            totalSpend: totalSpend,
            purchaseCount: purchaseCount,
            dominantCategory: dominantCategory,
            dominantLocation: dominantLocation,
            summary: "\(purchaseCount) maintenance purchase\(purchaseCount == 1 ? "" : "s") • \(currency(totalSpend))"
        )
    }

    private func currentHeadline(for period: FuelCostPeriod, bucket: FuelCostBucket) -> String {
        switch period {
        case .daily:
            return "Latest fill-up day: \(bucket.label)"
        case .weekly:
            return "Latest active week: \(bucket.label)"
        case .monthly:
            return "Latest active month: \(bucket.label)"
        case .yearly:
            return "Latest active year: \(bucket.label)"
        }
    }

    private func currentMaintenanceHeadline(
        for period: FuelCostPeriod,
        bucket: MaintenanceCostBucket
    ) -> String {
        switch period {
        case .daily:
            return "Latest maintenance day: \(bucket.label)"
        case .weekly:
            return "Latest maintenance week: \(bucket.label)"
        case .monthly:
            return "Latest maintenance month: \(bucket.label)"
        case .yearly:
            return "Latest maintenance year: \(bucket.label)"
        }
    }

    private func periodSummary(period: FuelCostPeriod, bucket: FuelCostBucket, logs: [FuelLog]) -> String {
        let priceText = bucket.averagePrice > 0 ? String(format: "$%.2f", bucket.averagePrice) : "--"
        let station = bucket.dominantStation ?? "mixed stations"

        switch period {
        case .daily:
            return "On \(bucket.label), you spent \(currency(bucket.totalSpend)) across \(bucket.fillUpCount) fill-up\(bucket.fillUpCount == 1 ? "" : "s"). Average price was \(priceText) per gallon, mostly at \(station)."
        case .weekly:
            return "That week, you spent \(currency(bucket.totalSpend)) across \(bucket.fillUpCount) fill-ups. Average price was \(priceText) per gallon, and your most common station was \(station)."
        case .monthly:
            return "In \(bucket.label), you spent \(currency(bucket.totalSpend)) across \(bucket.fillUpCount) fill-ups. Average price was \(priceText) per gallon, with \(station) showing up most often."
        case .yearly:
            return "In \(bucket.label), you spent \(currency(bucket.totalSpend)) on fuel across \(bucket.fillUpCount) logged stops. Average price sat around \(priceText) per gallon, centered on \(station)."
        }
    }

    private func maintenancePeriodSummary(
        period: FuelCostPeriod,
        bucket: MaintenanceCostBucket,
        expenses: [MaintenanceExpense]
    ) -> String {
        let location = bucket.dominantLocation ?? "mixed locations"
        let category = bucket.dominantCategory ?? "maintenance items"

        switch period {
        case .daily:
            return "On \(bucket.label), you logged \(bucket.purchaseCount) maintenance purchase\(bucket.purchaseCount == 1 ? "" : "s") for \(currency(bucket.totalSpend)), centered on \(category.lowercased()) around \(location)."
        case .weekly:
            return "That week, you spent \(currency(bucket.totalSpend)) across \(bucket.purchaseCount) maintenance entries. \(category) led the spend, mostly around \(location)."
        case .monthly:
            return "In \(bucket.label), you spent \(currency(bucket.totalSpend)) on maintenance across \(bucket.purchaseCount) logged purchases. \(category) was the top category, centered on \(location)."
        case .yearly:
            return "In \(bucket.label), you recorded \(bucket.purchaseCount) maintenance purchases totaling \(currency(bucket.totalSpend)). The strongest pattern was \(category.lowercased()) around \(location)."
        }
    }

    private func comparisonText(
        current: FuelCostBucket,
        previous: FuelCostBucket?,
        period: FuelCostPeriod
    ) -> String {
        guard let previous else {
            return "No prior \(period.rawValue.lowercased()) period available yet."
        }

        let delta = current.totalSpend - previous.totalSpend
        if abs(delta) < 0.01 {
            return "Your spend matched the previous \(period.rawValue.lowercased()) period almost exactly."
        }

        let direction = delta > 0 ? "up" : "down"
        return "Fuel spend is \(direction) \(currency(abs(delta))) versus the previous \(period.rawValue.lowercased()) period."
    }

    private func maintenanceComparisonText(
        current: MaintenanceCostBucket,
        previous: MaintenanceCostBucket?,
        period: FuelCostPeriod
    ) -> String {
        guard let previous else {
            return "No prior \(period.rawValue.lowercased()) maintenance period available yet."
        }

        let delta = current.totalSpend - previous.totalSpend
        if abs(delta) < 0.01 {
            return "Your maintenance spend matched the previous \(period.rawValue.lowercased()) period almost exactly."
        }

        let direction = delta > 0 ? "up" : "down"
        return "Maintenance spend is \(direction) \(currency(abs(delta))) versus the previous \(period.rawValue.lowercased()) period."
    }

    private func bucketStart(for date: Date, period: FuelCostPeriod) -> Date {
        let calendar = Calendar.current
        switch period {
        case .daily:
            return calendar.startOfDay(for: date)
        case .weekly:
            return calendar.dateInterval(of: .weekOfYear, for: date)?.start ?? calendar.startOfDay(for: date)
        case .monthly:
            return calendar.date(from: calendar.dateComponents([.year, .month], from: date)) ?? calendar.startOfDay(for: date)
        case .yearly:
            return calendar.date(from: calendar.dateComponents([.year], from: date)) ?? calendar.startOfDay(for: date)
        }
    }

    private func bucketLabel(for date: Date, period: FuelCostPeriod) -> String {
        let formatter = DateFormatter()
        switch period {
        case .daily:
            formatter.dateFormat = "MMM d"
        case .weekly:
            let endDate = Calendar.current.date(byAdding: .day, value: 6, to: date) ?? date
            let monthFormatter = DateFormatter()
            monthFormatter.dateFormat = "MMM d"
            return "\(monthFormatter.string(from: date))-\(monthFormatter.string(from: endDate))"
        case .monthly:
            formatter.dateFormat = "MMMM"
        case .yearly:
            formatter.dateFormat = "yyyy"
        }
        return formatter.string(from: date)
    }

    private func averagePricePerUnit(in logs: [FuelLog]) -> Double {
        guard !logs.isEmpty else { return 0 }
        return logs.map(\.pricePerUnit).reduce(0, +) / Double(logs.count)
    }

    private func averageDaysBetweenFillUps(in logs: [FuelLog]) -> Double? {
        let ordered = logs.map(\.loggedAt).sorted()
        guard ordered.count > 1 else { return nil }
        let gaps = zip(ordered, ordered.dropFirst()).map { earlier, later in
            later.timeIntervalSince(earlier) / 86_400
        }
        guard !gaps.isEmpty else { return nil }
        return gaps.reduce(0, +) / Double(gaps.count)
    }

    private func averageDaysBetweenPurchases(in expenses: [MaintenanceExpense]) -> Double? {
        let ordered = expenses.map(\.purchasedAt).sorted()
        guard ordered.count > 1 else { return nil }
        let gaps = zip(ordered, ordered.dropFirst()).map { earlier, later in
            later.timeIntervalSince(earlier) / 86_400
        }
        guard !gaps.isEmpty else { return nil }
        return gaps.reduce(0, +) / Double(gaps.count)
    }

    private func mostCommonString(in values: [String]) -> String? {
        let cleaned = values.map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }.filter { !$0.isEmpty }
        guard !cleaned.isEmpty else { return nil }
        let counts = cleaned.reduce(into: [String: Int]()) { $0[$1, default: 0] += 1 }
        return counts.max(by: { lhs, rhs in
            if lhs.value == rhs.value { return lhs.key > rhs.key }
            return lhs.value < rhs.value
        })?.key
    }

    private func pricePerUnitText(for log: FuelLog) -> String {
        String(format: "$%.2f/unit", log.pricePerUnit)
    }

    private func cost(from logs: [FuelLog], since start: Date) -> Double {
        logs.filter { $0.loggedAt >= start }.reduce(0) { $0 + $1.totalCost }
    }

    private func currency(_ value: Double) -> String {
        String(format: "$%.2f", value)
    }
}

private extension String {
    var nilIfBlank: String? {
        let value = trimmingCharacters(in: .whitespacesAndNewlines)
        guard !value.isEmpty else {
            return nil
        }
        return value
    }
}

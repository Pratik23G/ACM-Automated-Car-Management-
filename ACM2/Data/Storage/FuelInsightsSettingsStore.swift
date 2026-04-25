import Foundation
import Combine
import UserNotifications

private struct FuelInsightsSettingsSnapshot: Codable {
    var insightAlertsEnabled: Bool = false
    var priceShockAlertsEnabled: Bool = true
    var promoAlertsEnabled: Bool = true
    var weeklyDigestEnabled: Bool = true
}

@MainActor
final class FuelInsightsSettingsStore: ObservableObject {
    @Published var insightAlertsEnabled: Bool = false {
        didSet { persistIfReady() }
    }
    @Published var priceShockAlertsEnabled: Bool = true {
        didSet { persistIfReady() }
    }
    @Published var promoAlertsEnabled: Bool = true {
        didSet { persistIfReady() }
    }
    @Published var weeklyDigestEnabled: Bool = true {
        didSet { persistIfReady() }
    }
    @Published private(set) var authorizationStatusText: String = "Not requested"

    private var isReadyToPersist = false

    private let saveURL: URL = {
        let docs = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
        return docs.appendingPathComponent("fuel_insight_settings.json")
    }()

    init() {
        load()
        isReadyToPersist = true
        refreshAuthorizationStatus()
    }

    func updateInsightAlerts(enabled: Bool) {
        insightAlertsEnabled = enabled
        if enabled {
            requestAuthorization()
        }
    }

    func refreshAuthorizationStatus() {
        UNUserNotificationCenter.current().getNotificationSettings { settings in
            let text: String
            switch settings.authorizationStatus {
            case .authorized: text = "Alerts allowed"
            case .provisional: text = "Provisional alerts allowed"
            case .denied: text = "Permission denied"
            case .notDetermined: text = "Not requested"
            case .ephemeral: text = "Temporary access"
            @unknown default: text = "Unknown"
            }

            Task { @MainActor in
                self.authorizationStatusText = text
                if settings.authorizationStatus == .denied || settings.authorizationStatus == .notDetermined {
                    if !self.insightAlertsEnabled { return }
                    self.insightAlertsEnabled = false
                }
            }
        }
    }

    private func requestAuthorization() {
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound, .badge]) { granted, _ in
            Task { @MainActor in
                self.authorizationStatusText = granted ? "Alerts allowed" : "Permission denied"
                if !granted {
                    self.insightAlertsEnabled = false
                }
            }
        }
    }

    private func persistIfReady() {
        guard isReadyToPersist else { return }
        persist()
    }

    private func persist() {
        do {
            let snapshot = FuelInsightsSettingsSnapshot(
                insightAlertsEnabled: insightAlertsEnabled,
                priceShockAlertsEnabled: priceShockAlertsEnabled,
                promoAlertsEnabled: promoAlertsEnabled,
                weeklyDigestEnabled: weeklyDigestEnabled
            )
            let encoder = JSONEncoder()
            encoder.outputFormatting = [.prettyPrinted]
            let data = try encoder.encode(snapshot)
            try data.write(to: saveURL, options: [.atomic])
        } catch {
            print("FuelInsightsSettingsStore persist error:", error)
        }
    }

    private func load() {
        guard FileManager.default.fileExists(atPath: saveURL.path) else { return }
        do {
            let data = try Data(contentsOf: saveURL)
            let snapshot = try JSONDecoder().decode(FuelInsightsSettingsSnapshot.self, from: data)
            insightAlertsEnabled = snapshot.insightAlertsEnabled
            priceShockAlertsEnabled = snapshot.priceShockAlertsEnabled
            promoAlertsEnabled = snapshot.promoAlertsEnabled
            weeklyDigestEnabled = snapshot.weeklyDigestEnabled
        } catch {
            print("FuelInsightsSettingsStore load error:", error)
        }
    }
}

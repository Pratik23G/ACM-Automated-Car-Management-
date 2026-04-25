import SwiftUI
import UserNotifications

@main
struct ACM2App: App {

    @UIApplicationDelegateAdaptor(AppDelegate.self) var delegate

    var body: some Scene {
        WindowGroup {
            AppRootView()
                .onOpenURL { url in
                    handleDeepLink(url)
                }
        }
    }

    private func handleDeepLink(_ url: URL) {
        switch url.host {
        case "starttrip":
            // Widget tapped Start — update shared state; AppRootView picks this up
            SharedDefaults.isTripActive  = true
            SharedDefaults.tripStartedAt = Date()
            NotificationCenter.default.post(name: .acmWidgetStartTrip, object: nil)
        case "stoptrip":
            SharedDefaults.isTripActive  = false
            SharedDefaults.tripStartedAt = nil
            NotificationCenter.default.post(name: .acmWidgetStopTrip, object: nil)
        default:
            break
        }
    }
}

// MARK: - Notification Names

extension Notification.Name {
    static let acmWidgetStartTrip = Notification.Name("acmWidgetStartTrip")
    static let acmWidgetStopTrip  = Notification.Name("acmWidgetStopTrip")
    static let acmConfirmAutoTrip = Notification.Name("acmConfirmAutoTrip")
    static let acmDiscardAutoTrip = Notification.Name("acmDiscardAutoTrip")
}

// MARK: - AppDelegate (notification delegate for drive confirm/discard actions)

class AppDelegate: NSObject, UIApplicationDelegate, UNUserNotificationCenterDelegate {

    func application(_ application: UIApplication,
                     didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil) -> Bool {
        UNUserNotificationCenter.current().delegate = self
        DriveDetector.registerNotificationCategories()
        return true
    }

    // Handle notification action buttons (Confirm / Discard drive)
    func userNotificationCenter(_ center: UNUserNotificationCenter,
                                 didReceive response: UNNotificationResponse,
                                 withCompletionHandler completionHandler: @escaping () -> Void) {
        switch response.actionIdentifier {
        case "CONFIRM_DRIVE":
            NotificationCenter.default.post(name: .acmConfirmAutoTrip, object: nil)
        case "DISCARD_DRIVE":
            NotificationCenter.default.post(name: .acmDiscardAutoTrip, object: nil)
        default:
            break
        }
        completionHandler()
    }

    // Show notification even when app is in foreground
    func userNotificationCenter(_ center: UNUserNotificationCenter,
                                 willPresent notification: UNNotification,
                                 withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void) {
        completionHandler([.banner, .sound])
    }
}

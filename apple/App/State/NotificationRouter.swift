import Foundation
import UserNotifications
import ZotEatsKit

/// Routes notification taps into `anteats://` deep links and shows banners
/// while the app is foregrounded (favorite pings used to be silent otherwise).
@MainActor
final class NotificationRouter: NSObject, UNUserNotificationCenterDelegate {
    static let shared = NotificationRouter()

    /// Set by `RootTabView` so taps update tab selection + Eat/Campus state.
    var onDeepLink: ((AnteatsDeepLink) -> Void)?

    func install() {
        UNUserNotificationCenter.current().delegate = self
    }

    nonisolated func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification,
        withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void
    ) {
        completionHandler([.banner, .sound, .list])
    }

    nonisolated func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        didReceive response: UNNotificationResponse,
        withCompletionHandler completionHandler: @escaping () -> Void
    ) {
        let info = response.notification.request.content.userInfo
        Task { @MainActor in
            if let link = AnteatsDeepLink.fromNotification(userInfo: info) {
                onDeepLink?(link)
            }
            completionHandler()
        }
    }
}

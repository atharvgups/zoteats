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
        // Pull Sendable string keys on this isolation, then hop to MainActor.
        let info = response.notification.request.content.userInfo
        var payload: [AnyHashable: Any] = [:]
        if let deeplink = info["deeplink"] as? String { payload["deeplink"] = deeplink }
        if let place = info["place"] as? String { payload["place"] = place }
        if let hallID = info["hallID"] as? String { payload["hallID"] = hallID }
        if let period = info["period"] as? String { payload["period"] = period }
        if let dish = info["dish"] as? String { payload["dish"] = dish }
        if let date = info["date"] as? String { payload["date"] = date }
        let link = AnteatsDeepLink.fromNotification(userInfo: payload)
        let finish = UncheckedNotificationCompletion(completionHandler)
        Task { @MainActor in
            if let link { onDeepLink?(link) }
            finish.callAsFunction()
        }
    }
}

/// Bridges UNNotification completion handlers across actor boundaries.
private struct UncheckedNotificationCompletion: @unchecked Sendable {
    private let handler: () -> Void
    init(_ handler: @escaping () -> Void) { self.handler = handler }
    func callAsFunction() { handler() }
}

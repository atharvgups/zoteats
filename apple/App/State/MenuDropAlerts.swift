import Foundation
import UserNotifications
import ZotEatsKit

// "Menu dropped" alerts: UCI publishes menus a few days ahead. We remember
// which upcoming days were still unpublished (via /dateRange), and when one
// flips into the published window we send a single local notification.
// Opt-in via Settings; piggybacks on the existing background-refresh pipeline.

@MainActor
enum MenuDropAlerts {
    private static let enabledKey = "zoteats.menuDropAlertsEnabled"
    private static let pendingDaysKey = "zoteats.menuDrop.unpublishedDays"
    private static let notifiedDaysKey = "zoteats.menuDrop.notifiedDays"

    static var isEnabled: Bool {
        get { UserDefaults.standard.bool(forKey: enabledKey) }
        set { UserDefaults.standard.set(newValue, forKey: enabledKey) }
    }

    /// Remembers unpublished upcoming days (including today after midnight
    /// rollover); notifies once when `/dateRange` covers them.
    static func runCheck(service: DiningService = DiningService()) async {
        guard isEnabled else { return }
        guard let range = await service.publishedDateRange() else { return }

        // Include today so an overnight publish of what was “tomorrow” still
        // pings — future-only watch sets prune that ISO with no notification.
        let days = UCITime.upcomingDays(count: 5)
        guard !days.isEmpty else { return }

        let isoDates = days.map(\.isoDate)
        let validDays = Set(isoDates)
        let currentlyUnpublished = MenuDropMath.unpublishedDays(
            upcoming: isoDates,
            earliest: range.earliest,
            latest: range.latest
        )
        let currentlyPublished = validDays.subtracting(currentlyUnpublished)

        var unpublished = Set(UserDefaults.standard.stringArray(forKey: pendingDaysKey) ?? [])
        var notified = Set(UserDefaults.standard.stringArray(forKey: notifiedDaysKey) ?? [])

        let fresh = MenuDropMath.newlyDroppedDays(
            previouslyUnpublished: unpublished,
            nowPublished: currentlyPublished,
            alreadyNotified: notified
        )
        for iso in fresh.sorted() {
            notified.insert(iso)
            let label = days.first { $0.isoDate == iso }?.label ?? iso
            let content = UNMutableNotificationContent()
            content.title = "\(label)'s menu just dropped"
            content.body = "UCI Dining posted it — take a peek and plan your meals."
            content.sound = .default
            let link = AnteatsDeepLink.eat(date: iso)
            content.userInfo = [
                "deeplink": link.url.absoluteString,
                "date": iso,
            ]
            try? await UNUserNotificationCenter.current().add(
                UNNotificationRequest(
                    identifier: "menudrop:\(iso)",
                    content: content,
                    trigger: nil
                )
            )
        }

        // Remember what's still unpublished; drop days that scrolled out of window.
        unpublished = currentlyUnpublished.intersection(validDays)
        notified = notified.intersection(validDays)

        UserDefaults.standard.set(Array(unpublished).sorted(), forKey: pendingDaysKey)
        UserDefaults.standard.set(Array(notified).sorted(), forKey: notifiedDaysKey)
    }
}

import Foundation
import UserNotifications
import ZotEatsKit

// "Menu dropped" alerts: UCI publishes menus a few days ahead, and browsing
// an unpublished day shows "not posted yet". When a day we previously saw as
// unpublished flips to published, tell the user — one notification per day.
// Opt-in via Settings, piggybacks on the existing background refresh.

@MainActor
enum MenuDropAlerts {
    private static let enabledKey = "zoteats.menuDropAlertsEnabled"
    private static let pendingDaysKey = "zoteats.menuDrop.unpublishedDays"
    private static let notifiedDaysKey = "zoteats.menuDrop.notifiedDays"

    static var isEnabled: Bool {
        get { UserDefaults.standard.bool(forKey: enabledKey) }
        set { UserDefaults.standard.set(newValue, forKey: enabledKey) }
    }

    /// Checks the next few days: remembers which are unpublished, and when a
    /// remembered day turns published, notifies once.
    static func runCheck(service: DiningService = DiningService()) async {
        guard isEnabled else { return }

        let days = UCITime.upcomingDays(count: 5).dropFirst() // future days only
        guard let firstHall = await service.locations().first else { return }

        var unpublished = Set(UserDefaults.standard.stringArray(forKey: pendingDaysKey) ?? [])
        var notified = Set(UserDefaults.standard.stringArray(forKey: notifiedDaysKey) ?? [])
        let validDays = Set(days.map(\.isoDate))

        for day in days {
            // Any period returning stations means the day is published.
            let published = await isPublished(day: day.isoDate, hall: firstHall, service: service)

            if published {
                if unpublished.contains(day.isoDate) && !notified.contains(day.isoDate) {
                    notified.insert(day.isoDate)
                    let content = UNMutableNotificationContent()
                    content.title = "\(day.label)'s menu just dropped"
                    content.body = "UCI Dining posted it — take a peek and plan your meals."
                    content.sound = .default
                    try? await UNUserNotificationCenter.current().add(
                        UNNotificationRequest(identifier: "menudrop:\(day.isoDate)", content: content, trigger: nil)
                    )
                }
                unpublished.remove(day.isoDate)
            } else {
                unpublished.insert(day.isoDate)
            }
        }

        // Drop days that scrolled out of the window.
        UserDefaults.standard.set(Array(unpublished.intersection(validDays)).sorted(), forKey: pendingDaysKey)
        UserDefaults.standard.set(Array(notified.intersection(validDays)).sorted(), forKey: notifiedDaysKey)
    }

    private static func isPublished(day: String, hall: DiningLocation, service: DiningService) async -> Bool {
        // One representative period is enough; the 404 path returns empty stations.
        guard let period = hall.availablePeriods.first else { return false }
        let menu = try? await service.menu(for: hall.id, period: period, date: day)
        return !(menu?.stations.isEmpty ?? true)
    }
}

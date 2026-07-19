import Foundation
import UserNotifications
import BackgroundTasks
import ZotEatsKit

// Favorite-dish alerts: when a favorited dish shows up on today's menu,
// send one local notification per dish per day ("Zot! Crispy Okra is at
// The Anteatery today"). Checks run on foreground launches and via
// opportunistic background refresh — no servers, no push infrastructure.

@MainActor
enum FavoriteAlerts {
    static let refreshTaskID = "com.atharvgupta.zoteats.refresh"
    private static let enabledKey = "zoteats.favoriteAlertsEnabled"
    private static let notifiedKey = "zoteats.notifiedFavorites"

    static var isEnabled: Bool {
        get { UserDefaults.standard.bool(forKey: enabledKey) }
        set { UserDefaults.standard.set(newValue, forKey: enabledKey) }
    }

    /// Asks for notification permission; returns whether alerts can fire.
    static func requestPermission() async -> Bool {
        let center = UNUserNotificationCenter.current()
        let settings = await center.notificationSettings()
        switch settings.authorizationStatus {
        case .authorized, .provisional, .ephemeral:
            return true
        case .notDetermined:
            return (try? await center.requestAuthorization(options: [.alert, .sound, .badge])) ?? false
        default:
            return false
        }
    }

    /// Fetches today's menus, matches favorites, and notifies new matches.
    static func runCheck() async {
        guard isEnabled else { return }
        let favorites = Preferences().favoriteDishNames
        guard !favorites.isEmpty else { return }

        let service = DiningService()
        let locations = await service.locations()
        let hallNames = Dictionary(uniqueKeysWithValues: locations.map { ($0.id, $0.name) })

        let menus: [DiningMenu] = await withTaskGroup(of: DiningMenu?.self) { group in
            for location in locations {
                for period in location.availablePeriods {
                    group.addTask {
                        try? await service.menu(for: location.id, period: period)
                    }
                }
            }
            var collected: [DiningMenu] = []
            for await menu in group {
                if let menu { collected.append(menu) }
            }
            return collected
        }

        let dateISO = UCITime.upcomingDays(count: 1).first?.isoDate ?? ""
        var notified = Set(UserDefaults.standard.stringArray(forKey: notifiedKey) ?? [])

        for match in FavoritesMatcher.matches(favorites: favorites, menus: menus, hallNames: hallNames) {
            let key = match.dedupeKey(dateISO: dateISO)
            guard !notified.contains(key) else { continue }
            notified.insert(key)

            let content = UNMutableNotificationContent()
            content.title = "Zot! \(match.dishName) is on the menu"
            content.body = "Being served at \(match.hallName) for \(match.period.lowercased()) today."
            content.sound = .default
            try? await UNUserNotificationCenter.current().add(
                UNNotificationRequest(identifier: key, content: content, trigger: nil)
            )
        }

        // Keep only today's keys so the store doesn't grow forever.
        UserDefaults.standard.set(
            Array(notified.filter { $0.hasPrefix(dateISO) }),
            forKey: notifiedKey
        )
    }

    /// Asks iOS for the next opportunistic background check (~breakfast time next day).
    static func scheduleNextRefresh() {
        let request = BGAppRefreshTaskRequest(identifier: refreshTaskID)
        request.earliestBeginDate = Date(timeIntervalSinceNow: 4 * 60 * 60)
        try? BGTaskScheduler.shared.submit(request)
    }
}

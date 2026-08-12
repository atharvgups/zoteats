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

        var menus: [DiningMenu] = []
        for location in locations {
            // Primary pills only — menu(for:) resolves Brunch / Limited Dinner.
            for period in DiningService.primaryPeriods(from: location.availablePeriods) {
                if let menu = try? await service.menu(for: location.id, period: period) {
                    menus.append(menu)
                }
            }
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
            let deepLinkPeriod = MealPeriodPill.canonical(match.period)
            let link = AnteatsDeepLink.eat(
                hall: match.locationId,
                period: deepLinkPeriod,
                dish: match.dishName
            )
            content.userInfo = [
                "deeplink": link.url.absoluteString,
                "hallID": match.locationId,
                "hall": match.hallName,
                "period": deepLinkPeriod,
                "dish": match.dishName,
            ]
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

    /// Asks iOS for the next opportunistic background check, aiming near
    /// breakfast so favorite alerts land before the lunch rush.
    static func scheduleNextRefresh() {
        let request = BGAppRefreshTaskRequest(identifier: refreshTaskID)
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = TimeZone(identifier: "America/Los_Angeles") ?? .current
        let now = Date()
        var components = cal.dateComponents([.year, .month, .day], from: now)
        components.hour = 6
        components.minute = 45
        let todayTarget = cal.date(from: components) ?? now
        let tomorrowTarget = cal.date(byAdding: .day, value: 1, to: todayTarget) ?? now.addingTimeInterval(86_400)
        let preferred = todayTarget > now.addingTimeInterval(30 * 60) ? todayTarget : tomorrowTarget
        request.earliestBeginDate = max(preferred, now.addingTimeInterval(60 * 60))
        try? BGTaskScheduler.shared.submit(request)
    }

    /// Immediate local notification so testers can verify permission + banners.
    static func sendTestNotification() async {
        let granted = await requestPermission()
        guard granted else { return }
        let content = UNMutableNotificationContent()
        content.title = "Anteats alerts are on"
        content.body = "You'll get a ping when a hearted dish is on today's menu."
        content.sound = .default
        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: 1, repeats: false)
        try? await UNUserNotificationCenter.current().add(
            UNNotificationRequest(
                identifier: "anteats.test.\(Int(Date().timeIntervalSince1970))",
                content: content,
                trigger: trigger
            )
        )
    }
}

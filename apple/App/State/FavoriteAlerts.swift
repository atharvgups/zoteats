import Foundation
import UserNotifications
import BackgroundTasks
import ZotEatsKit

// Favorite-dish alerts: when a favorited dish shows up on today's menu,
// send a local notification ("Zot! Crispy Okra is on the menu"). One ping
// per dish per meal per day — "on today's menu" does not get a second
// "Being served now" follow-up. Checks run on foreground launches and via
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
        var hallPeriods: [String: (timed: [MealPeriodWindow], available: [String])] = [:]
        let nowMinutes = UCITime.nowMinutes()
        await withTaskGroup(of: DiningMenu?.self) { group in
            for location in locations {
                hallPeriods[location.id] = (location.periods, location.availablePeriods)
                for period in FavoriteAlertPeriods.eligible(
                    timedPeriods: location.periods,
                    availablePeriods: location.availablePeriods,
                    nowMinutes: nowMinutes
                ) {
                    group.addTask {
                        try? await service.menu(for: location.id, period: period)
                    }
                }
            }
            for await menu in group {
                if let menu { menus.append(menu) }
            }
        }

        let dateISO = UCITime.upcomingDays(count: 1).first?.isoDate ?? ""
        var notified = Set(UserDefaults.standard.stringArray(forKey: notifiedKey) ?? [])

        for match in FavoritesMatcher.matches(
            favorites: favorites,
            menus: menus,
            hallNames: hallNames,
            isServing: { locationId, period in
                guard let windows = hallPeriods[locationId] else { return false }
                return MealPillLiveness.isCurrentlyServing(
                    pill: MealPeriodPill.canonical(period),
                    timedPeriods: windows.timed,
                    availablePeriods: windows.available,
                    nowMinutes: nowMinutes
                )
            },
            periodStartMinutes: { locationId, period in
                guard let windows = hallPeriods[locationId] else { return nil }
                let pill = MealPeriodPill.canonical(period)
                return windows.timed.first(where: {
                    MealPeriodPill.canonical($0.name).caseInsensitiveCompare(pill) == .orderedSame
                })?.startMinutes
            }
        ) {
            let deepLinkPeriod = MealPeriodPill.canonical(match.period)
            let hallWindows = hallPeriods[match.locationId]
            let servingNow = hallWindows.map {
                MealPillLiveness.isCurrentlyServing(
                    pill: deepLinkPeriod,
                    timedPeriods: $0.timed,
                    availablePeriods: $0.available,
                    nowMinutes: nowMinutes
                )
            } ?? false

            guard FavoritesMatcher.shouldNotify(
                match: match,
                dateISO: dateISO,
                servingNow: servingNow,
                alreadyNotified: notified,
                earlierPeriodStillOpen: { pill in
                    hallPeriods.values.contains { windows in
                        MealPillLiveness.isLiveOrUpcoming(
                            pill: pill,
                            timedPeriods: windows.timed,
                            availablePeriods: windows.available,
                            nowMinutes: nowMinutes
                        )
                    }
                }
            ) else { continue }

            let phase: FavoritesMatcher.NotifyPhase = servingNow ? .serving : .upcoming
            let key = match.dedupeKey(dateISO: dateISO, phase: phase)
            notified.insert(key)
            notified.insert(match.bannerIdentifier(dateISO: dateISO))

            let content = UNMutableNotificationContent()
            content.title = "Zot! \(match.dishName) is on the menu"
            content.body = FavoriteAlertCopy.body(
                hallName: match.hallName,
                period: match.period,
                servingNow: servingNow
            )
            content.sound = .default
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
                UNNotificationRequest(
                    identifier: match.bannerIdentifier(dateISO: dateISO),
                    content: content,
                    trigger: nil
                )
            )
        }

        // Keep only today's keys so the store doesn't grow forever.
        UserDefaults.standard.set(
            Array(notified.filter { $0.hasPrefix(dateISO) }),
            forKey: notifiedKey
        )
    }

    /// Asks iOS for the next opportunistic background check, aiming near
    /// breakfast / lunch / dinner / evening menu drop, plus live meal opens
    /// and meal wrap-up (T−45) so Favorite Alerts and Live Activity auto-start
    /// can fire without waiting on Eat-tab foreground. While a hall still
    /// awaits Lunch/Dinner publish (or today's board is empty/unpublished),
    /// also short-lead the next publish probes so Opening Alerts can re-arm
    /// before a typical 11:00 / 16:00 open.
    static func scheduleNextRefresh(service: DiningService = DiningService()) async {
        let locations = await service.locations()
        let nowMinutes = UCITime.nowMinutes()
        let wrapUps = MealActivityAutoStart.wrapUpAimMinutes(locations: locations)
        let mealOpens = MealActivityAutoStart.mealOpenAimMinutes(locations: locations)
        let publishProbes: [Int] = {
            let needsProbe = locations.contains {
                DiningBoardPublish.shouldProbeForPublish(
                    periods: $0.periods,
                    nowMinutes: nowMinutes
                )
            }
            guard needsProbe else { return [] }
            return DiningBoardPublish.upcomingPublishProbeMinutes(nowMinutes: nowMinutes)
        }()
        let inWindow = MealActivityAutoStart.pick(
            locations: locations,
            nowMinutes: nowMinutes,
            alreadyTracking: false,
            autoEnabled: MealActivityManager.autoStartEnabled
        ) != nil
        let request = BGAppRefreshTaskRequest(identifier: refreshTaskID)
        request.earliestBeginDate = FavoriteAlertRefresh.earliestBeginDate(
            extraAimMinutes: wrapUps + mealOpens + publishProbes,
            allowImmediate: inWindow && MealActivityManager.autoStartEnabled
        )
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

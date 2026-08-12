import Foundation
import UserNotifications
import ZotEatsKit

// Opening alerts: "tell me the moment this spot opens." The user picks dining
// halls and campus venues in Settings; we schedule local notifications at
// today's opening times whenever fresh hours arrive (foreground + background
// refresh). Dining pre-arms every remaining meal today (Breakfast + Lunch +
// Dinner) plus tomorrow's full meal chain so a missed BG overnight can't drop
// Lunch; campus pre-arms every remaining today window (split schedules) plus
// tomorrow's full window chain — dining parity. No servers — iOS fires them
// even if the app stays closed.

@MainActor
enum OpeningAlerts {
    private static let watchedKey = "zoteats.openingAlertPlaces"
    private static let identifierPrefix = "open:"

    /// Namespaced place ids: "dining:<hallID>" or "campus:<placeID>".
    static var watchedIDs: Set<String> {
        get { Set(UserDefaults.standard.stringArray(forKey: watchedKey) ?? []) }
        set { UserDefaults.standard.set(Array(newValue).sorted(), forKey: watchedKey) }
    }

    static func isWatching(_ id: String) -> Bool {
        watchedIDs.contains(id)
    }

    static func setWatching(_ id: String, _ watching: Bool) {
        var ids = watchedIDs
        if watching { ids.insert(id) } else { ids.remove(id) }
        watchedIDs = ids
        Task { await refreshSchedules() }
    }

    /// Re-plans opening alerts from fresh hours. Cheap: services are TTL-cached,
    /// so foreground calls right after the stores load hit memory.
    static func refreshSchedules() async {
        let center = UNUserNotificationCenter.current()

        // Always clear our pending alerts first so deselected or re-planned
        // places never fire stale notifications.
        let pending = await center.pendingNotificationRequests()
            .map(\.identifier)
            .filter { $0.hasPrefix(identifierPrefix) }
        center.removePendingNotificationRequests(withIdentifiers: pending)

        let watched = watchedIDs
        guard !watched.isEmpty else { return }

        var candidates: [OpeningAlertPlanner.Candidate] = []

        let dining = DiningService()
        let nowMinutes = UCITime.nowMinutes()
        let tomorrowISO = UCITime.upcomingDays(count: 2).dropFirst().first?.isoDate

        for hall in await dining.locations() {
            let id = "dining:\(hall.id)"
            // Pre-arm every meal still ahead today (per-meal notification ids).
            for meal in OpeningAlertPlanner.followingMeals(
                periods: hall.periods, nowMinutes: nowMinutes
            ) {
                candidates.append(.init(
                    id: id,
                    name: hall.name,
                    opensAtMinutes: meal.startMinutes,
                    dayOffset: 0,
                    mealPeriod: meal.periodName,
                    closesAtMinutes: meal.endMinutes
                ))
            }
            // Pre-arm tomorrow's full meal chain overnight — Breakfast alone
            // still leaves Lunch/Dinner dependent on a morning BG that often
            // lands after they open.
            if let tomorrowISO {
                let periods = await dining.mealPeriods(for: hall.id, dateISO: tomorrowISO)
                for meal in OpeningAlertPlanner.allTimedMeals(periods: periods) {
                    candidates.append(.init(
                        id: id,
                        name: hall.name,
                        opensAtMinutes: meal.startMinutes,
                        dayOffset: 1,
                        mealPeriod: meal.periodName,
                        closesAtMinutes: meal.endMinutes
                    ))
                }
            }
        }

        for place in (try? await CampusService().places()) ?? [] {
            let id = "campus:\(place.id)"
            // Pre-arm every remaining today window (morning + afternoon reopen)
            // and tomorrow's full chain — dining multi-meal parity so a missed
            // BG after the morning open can't drop the afternoon ping.
            for window in place.upcomingWindows {
                candidates.append(.init(
                    id: id,
                    name: place.name,
                    opensAtMinutes: window.startMinutes,
                    dayOffset: 0,
                    closesAtMinutes: window.endMinutes,
                    windowStartMinutes: window.startMinutes
                ))
            }
            for window in place.tomorrowOpenWindows {
                candidates.append(.init(
                    id: id,
                    name: place.name,
                    opensAtMinutes: window.startMinutes,
                    dayOffset: 1,
                    closesAtMinutes: window.endMinutes,
                    hoursSpan: place.tomorrowHours,
                    windowStartMinutes: window.startMinutes
                ))
            }
            if let offset = place.opensNextDayOffset {
                for window in place.nextOpenWindows {
                    candidates.append(.init(
                        id: id,
                        name: place.name,
                        opensAtMinutes: window.startMinutes,
                        dayOffset: offset,
                        closesAtMinutes: window.endMinutes,
                        hoursSpan: place.nextOpenHours,
                        windowStartMinutes: window.startMinutes
                    ))
                }
            }
            if place.upcomingWindows.isEmpty,
               place.tomorrowOpenWindows.isEmpty,
               place.nextOpenWindows.isEmpty {
                candidates.append(.init(
                    id: id,
                    name: place.name,
                    opensAtMinutes: nil,
                    hoursSpan: place.nextOpenHours ?? place.tomorrowHours ?? place.todayHours
                ))
            }
        }

        for alert in OpeningAlertPlanner.plan(candidates: candidates, watchedIDs: watched) {
            let content = UNMutableNotificationContent()
            if let meal = alert.mealPeriod {
                let display = MealPeriodDisplay.label(live: meal)
                content.title = "\(alert.placeName) · \(display) just opened"
            } else {
                content.title = "\(alert.placeName) just opened"
            }
            // Dining meal close and campus per-window close both prefer
            // "Open until …"; hoursSpan is the continuous-day fallback.
            content.body = OpeningAlertCopy.body(
                openUntilMinutes: alert.closesAtMinutes,
                hoursSpan: alert.hoursSpan
            )
            content.sound = .default
            let link: AnteatsDeepLink = {
                if alert.placeID.hasPrefix("campus:") {
                    return .campus(placeID: String(alert.placeID.dropFirst("campus:".count)))
                }
                if alert.placeID.hasPrefix("dining:") {
                    // Deep links use primary Eat pills; titles keep live names.
                    let pill = alert.mealPeriod.map { MealPeriodPill.canonical($0) }
                    return .eat(
                        hall: String(alert.placeID.dropFirst("dining:".count)),
                        period: pill,
                        date: alert.deepLinkDate
                    )
                }
                return .eat()
            }()
            content.userInfo = [
                "deeplink": link.url.absoluteString,
                "place": alert.placeID,
            ]
            let trigger = UNTimeIntervalNotificationTrigger(
                timeInterval: max(1, alert.fireDate.timeIntervalSinceNow),
                repeats: false
            )
            try? await center.add(
                UNNotificationRequest(identifier: alert.identifier, content: content, trigger: trigger)
            )
        }
    }
}

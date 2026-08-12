import Foundation
import UserNotifications
import ZotEatsKit

// Opening alerts: "tell me the moment this spot opens." The user picks dining
// halls and campus venues in Settings; we schedule local notifications at
// today's opening times whenever fresh hours arrive (foreground + background
// refresh). Dining pre-arms every remaining meal today (Breakfast + Lunch +
// Dinner) plus tomorrow's first open so a missed BG refresh can't drop Lunch;
// campus still schedules a later same-day reopen or tomorrow morning. No
// servers — iOS fires them even if the app stays closed.

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
        /// Campus continuous hours only — dining bodies use meal close times.
        var campusHoursByID: [String: String] = [:]

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
            // Also arm tomorrow's first open while Lunch/Dinner is still ahead —
            // same honesty as campus overnight watches.
            if let tomorrowISO {
                let periods = await dining.mealPeriods(for: hall.id, dateISO: tomorrowISO)
                if let meal = OpeningAlertPlanner.earliestMeal(periods: periods) {
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
            if let todayOpen = place.opensAtMinutes {
                // Includes later same-day reopens while currently open.
                candidates.append(.init(
                    id: id, name: place.name, opensAtMinutes: todayOpen, dayOffset: 0
                ))
                if let hours = place.todayHours { campusHoursByID[id] = hours }
            } else if let tomorrowOpen = place.opensTomorrowAtMinutes {
                // Open now or done for today — still schedule tomorrow morning.
                candidates.append(.init(
                    id: id, name: place.name, opensAtMinutes: tomorrowOpen, dayOffset: 1
                ))
                if let hours = place.tomorrowHours { campusHoursByID[id] = hours }
            } else {
                candidates.append(.init(id: id, name: place.name, opensAtMinutes: nil))
                if let hours = place.todayHours { campusHoursByID[id] = hours }
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
            if alert.placeID.hasPrefix("dining:") {
                content.body = OpeningAlertCopy.body(openUntilMinutes: alert.closesAtMinutes)
            } else {
                content.body = OpeningAlertCopy.body(hoursSpan: campusHoursByID[alert.placeID])
            }
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

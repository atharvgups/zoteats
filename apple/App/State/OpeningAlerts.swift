import Foundation
import UserNotifications
import ZotEatsKit

// Opening alerts: "tell me the moment this spot opens." The user picks dining
// halls and campus venues in Settings; we schedule local notifications at
// today's opening times whenever fresh hours arrive (foreground + background
// refresh). After the last window of the day, we schedule tomorrow's first
// open so evening watchers still get a morning ping. No servers — iOS fires
// them even if the app stays closed.

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
        var hoursByID: [String: String] = [:]

        let dining = DiningService()
        let nowMinutes = UCITime.nowMinutes()
        let tomorrowISO = UCITime.upcomingDays(count: 2).dropFirst().first?.isoDate

        for hall in await dining.locations() {
            let id = "dining:\(hall.id)"
            if hall.openNow {
                candidates.append(.init(id: id, name: hall.name, opensAtMinutes: nil))
                if let hours = hall.todayHours { hoursByID[id] = hours }
                continue
            }
            if let todayOpen = OpeningAlertPlanner.nextOpening(
                periods: hall.periods, nowMinutes: nowMinutes
            ) {
                candidates.append(.init(
                    id: id, name: hall.name, opensAtMinutes: todayOpen, dayOffset: 0
                ))
                if let hours = hall.todayHours { hoursByID[id] = hours }
            } else if let tomorrowISO {
                let periods = await dining.mealPeriods(for: hall.id, dateISO: tomorrowISO)
                if let open = OpeningAlertPlanner.earliestOpening(periods: periods) {
                    candidates.append(.init(
                        id: id, name: hall.name, opensAtMinutes: open, dayOffset: 1
                    ))
                    if let summary = Self.hoursSummary(periods: periods) {
                        hoursByID[id] = summary
                    }
                }
            }
        }

        for place in (try? await CampusService().places()) ?? [] {
            let id = "campus:\(place.id)"
            if let todayOpen = place.opensAtMinutes {
                candidates.append(.init(
                    id: id, name: place.name, opensAtMinutes: todayOpen, dayOffset: 0
                ))
                if let hours = place.todayHours { hoursByID[id] = hours }
            } else if !place.openNow, let tomorrowOpen = place.opensTomorrowAtMinutes {
                candidates.append(.init(
                    id: id, name: place.name, opensAtMinutes: tomorrowOpen, dayOffset: 1
                ))
                // tomorrowHours isn't on the model — fall back to a generic body.
            } else {
                candidates.append(.init(id: id, name: place.name, opensAtMinutes: nil))
                if let hours = place.todayHours { hoursByID[id] = hours }
            }
        }

        for alert in OpeningAlertPlanner.plan(candidates: candidates, watchedIDs: watched) {
            let content = UNMutableNotificationContent()
            content.title = "\(alert.placeName) just opened"
            if let hours = hoursByID[alert.placeID] {
                content.body = "Open \(hours). Head over when you're ready."
            } else {
                content.body = "Doors are open — head over when you're ready."
            }
            content.sound = .default
            content.userInfo = ["place": alert.placeID]
            let trigger = UNTimeIntervalNotificationTrigger(
                timeInterval: max(1, alert.fireDate.timeIntervalSinceNow),
                repeats: false
            )
            try? await center.add(
                UNNotificationRequest(identifier: alert.identifier, content: content, trigger: trigger)
            )
        }
    }

    private static func hoursSummary(periods: [MealPeriodWindow]) -> String? {
        let starts = periods.compactMap(\.startMinutes)
        let ends = periods.compactMap(\.endMinutes)
        guard let start = starts.min(), let end = ends.max() else { return nil }
        return "\(UCITime.format(minutes: start)) – \(UCITime.format(minutes: end))"
    }
}

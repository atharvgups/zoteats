import Foundation
import UserNotifications
import ZotEatsKit

// Opening alerts: "tell me the moment this spot opens." The user picks dining
// halls and campus venues in Settings; we schedule local notifications at
// today's opening times whenever fresh hours arrive (foreground + background
// refresh). No servers — iOS fires them even if the app stays closed.

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

    /// Re-plans today's alerts from fresh hours. Cheap: services are TTL-cached,
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

        let nowMinutes = UCITime.nowMinutes()
        for hall in await DiningService().locations() {
            let id = "dining:\(hall.id)"
            candidates.append(.init(
                id: id,
                name: hall.name,
                opensAtMinutes: hall.openNow
                    ? nil
                    : OpeningAlertPlanner.nextOpening(periods: hall.periods, nowMinutes: nowMinutes)
            ))
            if let hours = hall.todayHours { hoursByID[id] = hours }
        }
        for place in (try? await CampusService().places()) ?? [] {
            let id = "campus:\(place.id)"
            candidates.append(.init(id: id, name: place.name, opensAtMinutes: place.opensAtMinutes))
            if let hours = place.todayHours { hoursByID[id] = hours }
        }

        for alert in OpeningAlertPlanner.plan(candidates: candidates, watchedIDs: watched) {
            let content = UNMutableNotificationContent()
            content.title = "\(alert.placeName) just opened"
            if let hours = hoursByID[alert.placeID] {
                content.body = "Open today \(hours). Zot on over."
            } else {
                content.body = "Doors are open — zot on over."
            }
            content.sound = .default
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

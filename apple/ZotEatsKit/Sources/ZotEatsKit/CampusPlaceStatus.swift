import Foundation

/// Live Campus open/close fields derived from schedule windows.
/// Kept pure so `CampusService.places()` can TTL-cache windows and still
/// flip `openNow` / boundary minutes on every read (app ↔ widget parity).
public enum CampusPlaceStatus {
    public struct Snapshot: Equatable, Sendable {
        public let openNow: Bool
        public let todayHours: String?
        /// Formatted tomorrow windows for Opening Alerts overnight schedules.
        public let tomorrowHours: String?
        public let opensAtMinutes: Int?
        public let closesAtMinutes: Int?
        /// Start of the window covering now (Opening Alerts late-BG catch-up).
        public let currentOpenStartMinutes: Int?
        public let opensTomorrowAtMinutes: Int?
        /// Schedule was resolved from the feed (including explicit "off").
        public let hoursKnown: Bool

        public init(
            openNow: Bool,
            todayHours: String?,
            tomorrowHours: String? = nil,
            opensAtMinutes: Int?,
            closesAtMinutes: Int?,
            currentOpenStartMinutes: Int? = nil,
            opensTomorrowAtMinutes: Int?,
            hoursKnown: Bool = true
        ) {
            self.openNow = openNow
            self.todayHours = todayHours
            self.tomorrowHours = tomorrowHours
            self.opensAtMinutes = opensAtMinutes
            self.closesAtMinutes = closesAtMinutes
            self.currentOpenStartMinutes = currentOpenStartMinutes
            self.opensTomorrowAtMinutes = opensTomorrowAtMinutes
            self.hoursKnown = hoursKnown
        }
    }

    public static func evaluate(
        todayWindows: [CampusService.TimeWindow],
        tomorrowWindows: [CampusService.TimeWindow],
        nowMinutes: Int,
        todayScheduleResolved: Bool = true
    ) -> Snapshot {
        let openNow = todayWindows.contains { $0.contains(minute: nowMinutes) }
        let currentTimed = todayWindows.first(where: {
            $0.contains(minute: nowMinutes) && !$0.isAllDay
        })
        let closesAt: Int? = {
            guard let current = currentTimed else { return nil }
            // Midnight-crossing windows: treat end as next-day minutes for dating.
            return current.end % (24 * 60) == 0 && current.end >= 24 * 60
                ? 24 * 60
                : current.end
        }()
        return Snapshot(
            openNow: openNow,
            todayHours: CampusService.format(windows: todayWindows),
            tomorrowHours: CampusService.format(windows: tomorrowWindows),
            opensAtMinutes: CampusService.nextOpeningMinutes(
                windows: todayWindows,
                nowMinutes: nowMinutes
            ),
            closesAtMinutes: closesAt,
            currentOpenStartMinutes: currentTimed.map(\.start),
            opensTomorrowAtMinutes: tomorrowWindows.map(\.start).min(),
            hoursKnown: todayScheduleResolved || !tomorrowWindows.isEmpty
        )
    }
}

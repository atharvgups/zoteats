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
        public let opensTomorrowAtMinutes: Int?

        public init(
            openNow: Bool,
            todayHours: String?,
            tomorrowHours: String? = nil,
            opensAtMinutes: Int?,
            closesAtMinutes: Int?,
            opensTomorrowAtMinutes: Int?
        ) {
            self.openNow = openNow
            self.todayHours = todayHours
            self.tomorrowHours = tomorrowHours
            self.opensAtMinutes = opensAtMinutes
            self.closesAtMinutes = closesAtMinutes
            self.opensTomorrowAtMinutes = opensTomorrowAtMinutes
        }
    }

    public static func evaluate(
        todayWindows: [CampusService.TimeWindow],
        tomorrowWindows: [CampusService.TimeWindow],
        nowMinutes: Int
    ) -> Snapshot {
        let openNow = todayWindows.contains { $0.contains(minute: nowMinutes) }
        let closesAt: Int? = {
            guard openNow else { return nil }
            // End of the window covering now (skip all-day — no useful boundary).
            guard let current = todayWindows.first(where: { $0.contains(minute: nowMinutes) }),
                  !current.isAllDay
            else { return nil }
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
            opensTomorrowAtMinutes: tomorrowWindows.map(\.start).min()
        )
    }
}

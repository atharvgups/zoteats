import Foundation

/// WidgetKit reload points for Today's Menu — meal start while still closed,
/// Irvine midnight, and tomorrow's first open after hours so StandBy doesn't
/// sit on "Dinner's done…" for up to the 30m cap after breakfast is live.
public enum TodaysMenuReload {
    public static func boundaries(
        upcomingStartMinutes: Int?,
        isAfterHours: Bool,
        opensTomorrowAtMinutes: Int?,
        nowMinutes: Int,
        now: Date = Date()
    ) -> [Date] {
        var dates: [Date] = [UCITime.nextIrvineMidnight(now: now)]
        if let start = upcomingStartMinutes {
            dates.append(UCITime.date(forMinutes: start, nowMinutes: nowMinutes, now: now))
        }
        if isAfterHours, let open = opensTomorrowAtMinutes {
            dates.append(UCITime.date(forMinutes: open, nowMinutes: nowMinutes, now: now))
        }
        return dates
    }
}

import Foundation

/// WidgetKit reload points for Today's Menu — every hall's meal open/close
/// (Auto can switch halls at a sibling's edge), Irvine midnight, and each
/// hall's tomorrow open so StandBy doesn't sit on the wrong board for up to
/// the 30m cap after another hall starts serving.
public enum TodaysMenuReload {
    public static func boundaries(
        locations: [DiningLocation],
        nowMinutes: Int,
        now: Date = Date()
    ) -> [Date] {
        var dates: [Date] = [UCITime.nextIrvineMidnight(now: now)]
        for hall in locations {
            for window in hall.periods {
                if let start = window.startMinutes {
                    dates.append(
                        UCITime.date(forMinutes: start, nowMinutes: nowMinutes, now: now)
                    )
                }
                if let end = window.endMinutes {
                    dates.append(
                        UCITime.date(forMinutes: end, nowMinutes: nowMinutes, now: now)
                    )
                }
            }
            if let open = hall.opensTomorrowAtMinutes {
                dates.append(
                    UCITime.date(forMinutes: open, nowMinutes: nowMinutes, now: now)
                )
            }
        }
        return dates
    }

    public static func nextReload(
        locations: [DiningLocation],
        nowMinutes: Int,
        now: Date = Date(),
        maxInterval: TimeInterval = 30 * 60
    ) -> Date {
        WidgetRefreshMath.nextReload(
            now: now,
            boundaries: boundaries(
                locations: locations,
                nowMinutes: nowMinutes,
                now: now
            ),
            maxInterval: maxInterval
        )
    }
}

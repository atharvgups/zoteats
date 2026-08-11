import Foundation

/// Reload boundaries for the Campus Open Now widget — open/close / tomorrow
/// open, plus Irvine midnight so overnight glances don't wait on the 20m cap.
public enum CampusOpenReload {
    public static func boundaries(
        places: [CampusPlace],
        now: Date = Date()
    ) -> [Date] {
        let nowMinutes = UCITime.nowMinutes(now: now)
        var dates: [Date] = [UCITime.nextIrvineMidnight(now: now)]
        for place in places {
            if let minutes = place.closesAtMinutes {
                dates.append(UCITime.date(forMinutes: minutes, nowMinutes: nowMinutes, now: now))
            }
            if let minutes = place.opensAtMinutes {
                dates.append(UCITime.date(forMinutes: minutes, nowMinutes: nowMinutes, now: now))
            }
            if let minutes = place.opensTomorrowAtMinutes {
                dates.append(UCITime.date(forMinutes: minutes, nowMinutes: nowMinutes, now: now))
            }
        }
        return dates
    }

    public static func nextReload(
        now: Date = Date(),
        places: [CampusPlace],
        maxInterval: TimeInterval = 20 * 60
    ) -> Date {
        WidgetRefreshMath.nextReload(
            now: now,
            boundaries: boundaries(places: places, now: now),
            maxInterval: maxInterval
        )
    }
}

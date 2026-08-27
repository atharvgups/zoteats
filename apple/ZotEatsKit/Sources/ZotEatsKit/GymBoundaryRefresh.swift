import Foundation

/// In-app Gym schedule refresh — same open/close + Irvine midnight + Waitz
/// Closed-until reopen / live-range close + 15m Waitz cadence as the ARC widget
/// (`ArcStatusProvider`), so StatusPill / crowding / rush “now” and overnight
/// “Opens tomorrow” flip while the Gym tab stays open.
public enum GymBoundaryRefresh {
    public static let maxInterval: TimeInterval = 15 * 60

    public static func boundaries(
        now: Date = Date(),
        reopenMinutes: Int? = nil,
        closeMinutes: Int? = nil
    ) -> [Date] {
        var dates: [Date] = [UCITime.nextIrvineMidnight(now: now)]
        if let boundary = GymService.nextScheduleBoundary(now: now) {
            dates.append(boundary)
        }
        let nowMinutes = UCITime.nowMinutes(now: now)
        if let reopen = reopenMinutes {
            dates.append(UCITime.date(forMinutes: reopen, nowMinutes: nowMinutes, now: now))
        }
        if let close = closeMinutes {
            dates.append(UCITime.date(forMinutes: close, nowMinutes: nowMinutes, now: now))
        }
        return dates
    }

    public static func nextFire(
        now: Date = Date(),
        reopenMinutes: Int? = nil,
        closeMinutes: Int? = nil,
        maxInterval: TimeInterval = maxInterval
    ) -> Date {
        WidgetRefreshMath.nextReload(
            now: now,
            boundaries: boundaries(
                now: now,
                reopenMinutes: reopenMinutes,
                closeMinutes: closeMinutes
            ),
            maxInterval: maxInterval
        )
    }
}

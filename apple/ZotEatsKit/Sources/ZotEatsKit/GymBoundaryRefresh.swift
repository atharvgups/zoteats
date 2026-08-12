import Foundation

/// In-app Gym schedule refresh — same open/close + Irvine midnight + 15m Waitz
/// cadence as the ARC widget (`ArcStatusProvider`), so StatusPill / crowding /
/// rush “now” and overnight “Opens tomorrow” flip while the Gym tab stays open.
public enum GymBoundaryRefresh {
    public static let maxInterval: TimeInterval = 15 * 60

    public static func boundaries(now: Date = Date()) -> [Date] {
        var dates: [Date] = [UCITime.nextIrvineMidnight(now: now)]
        if let boundary = GymService.nextScheduleBoundary(now: now) {
            dates.append(boundary)
        }
        return dates
    }

    public static func nextFire(now: Date = Date(), maxInterval: TimeInterval = maxInterval) -> Date {
        WidgetRefreshMath.nextReload(
            now: now,
            boundaries: boundaries(now: now),
            maxInterval: maxInterval
        )
    }
}

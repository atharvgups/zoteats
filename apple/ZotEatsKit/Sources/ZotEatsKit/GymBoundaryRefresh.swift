import Foundation

/// In-app Gym schedule refresh — same open/close + 15m Waitz cadence as the
/// ARC widget (`ArcStatusProvider`), so StatusPill / crowding / rush “now”
/// flip while the Gym tab stays open.
public enum GymBoundaryRefresh {
    public static let maxInterval: TimeInterval = 15 * 60

    public static func boundaries(now: Date = Date()) -> [Date] {
        GymService.nextScheduleBoundary(now: now).map { [$0] } ?? []
    }

    public static func nextFire(now: Date = Date(), maxInterval: TimeInterval = maxInterval) -> Date {
        WidgetRefreshMath.nextReload(
            now: now,
            boundaries: boundaries(now: now),
            maxInterval: maxInterval
        )
    }
}

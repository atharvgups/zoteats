import Foundation

/// Foreground wrap-up cadence for Live Activity auto-start on any tab
/// (Eat unloaded). Same T−45 aims as `MealActivityAutoStart.wrapUpAimMinutes`.
public enum MealActivityWrapUpRefresh {
    public static let maxInterval: TimeInterval = 15 * 60

    public static func nextFire(
        locations: [DiningLocation],
        now: Date = Date(),
        maxInterval: TimeInterval = maxInterval
    ) -> Date {
        let nowMinutes = UCITime.nowMinutes(now: now)
        let boundaries = MealActivityAutoStart.wrapUpAimMinutes(locations: locations).map {
            UCITime.date(forMinutes: $0, nowMinutes: nowMinutes, now: now)
        }
        return WidgetRefreshMath.nextReload(
            now: now,
            boundaries: boundaries,
            maxInterval: maxInterval
        )
    }
}

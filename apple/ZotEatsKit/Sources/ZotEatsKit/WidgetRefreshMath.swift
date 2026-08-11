import Foundation

/// Pure helpers for WidgetKit timeline reload times.
/// Prefer refreshing at the next open/close / meal boundary so Home Screen
/// and StandBy glances don't sit on stale "open" / lunch dishes after the
/// window ends — while still capping how long we wait if nothing's upcoming.
public enum WidgetRefreshMath {
    /// Earliest future boundary, otherwise `now + maxInterval`.
    /// A 2-second pad past the boundary lets countdowns finish and the next
    /// fetch see the post-boundary open state.
    public static func nextReload(
        now: Date,
        boundaries: [Date],
        maxInterval: TimeInterval,
        padPastBoundary: TimeInterval = 2
    ) -> Date {
        let cap = now.addingTimeInterval(max(60, maxInterval))
        let soonest = boundaries
            .filter { $0 > now }
            .min()
        guard let soonest else { return cap }
        let afterBoundary = soonest.addingTimeInterval(max(0, padPastBoundary))
        return min(afterBoundary, cap)
    }
}

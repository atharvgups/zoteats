import Foundation

/// In-app Eat meal-boundary refresh — same honesty widgets get from
/// `TodaysMenuReload` / `WidgetRefreshMath`, so hall chrome, sticky pills,
/// and Live Activity auto-start update while the Eat tab stays open.
public enum EatBoundaryRefresh {
    /// Cap between ticks when no meal boundary is near (matches Dining Status).
    public static let maxInterval: TimeInterval = 15 * 60

    /// Open/close edges for every loaded hall, Irvine midnight, and the
    /// selected meal's Live Activity auto-start (final 45 minutes).
    public static func boundaries(
        hallPeriods: [[MealPeriodWindow]],
        selectedTimedPeriods: [MealPeriodWindow],
        selectedAvailablePeriods: [String],
        selectedPill: String?,
        nowMinutes: Int,
        now: Date = Date()
    ) -> [Date] {
        var dates: [Date] = [UCITime.nextIrvineMidnight(now: now)]

        for periods in hallPeriods {
            for window in periods {
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
        }

        if let pill = selectedPill,
           let window = MealTrackWindow.resolve(
            pill: pill,
            timedPeriods: selectedTimedPeriods,
            availablePeriods: selectedAvailablePeriods
           ) {
            let autoAt = window.endMinutes - MealTrackMath.autoStartWindowMinutes
            if autoAt > window.startMinutes {
                dates.append(
                    UCITime.date(forMinutes: autoAt, nowMinutes: nowMinutes, now: now)
                )
            }
        }

        return dates
    }

    public static func nextFire(
        hallPeriods: [[MealPeriodWindow]],
        selectedTimedPeriods: [MealPeriodWindow],
        selectedAvailablePeriods: [String],
        selectedPill: String?,
        nowMinutes: Int,
        now: Date = Date(),
        maxInterval: TimeInterval = maxInterval
    ) -> Date {
        WidgetRefreshMath.nextReload(
            now: now,
            boundaries: boundaries(
                hallPeriods: hallPeriods,
                selectedTimedPeriods: selectedTimedPeriods,
                selectedAvailablePeriods: selectedAvailablePeriods,
                selectedPill: selectedPill,
                nowMinutes: nowMinutes,
                now: now
            ),
            maxInterval: maxInterval
        )
    }
}

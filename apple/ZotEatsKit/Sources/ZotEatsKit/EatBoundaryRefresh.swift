import Foundation

/// In-app Eat meal-boundary refresh — same honesty widgets get from
/// `TodaysMenuReload` / `WidgetRefreshMath`, so hall chrome, sticky pills,
/// and Live Activity auto-start update while the Eat tab stays open.
///
/// Callers must purge live `"today"` menus at Irvine midnight
/// (`DiningStore.ensureCurrentDay`), reload locations, and snap the day strip
/// (`EatDateSelection.snapLiveToday`) — the fire date alone does not refresh data.
public enum EatBoundaryRefresh {
    /// Cap between ticks when no meal boundary is near (matches Dining Status).
    public static let maxInterval: TimeInterval = 15 * 60

    /// Open/close edges for every loaded hall, Irvine midnight, **every**
    /// hall's Live Activity wrap-up (end − 45) — not only the selected pill —
    /// so Anteatery selected still ticks when Brandywine enters T−45 — plus
    /// Lunch/Dinner publish probes while a board is still awaiting more meals.
    public static func boundaries(
        hallPeriods: [[MealPeriodWindow]],
        nowMinutes: Int,
        now: Date = Date()
    ) -> [Date] {
        var dates: [Date] = [UCITime.nextIrvineMidnight(now: now)]
        var awaitingPublish = false

        for periods in hallPeriods {
            if DiningBoardPublish.awaitingLaterMeals(
                periods: periods,
                nowMinutes: nowMinutes
            ) {
                awaitingPublish = true
            }
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
                    if let start = window.startMinutes {
                        let autoAt = end - MealTrackMath.autoStartWindowMinutes
                        if autoAt > start {
                            dates.append(
                                UCITime.date(forMinutes: autoAt, nowMinutes: nowMinutes, now: now)
                            )
                        }
                    }
                }
            }
        }

        if awaitingPublish {
            dates.append(contentsOf: DiningBoardPublish.futurePublishProbeDates(
                nowMinutes: nowMinutes,
                now: now
            ))
        }

        return dates
    }

    public static func nextFire(
        hallPeriods: [[MealPeriodWindow]],
        nowMinutes: Int,
        now: Date = Date(),
        maxInterval: TimeInterval = maxInterval
    ) -> Date {
        WidgetRefreshMath.nextReload(
            now: now,
            boundaries: boundaries(
                hallPeriods: hallPeriods,
                nowMinutes: nowMinutes,
                now: now
            ),
            maxInterval: maxInterval
        )
    }
}

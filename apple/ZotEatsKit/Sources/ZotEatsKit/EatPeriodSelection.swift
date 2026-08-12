import Foundation

/// Eat tab meal-pill selection — same after-hours truth as Today's Menu.
/// Sticky picks stay only while live or still upcoming; ended meals advance
/// to the next window (or clear after hours) so Eat matches Today's Menu.
public enum EatPeriodSelection {
    /// Resolve the period pill to show for a hall.
    /// - Parameters:
    ///   - current: Existing selection (may be user/deeplink).
    ///   - browsingFutureDay: When true, skip live/after-hours rules and keep a valid pill.
    public static func snap(
        current: String?,
        availablePeriods: [String],
        timedPeriods: [MealPeriodWindow],
        nowMinutes: Int,
        browsingFutureDay: Bool
    ) -> String? {
        let pills = DiningService.primaryPeriods(from: availablePeriods)
        guard !pills.isEmpty else { return nil }

        if browsingFutureDay {
            if let current, pills.contains(current) { return current }
            return pills.first
        }

        let choice = TodaysMenuPeriodPick.choose(
            timedPeriods: timedPeriods,
            availablePeriods: availablePeriods,
            nowMinutes: nowMinutes
        )

        if choice.isAfterHours {
            // Drop auto/stale serving picks so Eat matches the widget empty state.
            // Eat deep links use `EatDeepLinkPeriod` so they can't re-pin Dinner after this.
            return nil
        }

        if let current,
           pills.contains(current),
           MealPillLiveness.isLiveOrUpcoming(
            pill: current,
            timedPeriods: timedPeriods,
            pills: pills,
            nowMinutes: nowMinutes
           ) {
            return current
        }

        return choice.period.isEmpty ? nil : choice.period
    }
}

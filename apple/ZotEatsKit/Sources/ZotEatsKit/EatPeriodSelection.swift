import Foundation

/// Eat tab meal-pill selection — same after-hours truth as Today's Menu.
/// Never auto-picks last night's Dinner; overnight warm launches clear a
/// serving selection whose window has already ended.
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
            // Deeplinks that set a period after sync still win until the next snap.
            return nil
        }

        if let current, pills.contains(current) {
            return current
        }

        return choice.period.isEmpty ? nil : choice.period
    }
}

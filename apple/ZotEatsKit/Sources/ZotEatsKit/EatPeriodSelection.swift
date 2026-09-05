import Foundation

/// Eat tab meal-pill selection — same after-hours truth as Today's Menu.
/// Sticky picks stay only while live or still upcoming; ended meals advance
/// to the next window (or clear after hours) so Eat matches Today's Menu.
/// Partial boards awaiting later meals keep the last posted pill browsable.
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
        // Eat chips are always Breakfast / Lunch / Dinner — not only what's posted.
        let pills = DiningService.mealSelectorPills
        // Board-backed pills for window matching (Brunch → Breakfast, etc.).
        let boardPills = DiningService.primaryPeriods(from: availablePeriods)
        let matchPills = boardPills.isEmpty ? pills : boardPills

        if browsingFutureDay {
            if let current, pills.contains(current) { return current }
            // Prefer a period that day actually published; else first chip.
            if let firstBoard = boardPills.first { return firstBoard }
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

        // Keep a user/deeplink peek unless that meal's window has already ended.
        // Unposted Lunch/Dinner (no window yet) stay sticky at 7am.
        if let current,
           pills.contains(current),
           !MealPillLiveness.hasEnded(
            pill: current,
            timedPeriods: timedPeriods,
            pills: matchPills,
            nowMinutes: nowMinutes
           ) {
            return current
        }

        return choice.period.isEmpty ? nil : choice.period
    }
}

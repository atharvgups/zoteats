import Foundation

/// Period to apply from an Eat deep link / notification — after-hours clears,
/// and an ended meal falls through to the live or upcoming pill (same liveness
/// gate as Eat's sticky pill via `MealPillLiveness`). Future-day browse (Menu
/// Drop date-only links included) snaps the first primary pill when none is
/// requested.
///
/// Dish deep links (Favorite Alerts, shared dish URLs) pass
/// `preserveRequestedMeal: true` so an ended Lunch still opens the Lunch board
/// where the dish lives, instead of remapping to Dinner / clearing after hours.
public enum EatDeepLinkPeriod {
    public static func resolve(
        requested: String?,
        availablePeriods: [String],
        timedPeriods: [MealPeriodWindow],
        nowMinutes: Int,
        browsingFutureDay: Bool,
        preserveRequestedMeal: Bool = false
    ) -> String? {
        let pills = DiningService.primaryPeriods(from: availablePeriods)
        guard !pills.isEmpty else { return nil }

        if browsingFutureDay {
            if let requested, let match = MealPeriodPill.match(requested, in: pills) {
                return match
            }
            return pills.first
        }

        // Favorite / dish targets: keep the named meal whenever it exists on the
        // board, even when ended or after hours.
        if preserveRequestedMeal,
           let requested,
           let pill = MealPeriodPill.match(requested, in: pills) {
            return pill
        }

        let choice = TodaysMenuPeriodPick.choose(
            timedPeriods: timedPeriods,
            availablePeriods: availablePeriods,
            nowMinutes: nowMinutes
        )
        if choice.isAfterHours {
            return nil
        }

        if let requested,
           let pill = MealPeriodPill.match(requested, in: pills),
           MealPillLiveness.isLiveOrUpcoming(
            pill: pill,
            timedPeriods: timedPeriods,
            pills: pills,
            nowMinutes: nowMinutes
           ) {
            return pill
        }

        return choice.period.isEmpty ? nil : choice.period
    }
}

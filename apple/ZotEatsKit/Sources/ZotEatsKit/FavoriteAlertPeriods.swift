import Foundation

/// Which primary meal pills Favorite Alerts should fetch for a hall today.
/// Ended Breakfast/Lunch (and after-hours leftovers) must not ping "today"
/// when that meal is already over.
public enum FavoriteAlertPeriods {
    public static func eligible(
        timedPeriods: [MealPeriodWindow],
        availablePeriods: [String],
        nowMinutes: Int
    ) -> [String] {
        let pills = DiningService.primaryPeriods(from: availablePeriods)
        guard !pills.isEmpty else { return [] }

        let choice = TodaysMenuPeriodPick.choose(
            timedPeriods: timedPeriods,
            availablePeriods: availablePeriods,
            nowMinutes: nowMinutes
        )
        if choice.isAfterHours {
            return []
        }

        return pills.filter { pill in
            MealPillLiveness.isLiveOrUpcoming(
                pill: pill,
                timedPeriods: timedPeriods,
                pills: pills,
                nowMinutes: nowMinutes
            )
        }
    }
}

import Foundation

/// Period to apply from an Eat deep link / notification — after-hours clears,
/// and an ended meal falls through to the live or upcoming pill (same liveness
/// gate as Eat's sticky pill via `MealPillLiveness`).
public enum EatDeepLinkPeriod {
    public static func resolve(
        requested: String?,
        availablePeriods: [String],
        timedPeriods: [MealPeriodWindow],
        nowMinutes: Int,
        browsingFutureDay: Bool
    ) -> String? {
        let pills = DiningService.primaryPeriods(from: availablePeriods)
        guard !pills.isEmpty else { return nil }

        if browsingFutureDay {
            if let requested, let match = Self.matchPill(requested, in: pills) {
                return match
            }
            return pills.first
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
           let pill = Self.matchPill(requested, in: pills),
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

    private static func matchPill(_ requested: String, in pills: [String]) -> String? {
        pills.first { $0.caseInsensitiveCompare(requested) == .orderedSame }
    }
}

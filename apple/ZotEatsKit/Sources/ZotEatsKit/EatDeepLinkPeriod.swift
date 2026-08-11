import Foundation

/// Period to apply from an Eat deep link / notification — after-hours clears,
/// and an ended meal falls through to the live or upcoming pill (unlike the
/// in-tab sticky pill, which can keep last night's Dinner until the next snap).
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
           Self.isLiveOrUpcoming(
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

    /// True while the meal's window has not yet ended today.
    private static func isLiveOrUpcoming(
        pill: String,
        timedPeriods: [MealPeriodWindow],
        pills: [String],
        nowMinutes: Int
    ) -> Bool {
        for window in timedPeriods {
            guard let end = window.endMinutes else { continue }
            let windowPill = Self.primaryPill(for: window.name, pills: pills)
            guard windowPill.caseInsensitiveCompare(pill) == .orderedSame else { continue }
            if nowMinutes < end { return true }
        }
        return false
    }

    private static func primaryPill(for liveName: String, pills: [String]) -> String {
        let lower = liveName.lowercased()
        if lower.contains("brunch") || lower.contains("breakfast"), pills.contains("Breakfast") {
            return "Breakfast"
        }
        if lower.contains("lunch"), pills.contains("Lunch") { return "Lunch" }
        if lower.contains("dinner"), pills.contains("Dinner") { return "Dinner" }
        return pills.first { liveName.caseInsensitiveCompare($0) == .orderedSame } ?? liveName
    }
}

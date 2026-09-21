import Foundation

/// Honest Eat copy when Twisted Root is on today's board, but not this meal.
/// Never invents dishes for a period the hall didn't post.
public enum TwistedRootBoardCopy {
    /// One-line caption. Nil when this meal already has the station, or the
    /// station isn't posted on any Breakfast / Lunch / Dinner board today.
    public static func otherMealsNote(
        selectedPeriod: String,
        mealsToday: [String]
    ) -> String? {
        let selected = MealPeriodPill.canonical(selectedPeriod)
        let meals = DiningService.mealSelectorPills.filter { pill in
            mealsToday.contains { $0.caseInsensitiveCompare(pill) == .orderedSame }
        }
        guard !meals.isEmpty else { return nil }
        if meals.contains(where: { $0.caseInsensitiveCompare(selected) == .orderedSame }) {
            return nil
        }
        return "Twisted Root isn't on \(selected). It's on \(join(meals)) today."
    }

    static func join(_ meals: [String]) -> String {
        switch meals.count {
        case 0: return ""
        case 1: return meals[0]
        case 2: return "\(meals[0]) and \(meals[1])"
        default:
            let head = meals.dropLast().joined(separator: ", ")
            return "\(head), and \(meals.last!)"
        }
    }
}

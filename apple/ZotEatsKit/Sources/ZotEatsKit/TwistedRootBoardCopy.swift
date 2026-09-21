import Foundation

/// Honest copy when Twisted Root isn't on the selected Eat pill.
/// Never invents dishes — only names meals the live board actually posted.
public enum TwistedRootBoardCopy {
    /// Nil when the current pill already listed Twisted Root.
    public static func message(currentMeal: String, postedMeals: [String]) -> String? {
        let current = MealPeriodPill.canonical(currentMeal)
        let posted = uniquePills(postedMeals)
        if posted.contains(where: { $0.caseInsensitiveCompare(current) == .orderedSame }) {
            return nil
        }
        if posted.isEmpty {
            return "Twisted Root isn’t posted today."
        }
        let meal = current.isEmpty ? "this meal" : current
        return "Twisted Root isn’t posted for \(meal). It’s on \(joinMeals(posted)) today."
    }

    /// First other posted pill, for a "See Lunch" jump. Nil when there's nowhere to go.
    public static func actionMeal(currentMeal: String, postedMeals: [String]) -> String? {
        let current = MealPeriodPill.canonical(currentMeal)
        return uniquePills(postedMeals).first {
            $0.caseInsensitiveCompare(current) != .orderedSame
        }
    }

    public static func actionTitle(currentMeal: String, postedMeals: [String]) -> String? {
        guard let meal = actionMeal(currentMeal: currentMeal, postedMeals: postedMeals) else {
            return nil
        }
        return "See \(meal)"
    }

    static func uniquePills(_ meals: [String]) -> [String] {
        var seen = Set<String>()
        var result: [String] = []
        for meal in meals {
            let pill = MealPeriodPill.canonical(meal)
            guard !pill.isEmpty, seen.insert(pill.lowercased()).inserted else { continue }
            result.append(pill)
        }
        return result
    }

    static func joinMeals(_ meals: [String]) -> String {
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

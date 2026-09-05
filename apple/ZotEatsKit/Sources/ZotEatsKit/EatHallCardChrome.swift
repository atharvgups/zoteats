import Foundation

/// Short 3-across Eat hall status — meal now / next, never a clock essay.
public enum EatHallCardChrome: Sendable {
    public static func statusText(
        comingSoon: Bool,
        state: HallOpenState,
        opensTomorrowPeriod: String?,
        opensNextPeriod: String?
    ) -> String {
        if comingSoon { return OasisComingSoonCopy.cardStatus }
        switch state {
        case .open(let period, _):
            return MealPeriodPill.canonical(period)
        case .openingLater(let period, _):
            return "\(MealPeriodPill.canonical(period)) soon"
        case .awaitingMoreMeals:
            return "Later"
        case .closedForToday:
            if let meal = opensTomorrowPeriod ?? opensNextPeriod {
                return "\(MealPeriodPill.canonical(meal)) next"
            }
            return "Closed"
        case .unknown:
            return "Soon"
        }
    }
}

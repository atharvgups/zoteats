import Foundation

/// Short 3-across Eat hall status — open/closed plus meal, never a clock essay.
public struct EatHallCardStatus: Sendable, Equatable {
    public let primary: String
    public let secondary: String?

    public init(primary: String, secondary: String? = nil) {
        self.primary = primary
        self.secondary = secondary
    }

    public var accessibilityLine: String {
        if let secondary, !secondary.isEmpty {
            return "\(primary), \(secondary)"
        }
        return primary
    }
}

public enum EatHallCardChrome: Sendable {
    public static func status(
        comingSoon: Bool,
        state: HallOpenState,
        opensTomorrowPeriod: String?,
        opensNextPeriod: String?
    ) -> EatHallCardStatus {
        if comingSoon {
            return EatHallCardStatus(primary: OasisComingSoonCopy.cardStatus)
        }
        switch state {
        case .open(let period, _):
            return EatHallCardStatus(
                primary: "Open",
                secondary: MealPeriodPill.canonical(period)
            )
        case .openingLater(let period, _):
            return EatHallCardStatus(
                primary: "Soon",
                secondary: MealPeriodPill.canonical(period)
            )
        case .awaitingMoreMeals:
            return EatHallCardStatus(primary: "Later")
        case .closedForToday:
            if let meal = opensTomorrowPeriod ?? opensNextPeriod {
                return EatHallCardStatus(
                    primary: "Closed",
                    secondary: MealPeriodPill.canonical(meal)
                )
            }
            return EatHallCardStatus(primary: "Closed")
        case .unknown:
            return EatHallCardStatus(primary: "Soon")
        }
    }

    public static func statusText(
        comingSoon: Bool,
        state: HallOpenState,
        opensTomorrowPeriod: String?,
        opensNextPeriod: String?
    ) -> String {
        status(
            comingSoon: comingSoon,
            state: state,
            opensTomorrowPeriod: opensTomorrowPeriod,
            opensNextPeriod: opensNextPeriod
        ).accessibilityLine
    }
}

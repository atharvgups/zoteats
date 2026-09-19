import Foundation

/// Short 3-across Eat hall status — one small line under the name:
/// Closed / Dinner / Coming Soon. Never a clock essay or paragraph.
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
        opensTomorrowPeriod _: String?,
        opensNextPeriod _: String?
    ) -> EatHallCardStatus {
        if comingSoon {
            return EatHallCardStatus(primary: OasisComingSoonCopy.cardStatus)
        }
        switch state {
        case .open(let period, _):
            return EatHallCardStatus(primary: MealPeriodPill.canonical(period))
        case .openingLater(let period, _):
            return EatHallCardStatus(primary: MealPeriodPill.canonical(period))
        case .awaitingMoreMeals, .closedForToday, .unknown:
            return EatHallCardStatus(primary: "Closed")
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

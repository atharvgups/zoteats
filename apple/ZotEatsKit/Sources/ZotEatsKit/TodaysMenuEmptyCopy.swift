import Foundation

/// Empty-state copy for Today's Menu when the board has no dishes.
/// After hours with a known tomorrow open names that meal (and time) so the
/// glance matches the tomorrow deep link — not "wait overnight" while tap
/// already opens tomorrow's Breakfast.
public enum TodaysMenuEmptyCopy {
    public enum Surface: Equatable, Sendable {
        case glance
        case home
    }

    public static func afterHours(
        opensTomorrowPeriod: String?,
        opensTomorrowAtMinutes: Int?,
        surface: Surface
    ) -> String {
        if let open = opensTomorrowAtMinutes {
            let meal = MealPeriodPill.canonical(opensTomorrowPeriod ?? "Breakfast")
            let time = UCITime.format(minutes: open)
            switch surface {
            case .glance:
                return "\(meal) tomorrow · \(time)"
            case .home:
                return "Dinner's done — \(meal) tomorrow · \(time)"
            }
        }
        switch surface {
        case .glance:
            return "See you at breakfast"
        case .home:
            return "Dinner's done — breakfast posts overnight"
        }
    }

    public static func reason(
        periodIsEmpty: Bool,
        filtersEmptiedMenu: Bool,
        opensTomorrowPeriod: String?,
        opensTomorrowAtMinutes: Int?,
        surface: Surface
    ) -> String {
        if filtersEmptiedMenu {
            return surface == .glance
                ? "Nothing matches Eat Filters"
                : "Nothing matches your Eat Filters"
        }
        if periodIsEmpty {
            return afterHours(
                opensTomorrowPeriod: opensTomorrowPeriod,
                opensTomorrowAtMinutes: opensTomorrowAtMinutes,
                surface: surface
            )
        }
        return surface == .glance
            ? "Menu not posted yet"
            : "No menu posted right now — check back at the next meal"
    }
}

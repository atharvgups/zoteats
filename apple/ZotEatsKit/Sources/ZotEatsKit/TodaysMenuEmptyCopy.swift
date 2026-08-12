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

    /// Eat tab after-hours empty message — hall + tomorrow meal/time when known.
    public static func eatAfterHoursMessage(
        hallName: String,
        opensTomorrowPeriod: String?,
        opensTomorrowAtMinutes: Int?
    ) -> String {
        let hall = hallName.trimmingCharacters(in: .whitespacesAndNewlines)
        let name = hall.isEmpty ? "This hall" : hall
        if let open = opensTomorrowAtMinutes {
            let meal = MealPeriodPill.canonical(opensTomorrowPeriod ?? "Breakfast")
            let time = UCITime.format(minutes: open)
            return "\(name) is closed for tonight. \(meal) tomorrow · \(time)."
        }
        return "\(name) is closed for tonight. Breakfast posts overnight — or pick tomorrow in the day strip."
    }

    /// Tomorrow's Irvine ISO for Eat "See tomorrow" CTA / deep links.
    public static func tomorrowISO(now: Date = Date()) -> String? {
        UCITime.upcomingDays(count: 2, now: now).dropFirst().first?.isoDate
    }

    public static func reason(
        periodIsEmpty: Bool,
        filtersEmptiedMenu: Bool,
        opensTomorrowPeriod: String?,
        opensTomorrowAtMinutes: Int?,
        surface: Surface,
        period: String = "",
        upcomingStartMinutes: Int? = nil
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
        if let start = upcomingStartMinutes {
            let meal = period.isEmpty ? "Next meal" : period
            let time = UCITime.format(minutes: start)
            switch surface {
            case .glance:
                return "\(meal) starts at \(time)"
            case .home:
                return "\(meal) starts at \(time) — dishes post when it opens"
            }
        }
        return surface == .glance
            ? "Menu not posted yet"
            : "No menu posted right now — check back at the next meal"
    }
}

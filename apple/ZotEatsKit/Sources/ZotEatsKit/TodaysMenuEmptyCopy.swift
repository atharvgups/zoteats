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
        surface: Surface,
        opensNextPeriod: String? = nil,
        opensNextAtMinutes: Int? = nil,
        opensNextWeekday: String? = nil
    ) -> String {
        if let open = opensTomorrowAtMinutes {
            let meal = MealPeriodDisplay.label(
                live: opensTomorrowPeriod ?? "",
                pill: "Breakfast"
            )
            let time = UCITime.format(minutes: open)
            switch surface {
            case .glance:
                return "\(meal) tomorrow · \(time)"
            case .home:
                return "Dinner's done — \(meal) tomorrow · \(time)"
            }
        }
        if let open = opensNextAtMinutes,
           let weekday = opensNextWeekday,
           !weekday.isEmpty {
            let meal = MealPeriodDisplay.label(
                live: opensNextPeriod ?? "",
                pill: "Breakfast"
            )
            let time = UCITime.format(minutes: open)
            switch surface {
            case .glance:
                return "\(meal) \(weekday) · \(time)"
            case .home:
                return "Dinner's done — \(meal) \(weekday) · \(time)"
            }
        }
        switch surface {
        case .glance:
            return "See you at breakfast"
        case .home:
            return "Dinner's done — breakfast posts overnight"
        }
    }

    /// Partial board after Breakfast (Dinner not posted yet).
    public static func awaitingMoreMeals(surface: Surface) -> String {
        switch surface {
        case .glance:
            return "More meals post later"
        case .home:
            return "More meals still posting today — pull to refresh"
        }
    }

    /// Eat tab after-hours empty message — hall + next meal/time when known.
    public static func eatAfterHoursMessage(
        hallName: String,
        opensTomorrowPeriod: String?,
        opensTomorrowAtMinutes: Int?,
        opensNextPeriod: String? = nil,
        opensNextAtMinutes: Int? = nil,
        opensNextWeekday: String? = nil
    ) -> String {
        let hall = hallName.trimmingCharacters(in: .whitespacesAndNewlines)
        let name = hall.isEmpty ? "This hall" : hall
        if let open = opensTomorrowAtMinutes {
            let meal = MealPeriodDisplay.label(
                live: opensTomorrowPeriod ?? "",
                pill: "Breakfast"
            )
            let time = UCITime.format(minutes: open)
            return "\(name) is closed for tonight. \(meal) tomorrow · \(time)."
        }
        if let open = opensNextAtMinutes,
           let weekday = opensNextWeekday,
           !weekday.isEmpty {
            let meal = MealPeriodDisplay.label(
                live: opensNextPeriod ?? "",
                pill: "Breakfast"
            )
            let time = UCITime.format(minutes: open)
            return "\(name) is closed for tonight. \(meal) \(weekday) · \(time)."
        }
        return "\(name) is closed for tonight. Breakfast posts overnight — or pick the next day in the day strip."
    }

    /// Tomorrow's Irvine ISO for Eat "See tomorrow" CTA / deep links.
    public static func tomorrowISO(now: Date = Date()) -> String? {
        UCITime.upcomingDays(count: 2, now: now).dropFirst().first?.isoDate
    }

    /// Next-open ISO when jumping past an empty tomorrow (dayOffset ≥ 2).
    public static func nextOpenISO(dayOffset: Int, now: Date = Date()) -> String? {
        guard dayOffset >= 1 else { return nil }
        return UCITime.upcomingDays(count: dayOffset + 1, now: now)
            .dropFirst(dayOffset)
            .first?
            .isoDate
    }

    /// Eat after-hours empty CTA — "See tomorrow" or "See Monday" to match the jump.
    public static func afterHoursActionTitle(
        opensTomorrowAtMinutes: Int?,
        opensNextWeekday: String?
    ) -> String {
        if opensTomorrowAtMinutes != nil {
            return "See tomorrow"
        }
        if let weekday = opensNextWeekday?.trimmingCharacters(in: .whitespacesAndNewlines),
           !weekday.isEmpty {
            return "See \(weekday)"
        }
        return "See tomorrow"
    }

    public static func reason(
        periodIsEmpty: Bool,
        filtersEmptiedMenu: Bool,
        opensTomorrowPeriod: String?,
        opensTomorrowAtMinutes: Int?,
        surface: Surface,
        period: String = "",
        upcomingStartMinutes: Int? = nil,
        awaitingMoreMeals: Bool = false,
        opensNextPeriod: String? = nil,
        opensNextAtMinutes: Int? = nil,
        opensNextWeekday: String? = nil
    ) -> String {
        if filtersEmptiedMenu {
            return surface == .glance
                ? "Nothing matches Eat Filters"
                : "Nothing matches your Eat Filters"
        }
        if awaitingMoreMeals {
            return Self.awaitingMoreMeals(surface: surface)
        }
        if periodIsEmpty {
            return afterHours(
                opensTomorrowPeriod: opensTomorrowPeriod,
                opensTomorrowAtMinutes: opensTomorrowAtMinutes,
                surface: surface,
                opensNextPeriod: opensNextPeriod,
                opensNextAtMinutes: opensNextAtMinutes,
                opensNextWeekday: opensNextWeekday
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

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
        opensNextWeekday: String? = nil,
        emptyBoard: Bool = false
    ) -> String {
        if let open = opensTomorrowAtMinutes {
            let meal = MealPeriodDisplay.label(
                live: opensTomorrowPeriod ?? "",
                pill: "Breakfast"
            )
            let time = UCITime.format(minutes: open)
            let next = "\(meal) tomorrow · \(time)"
            // Empty/unpublished boards never served Dinner — Status parity, no
            // "Dinner's done" framing (weekend daytime next-open path).
            if emptyBoard || surface == .glance { return next }
            return "Dinner's done — \(next)"
        }
        if let open = opensNextAtMinutes,
           let weekday = opensNextWeekday,
           !weekday.isEmpty {
            let meal = MealPeriodDisplay.label(
                live: opensNextPeriod ?? "",
                pill: "Breakfast"
            )
            let time = UCITime.format(minutes: open)
            let next = "\(meal) \(weekday) · \(time)"
            if emptyBoard || surface == .glance { return next }
            return "Dinner's done — \(next)"
        }
        switch surface {
        case .glance:
            // Match Status / widgets: no invented overnight breakfast when
            // neither tomorrow nor a later next-open is known.
            return "Closed for today"
        case .home:
            if emptyBoard { return "Closed for today" }
            return "Dinner's done — closed for today"
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

    /// Eat tab empty title when the selected hall has no selectable meal pill.
    public static func eatIdleEmptyTitle(
        awaitingMoreMeals: Bool,
        afterHours: Bool,
        emptyBoard: Bool = false
    ) -> String {
        if awaitingMoreMeals { return "More meals coming" }
        if afterHours {
            // Unpublished day — Status says Closed for today, not Dinner's done.
            return emptyBoard ? "Closed for today" : "Dinner's done"
        }
        return "No menu yet"
    }

    /// Eat tab empty message for a partial board (Breakfast/Lunch posted; later meals pending).
    public static func eatAwaitingMoreMealsMessage(hallName: String) -> String {
        let hall = hallName.trimmingCharacters(in: .whitespacesAndNewlines)
        let name = hall.isEmpty ? "This hall" : hall
        return "\(name) already posted earlier meals — Lunch or Dinner often lands later. Pull to refresh."
    }

    /// Eat tab after-hours empty message — hall + next meal/time when known.
    public static func eatAfterHoursMessage(
        hallName: String,
        opensTomorrowPeriod: String?,
        opensTomorrowAtMinutes: Int?,
        opensNextPeriod: String? = nil,
        opensNextAtMinutes: Int? = nil,
        opensNextWeekday: String? = nil,
        emptyBoard: Bool = false
    ) -> String {
        let hall = hallName.trimmingCharacters(in: .whitespacesAndNewlines)
        let name = hall.isEmpty ? "This hall" : hall
        if let open = opensTomorrowAtMinutes {
            let meal = MealPeriodDisplay.label(
                live: opensTomorrowPeriod ?? "",
                pill: "Breakfast"
            )
            let time = UCITime.format(minutes: open)
            if emptyBoard {
                return "\(name) isn't serving today. \(meal) tomorrow · \(time)."
            }
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
            if emptyBoard {
                return "\(name) isn't serving today. \(meal) \(weekday) · \(time)."
            }
            return "\(name) is closed for tonight. \(meal) \(weekday) · \(time)."
        }
        if emptyBoard {
            return "\(name) isn't serving today."
        }
        return "\(name) is closed for tonight."
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

    /// Day-strip ISO for Eat after-hours CTA — only when a real next open is known.
    public static func afterHoursJumpISO(
        opensTomorrowAtMinutes: Int?,
        opensNextDateISO: String?,
        opensNextDayOffset: Int?,
        now: Date = Date()
    ) -> String? {
        if opensTomorrowAtMinutes != nil {
            return tomorrowISO(now: now)
        }
        if let iso = opensNextDateISO?.trimmingCharacters(in: .whitespacesAndNewlines),
           !iso.isEmpty {
            return iso
        }
        return opensNextDayOffset.flatMap { nextOpenISO(dayOffset: $0, now: now) }
    }

    /// Eat after-hours empty CTA — "See tomorrow" / "See Monday" only when that jump exists.
    /// Nil means refresh (no invented day-strip jump).
    public static func afterHoursActionTitle(
        opensTomorrowAtMinutes: Int?,
        opensNextWeekday: String?
    ) -> String? {
        if opensTomorrowAtMinutes != nil {
            return "See tomorrow"
        }
        if let weekday = opensNextWeekday?.trimmingCharacters(in: .whitespacesAndNewlines),
           !weekday.isEmpty {
            return "See \(weekday)"
        }
        return nil
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
        opensNextWeekday: String? = nil,
        isAfterHours: Bool = false,
        emptyBoard: Bool = false
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
            // Empty timed board (unpublished / 404) is not after-hours — Eat already
            // says "No menu yet"; don't claim Dinner's done / Closed for today.
            guard isAfterHours else {
                return surface == .glance
                    ? "Menu not posted yet"
                    : "No menu posted right now — check back at the next meal"
            }
            return afterHours(
                opensTomorrowPeriod: opensTomorrowPeriod,
                opensTomorrowAtMinutes: opensTomorrowAtMinutes,
                surface: surface,
                opensNextPeriod: opensNextPeriod,
                opensNextAtMinutes: opensNextAtMinutes,
                opensNextWeekday: opensNextWeekday,
                emptyBoard: emptyBoard
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

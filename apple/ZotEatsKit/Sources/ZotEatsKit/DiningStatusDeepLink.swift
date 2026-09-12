import Foundation

/// Eat destination for Dining Status hall-row deep links.
/// Open / opening-later rows carry today's live meal; after hours with a known
/// tomorrow open jump to tomorrow's board (period + date) instead of Eat's
/// empty after-hours state.
public enum DiningStatusDeepLink {
    public struct Destination: Equatable, Sendable {
        public let period: String?
        public let date: String?

        public init(period: String?, date: String? = nil) {
            self.period = period
            self.date = date
        }
    }

    public static func destination(
        for state: HallOpenState,
        availablePeriods: [String],
        opensTomorrowAtMinutes: Int? = nil,
        opensTomorrowPeriod: String? = nil,
        now: Date = Date(),
        opensNextAtMinutes: Int? = nil,
        opensNextDayOffset: Int? = nil,
        opensNextPeriod: String? = nil,
        opensNextDateISO: String? = nil,
        timedPeriods: [MealPeriodWindow] = [],
        nowMinutes: Int? = nil
    ) -> Destination {
        switch state {
        case .open(let period, _), .openingLater(let period, _):
            return Destination(
                period: MealPeriodPill.match(period, in: DiningService.primaryPeriods(from: availablePeriods))
            )
        case .awaitingMoreMeals:
            // Stay on today's board — deep-link the last posted meal so Eat /
            // widgets don't wipe to empty while Lunch/Dinner may still publish.
            let minutes = nowMinutes ?? UCITime.nowMinutes(now: now)
            let choice = TodaysMenuPeriodPick.choose(
                timedPeriods: timedPeriods,
                availablePeriods: availablePeriods,
                nowMinutes: minutes
            )
            let period = choice.period.isEmpty ? nil : choice.period
            return Destination(period: period)
        case .closedForToday:
            if opensTomorrowAtMinutes != nil {
                // Tomorrow's meal is independent of today's pills (weekend Brunch
                // must not gate weekday Breakfast / Lunch deep links).
                let period = opensTomorrowPeriod.map { MealPeriodPill.canonical($0) }
                let tomorrow = UCITime.upcomingDays(count: 2, now: now).dropFirst().first?.isoDate
                return Destination(period: period, date: tomorrow)
            }
            if opensNextAtMinutes != nil {
                let period = opensNextPeriod.map { MealPeriodPill.canonical($0) }
                let iso = opensNextDateISO
                    ?? opensNextDayOffset.flatMap { offset in
                        UCITime.upcomingDays(count: offset + 1, now: now)
                            .dropFirst(offset)
                            .first?
                            .isoDate
                    }
                return Destination(period: period, date: iso)
            }
            return Destination(period: nil)
        case .unknown:
            return Destination(period: nil)
        }
    }

    /// Period-only convenience (same-day open / opening-later; after hours nil
    /// unless tomorrow / later open metadata is passed through `destination`).
    public static func period(
        for state: HallOpenState,
        availablePeriods: [String],
        opensTomorrowAtMinutes: Int? = nil,
        opensTomorrowPeriod: String? = nil,
        now: Date = Date(),
        opensNextAtMinutes: Int? = nil,
        opensNextDayOffset: Int? = nil,
        opensNextPeriod: String? = nil,
        opensNextDateISO: String? = nil,
        timedPeriods: [MealPeriodWindow] = [],
        nowMinutes: Int? = nil
    ) -> String? {
        destination(
            for: state,
            availablePeriods: availablePeriods,
            opensTomorrowAtMinutes: opensTomorrowAtMinutes,
            opensTomorrowPeriod: opensTomorrowPeriod,
            now: now,
            opensNextAtMinutes: opensNextAtMinutes,
            opensNextDayOffset: opensNextDayOffset,
            opensNextPeriod: opensNextPeriod,
            opensNextDateISO: opensNextDateISO,
            timedPeriods: timedPeriods,
            nowMinutes: nowMinutes
        ).period
    }
}

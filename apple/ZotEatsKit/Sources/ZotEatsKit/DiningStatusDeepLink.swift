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
        now: Date = Date()
    ) -> Destination {
        switch state {
        case .open(let period, _), .openingLater(let period, _):
            return Destination(
                period: MealPeriodPill.match(period, in: DiningService.primaryPeriods(from: availablePeriods))
            )
        case .closedForToday:
            guard opensTomorrowAtMinutes != nil else {
                return Destination(period: nil)
            }
            // Tomorrow's meal is independent of today's pills (weekend Brunch
            // must not gate weekday Breakfast / Lunch deep links).
            let period = opensTomorrowPeriod.map { MealPeriodPill.canonical($0) }
            let tomorrow = UCITime.upcomingDays(count: 2, now: now).dropFirst().first?.isoDate
            return Destination(period: period, date: tomorrow)
        case .unknown:
            return Destination(period: nil)
        }
    }

    /// Period-only convenience (same-day open / opening-later; after hours nil
    /// unless tomorrow open metadata is passed through `destination`).
    public static func period(
        for state: HallOpenState,
        availablePeriods: [String],
        opensTomorrowAtMinutes: Int? = nil,
        opensTomorrowPeriod: String? = nil,
        now: Date = Date()
    ) -> String? {
        destination(
            for: state,
            availablePeriods: availablePeriods,
            opensTomorrowAtMinutes: opensTomorrowAtMinutes,
            opensTomorrowPeriod: opensTomorrowPeriod,
            now: now
        ).period
    }
}

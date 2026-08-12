import Foundation

/// Where the meal-end Live Activity should send the user after `endsAt`.
/// Prefer the next same-day meal (Lunch → Dinner); only fall through to
/// tomorrow when today's board looks done — Dining Status after-hours parity
/// (skip tomorrow while Dinner may still publish).
public enum MealActivityPostClose {
    public struct Destination: Equatable, Sendable {
        public let period: String?
        public let date: String?

        public init(period: String?, date: String? = nil) {
            self.period = period
            self.date = date
        }
    }

    /// Resolve at track/auto-start time from the current meal's end and hall windows.
    public static func destination(
        currentPeriodEndMinutes: Int,
        timedPeriods: [MealPeriodWindow],
        opensTomorrowPeriod: String?,
        now: Date = Date()
    ) -> Destination {
        if let next = timedPeriods
            .compactMap({ window -> (name: String, start: Int)? in
                guard let start = window.startMinutes, start > currentPeriodEndMinutes else {
                    return nil
                }
                return (window.name, start)
            })
            .min(by: { $0.start < $1.start }) {
            return Destination(period: MealPeriodPill.canonical(next.name))
        }

        // Breakfast-only (or Lunch without Dinner) boards often still publish
        // later — don't bake tomorrow into the Island while Status says
        // "More meals post later". Evaluate as of meal end.
        if DiningBoardPublish.awaitingLaterMeals(
            periods: timedPeriods,
            nowMinutes: currentPeriodEndMinutes
        ) {
            return Destination(period: nil)
        }

        let tomorrowMeal = opensTomorrowPeriod?
            .trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        guard !tomorrowMeal.isEmpty else {
            return Destination(period: nil)
        }
        let tomorrow = UCITime.upcomingDays(count: 2, now: now).dropFirst().first?.isoDate
        return Destination(
            period: MealPeriodPill.canonical(tomorrowMeal),
            date: tomorrow
        )
    }
}

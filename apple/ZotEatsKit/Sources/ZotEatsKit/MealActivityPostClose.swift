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
        now: Date = Date(),
        opensNextPeriod: String? = nil,
        opensNextDayOffset: Int? = nil,
        opensNextDateISO: String? = nil
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
        if !tomorrowMeal.isEmpty {
            let tomorrow = UCITime.upcomingDays(count: 2, now: now).dropFirst().first?.isoDate
            return Destination(
                period: MealPeriodPill.canonical(tomorrowMeal),
                date: tomorrow
            )
        }

        let nextMeal = opensNextPeriod?
            .trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        if !nextMeal.isEmpty {
            let iso = opensNextDateISO
                ?? opensNextDayOffset.flatMap { offset in
                    TodaysMenuEmptyCopy.nextOpenISO(dayOffset: offset, now: now)
                }
            return Destination(
                period: MealPeriodPill.canonical(nextMeal),
                date: iso
            )
        }

        return Destination(period: nil)
    }

    /// `opensTomorrowPeriod` for Live Activity ContentState after resolving
    /// post-close. Always nil — stashing the hall's tomorrow meal when
    /// `postClose.period` is nil re-enables DeepLink's legacy overnight jump
    /// on Breakfast-only / Lunch-without-Dinner boards (Island said done;
    /// tap opened tomorrow while Status still said more meals post later).
    public static func contentOpensTomorrowPeriod(
        postClose: Destination,
        hallOpensTomorrowPeriod: String?
    ) -> String? {
        _ = hallOpensTomorrowPeriod
        // Destination already encodes tomorrow / next-open when known.
        // Hall-only (nil period) must not arm the legacy DeepLink path.
        _ = postClose
        return nil
    }
}

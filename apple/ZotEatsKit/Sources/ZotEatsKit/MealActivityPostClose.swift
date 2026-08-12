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
        // "More meals post later". Deep-link the last posted meal (Eat /
        // Status / Today's Menu parity) instead of a hall-only wipe.
        if DiningBoardPublish.awaitingLaterMeals(
            periods: timedPeriods,
            nowMinutes: currentPeriodEndMinutes
        ) {
            let timed = timedPeriods.filter {
                $0.startMinutes != nil && $0.endMinutes != nil
            }
            if let lastEnded = timed
                .filter({ ($0.endMinutes ?? Int.min) <= currentPeriodEndMinutes })
                .max(by: { $0.endMinutes! < $1.endMinutes! })
            {
                return Destination(period: MealPeriodPill.canonical(lastEnded.name))
            }
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

    /// True when a Live Activity's baked post-close should be rewritten from a
    /// fresher hall board (Lunch/Dinner published during countdown or linger).
    public static func needsRefresh(
        currentPeriod: String?,
        currentDate: String?,
        fresh: Destination
    ) -> Bool {
        normalize(currentPeriod) != normalize(fresh.period)
            || normalize(currentDate) != normalize(fresh.date)
    }

    /// End minute for the meal an activity is tracking — used to recompute
    /// post-close against an updated board.
    public static func trackedPeriodEndMinutes(
        trackedPeriod: String,
        timedPeriods: [MealPeriodWindow]
    ) -> Int? {
        let tracked = trackedPeriod.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !tracked.isEmpty else { return nil }
        if let exact = timedPeriods.first(where: {
            $0.name.caseInsensitiveCompare(tracked) == .orderedSame
        }), let end = exact.endMinutes {
            return end
        }
        let pill = MealPeriodPill.canonical(tracked)
        return timedPeriods.first(where: {
            MealPeriodPill.canonical($0.name).caseInsensitiveCompare(pill) == .orderedSame
        })?.endMinutes
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

    private static func normalize(_ value: String?) -> String {
        value?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
    }
}

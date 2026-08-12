import Foundation

/// Eat destination for the meal-end Live Activity.
/// While the meal is live: today's hall + tracked period. After `endsAt`:
/// use the post-close destination resolved at track time (next meal today, or
/// tomorrow when after hours). Legacy activities that only stash
/// `opensTomorrowPeriod` (no `postClosePeriod`) keep the overnight fallback —
/// new starts must not stash hall tomorrow when post-close is hall-only
/// (`MealActivityPostClose.contentOpensTomorrowPeriod`).
public enum MealActivityDeepLink {
    public static func link(
        hallID: String?,
        period: String,
        endsAt: Date,
        postClosePeriod: String? = nil,
        postCloseDate: String? = nil,
        opensTomorrowPeriod: String? = nil,
        now: Date = Date()
    ) -> AnteatsDeepLink {
        let hall = hallID.flatMap { $0.trimmingCharacters(in: .whitespacesAndNewlines).nilIfEmpty }

        if now < endsAt {
            return .eat(
                hall: hall,
                period: MealPeriodPill.canonical(period)
            )
        }

        if let pill = postClosePeriod?
            .trimmingCharacters(in: .whitespacesAndNewlines),
           !pill.isEmpty {
            let date = postCloseDate?
                .trimmingCharacters(in: .whitespacesAndNewlines)
                .nilIfEmpty
            return .eat(hall: hall, period: MealPeriodPill.canonical(pill), date: date)
        }

        // Legacy ContentState: only tomorrow was stashed.
        guard let tomorrowMeal = opensTomorrowPeriod?
            .trimmingCharacters(in: .whitespacesAndNewlines),
              !tomorrowMeal.isEmpty
        else {
            return .eat(hall: hall)
        }

        let tomorrow = UCITime.upcomingDays(count: 2, now: now).dropFirst().first?.isoDate
        return .eat(
            hall: hall,
            period: MealPeriodPill.canonical(tomorrowMeal),
            date: tomorrow
        )
    }
}

private extension String {
    var nilIfEmpty: String? {
        let trimmed = trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }
}

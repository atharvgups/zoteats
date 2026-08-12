import Foundation

/// Eat destination for the meal-end Live Activity.
/// While the meal is live: today's hall + tracked period. After `endsAt`:
/// jump to tomorrow's board when known (Dining Status after-hours parity),
/// otherwise hall-only so we don't reopen a finished Dinner pill.
public enum MealActivityDeepLink {
    public static func link(
        hallID: String?,
        period: String,
        endsAt: Date,
        opensTomorrowPeriod: String?,
        now: Date = Date()
    ) -> AnteatsDeepLink {
        let hall = hallID.flatMap { $0.trimmingCharacters(in: .whitespacesAndNewlines).nilIfEmpty }

        if now < endsAt {
            return .eat(
                hall: hall,
                period: MealPeriodPill.canonical(period)
            )
        }

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

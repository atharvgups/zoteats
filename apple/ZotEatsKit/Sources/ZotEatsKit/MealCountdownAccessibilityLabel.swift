import Foundation

/// VoiceOver for the meal-end Live Activity — hall, period, and Pacific
/// wall-clock end (not the live timer digits VoiceOver fragments poorly).
public enum MealCountdownAccessibilityLabel {
    public static func label(
        hallName: String,
        period: String,
        endsAt: Date,
        now: Date = Date()
    ) -> String {
        let hall = hallName.trimmingCharacters(in: .whitespacesAndNewlines)
        let meal = period.trimmingCharacters(in: .whitespacesAndNewlines)
        let time = UCITime.format(minutes: UCITime.nowMinutes(now: endsAt))
        let ended = MealCountdownChrome.hasEnded(endsAt: endsAt, now: now)

        var parts: [String] = []
        if !hall.isEmpty {
            parts.append(hall)
        }
        if ended {
            if !meal.isEmpty {
                parts.append("\(meal) has ended")
            } else {
                parts.append("Meal has ended")
            }
        } else if !meal.isEmpty {
            parts.append("\(meal) ends at \(time)")
        } else {
            parts.append("Ends at \(time)")
        }
        return parts.joined(separator: ", ")
    }
}

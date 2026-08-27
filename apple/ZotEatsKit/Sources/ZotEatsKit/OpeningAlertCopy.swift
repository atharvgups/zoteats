import Foundation

/// Notification copy for Opening Alerts — dining uses the meal's close time
/// ("Open until 8:00 PM") so Dinner openings don't imply all-day continuous hours.
public enum OpeningAlertCopy {
    /// Dining meal-scoped body when `openUntilMinutes` is known; campus can pass
    /// a continuous `hoursSpan` like "7:30 AM – 4:00 PM".
    public static func body(
        openUntilMinutes: Int? = nil,
        hoursSpan: String? = nil
    ) -> String {
        if let end = openUntilMinutes {
            return "Open until \(UCITime.format(minutes: end % (24 * 60))). Head over when you're ready."
        }
        let span = hoursSpan?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        if !span.isEmpty {
            return "Open \(span). Head over when you're ready."
        }
        return "Doors are open — head over when you're ready."
    }
}

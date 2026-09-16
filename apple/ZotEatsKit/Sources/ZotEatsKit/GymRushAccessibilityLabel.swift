import Foundation

/// VoiceOver for Gym "Today at the ARC" — typical estimate, peak, live now
/// (only when open), and busiest/quietest summaries Sighted users already see.
public enum GymRushAccessibilityLabel {
    public static func label(
        curve: [Int],
        currentHour: Int?,
        busiestSummary: String?,
        quietestSummary: String?
    ) -> String {
        var parts: [String] = ["Today at the ARC", "typical estimate"]

        if let peak = peakHour(in: curve) {
            parts.append("Peak around \(formatHour(peak))")
            if let currentHour {
                parts.append("Now around \(formatHour(currentHour))")
            }
        } else {
            parts.append("No rush data for today")
        }

        if let busiest = trimmed(busiestSummary) {
            parts.append(busiest)
        }
        if let quietest = trimmed(quietestSummary) {
            parts.append(quietest)
        }

        return parts.joined(separator: ", ")
    }

    private static func peakHour(in curve: [Int]) -> Int? {
        guard let peak = curve.enumerated().max(by: { $0.element < $1.element }),
              peak.element > 0
        else { return nil }
        return peak.offset
    }

    /// Matches RushStrip's compact tick style: "6 PM", "12 AM".
    private static func formatHour(_ hour: Int) -> String {
        let wrapped = ((hour % 24) + 24) % 24
        let display = wrapped % 12 == 0 ? 12 : wrapped % 12
        let period = wrapped < 12 ? "AM" : "PM"
        return "\(display) \(period)"
    }

    private static func trimmed(_ value: String?) -> String? {
        guard let value else { return nil }
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }
}

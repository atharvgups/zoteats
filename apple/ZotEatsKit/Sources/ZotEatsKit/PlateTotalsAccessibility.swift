import Foundation

/// VoiceOver for My Plate totals — empty plate keeps visual zeros but must not
/// announce "Calories: 0" / "Protein: 0g" before the empty-state message.
public enum PlateTotalsAccessibility {
    public static func shouldAnnounceTotals(isEmpty: Bool) -> Bool {
        !isEmpty
    }

    public static func label(name: String, value: String) -> String {
        let title = name.trimmingCharacters(in: .whitespacesAndNewlines)
        let amount = value.trimmingCharacters(in: .whitespacesAndNewlines)
        let heading = title.isEmpty ? "Total" : title
        guard !amount.isEmpty else { return heading }
        return "\(heading): \(amount)"
    }
}

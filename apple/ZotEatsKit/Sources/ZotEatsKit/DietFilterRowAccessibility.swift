import Foundation

/// VoiceOver for DietFilterSheet rows — subtitle meaning + toggle hint;
/// selection state is the `.isSelected` trait (not ", active" in the label).
public enum DietFilterRowAccessibility {
    public static func label(title: String, subtitle: String) -> String {
        let name = title.trimmingCharacters(in: .whitespacesAndNewlines)
        let detail = subtitle.trimmingCharacters(in: .whitespacesAndNewlines)
        var parts: [String] = []
        if !name.isEmpty {
            parts.append("\(name) filter")
        } else {
            parts.append("Filter")
        }
        if !detail.isEmpty {
            parts.append(detail)
        }
        return parts.joined(separator: ", ")
    }

    public static func hint(isSelected: Bool) -> String {
        isSelected ? "Turns this filter off" : "Turns this filter on"
    }
}

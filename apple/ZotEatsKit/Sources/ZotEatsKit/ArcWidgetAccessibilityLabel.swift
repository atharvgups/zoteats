import Foundation

/// VoiceOver for the ARC Gym widget — closed must say closed *and* the
/// next-open hoursLine (circular used to drop hours; rectangular/small dropped closed).
public enum ArcWidgetAccessibilityLabel {
    public static func label(
        isOpen: Bool,
        hoursLine: String,
        percent: Int?,
        isTypical: Bool
    ) -> String {
        let hours = hoursLine.trimmingCharacters(in: .whitespacesAndNewlines)
        var parts: [String] = ["ARC"]

        if isOpen {
            parts.append("open")
        } else if !hours.lowercased().hasPrefix("closed") {
            // "Opens at …" / "Opens tomorrow …" need an explicit closed status.
            parts.append("closed")
        }

        if let percent {
            let source = isTypical ? "typical estimate" : "live"
            parts.append("\(percent) percent full, \(source)")
        }

        if !hours.isEmpty {
            parts.append(hours)
        }

        return parts.joined(separator: ", ")
    }
}

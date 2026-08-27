import Foundation

/// VoiceOver for Eat hall picker cards — announce the same status line
/// (closes in / opens at / tomorrow) and occupancy sighted users use to choose.
public enum DiningHallCardAccessibilityLabel {
    public static func label(
        name: String,
        isOpen: Bool,
        statusLine: String?,
        occupancyPercent: Int? = nil
    ) -> String {
        var parts: [String] = [name, isOpen ? "open" : "closed"]
        if let status = statusLine?.trimmingCharacters(in: .whitespacesAndNewlines),
           !status.isEmpty {
            parts.append(status)
        }
        if let occupancyPercent {
            parts.append("\(occupancyPercent) percent occupancy")
        }
        return parts.joined(separator: ", ")
    }
}

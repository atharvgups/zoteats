import Foundation

/// VoiceOver for Study floor zone rows — percent plus the level label sighted
/// users get from bar color (Busy / Not busy / Very busy).
public enum StudyZoneAccessibilityLabel {
    public static func label(
        fullName: String,
        percent: Int?,
        levelLabel: String?
    ) -> String {
        let name = fullName.trimmingCharacters(in: .whitespacesAndNewlines)
        let heading = name.isEmpty ? "Zone" : name

        guard let percent else {
            return "\(heading), no occupancy data"
        }

        var parts: [String] = [heading, "\(percent) percent full"]
        if let level = levelLabel?.trimmingCharacters(in: .whitespacesAndNewlines),
           !level.isEmpty,
           level.lowercased() != "no data" {
            parts.append(level)
        }
        return parts.joined(separator: ", ")
    }
}

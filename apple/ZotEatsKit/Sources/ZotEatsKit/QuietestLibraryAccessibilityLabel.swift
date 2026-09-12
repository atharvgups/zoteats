import Foundation

/// VoiceOver for the Quietest Library widget — closed circular used to drop
/// `closedDetail` that rectangular/home already announce. Open paths can
/// append Updated freshness (Study facility / ARC widget parity).
public enum QuietestLibraryAccessibilityLabel {
    public static func label(
        name: String,
        percent: Int?,
        includeQuietestQualifier: Bool = false,
        updatedRelative: String? = nil,
        reopenMinutes: Int? = nil,
        nowMinutes: Int = UCITime.nowMinutes()
    ) -> String {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let percent else {
            let title = trimmed.isEmpty ? QuietestLibraryGlance.closedTitle : trimmed
            let detail = StudyIdleCopy.quietestClosedDetail(
                reopenMinutes: reopenMinutes,
                nowMinutes: nowMinutes
            )
            return "\(title). \(detail)"
        }
        var parts: [String] = [
            trimmed.isEmpty ? "Library" : trimmed,
            "\(percent) percent full",
        ]
        if includeQuietestQualifier {
            parts.append("quietest library right now")
        }
        if let updated = updatedRelative?.trimmingCharacters(in: .whitespacesAndNewlines),
           !updated.isEmpty {
            parts.append("Updated \(updated)")
        }
        return parts.joined(separator: ", ")
    }
}

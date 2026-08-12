import Foundation

/// VoiceOver for the Quietest Library widget — closed circular used to drop
/// `closedDetail` that rectangular/home already announce.
public enum QuietestLibraryAccessibilityLabel {
    public static func label(
        name: String,
        percent: Int?,
        includeQuietestQualifier: Bool = false
    ) -> String {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let percent else {
            let title = trimmed.isEmpty ? QuietestLibraryGlance.closedTitle : trimmed
            return "\(title). \(QuietestLibraryGlance.closedDetail)"
        }
        var parts: [String] = [
            trimmed.isEmpty ? "Library" : trimmed,
            "\(percent) percent full",
        ]
        if includeQuietestQualifier {
            parts.append("quietest library right now")
        }
        return parts.joined(separator: ", ")
    }
}

import Foundation

/// VoiceOver for Campus Open — empty overnight must announce next-open,
/// not only "0 campus spots open".
public enum CampusOpenAccessibilityLabel {
    public static let emptyHeadline = "Nothing's open right now."

    public static func label(
        totalOpen: Int,
        openPlaceNames: [String],
        nextOpenLine: String?
    ) -> String {
        if totalOpen <= 0 || openPlaceNames.isEmpty {
            if let nextOpenLine, !nextOpenLine.isEmpty {
                return "\(emptyHeadline) \(nextOpenLine)"
            }
            return emptyHeadline
        }

        let listed = Array(openPlaceNames.prefix(3))
        var parts = ["\(totalOpen) campus \(totalOpen == 1 ? "spot" : "spots") open"]
        if !listed.isEmpty {
            parts.append(listed.joined(separator: ", "))
        }
        let more = totalOpen - listed.count
        if more > 0 {
            parts.append("and \(more) more")
        }
        return parts.joined(separator: ". ")
    }
}

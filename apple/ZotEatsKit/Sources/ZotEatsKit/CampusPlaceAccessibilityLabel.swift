import Foundation

/// VoiceOver for Campus place rows — nested brand locations must announce
/// the same next-open / until-close hoursLine sighted users see.
public enum CampusPlaceAccessibilityLabel {
    /// Flat list row (full place name).
    public static func place(
        name: String,
        openNow: Bool,
        hoursLine: String,
        hasMenu: Bool
    ) -> String {
        assemble(
            subject: name,
            openNow: openNow,
            hoursLine: hoursLine,
            hasMenu: hasMenu
        )
    }

    /// Nested location under an expanded brand group.
    public static func nested(
        brand: String,
        locationDetail: String?,
        openNow: Bool,
        hoursLine: String
    ) -> String {
        let whereAt = locationDetail?.trimmingCharacters(in: .whitespacesAndNewlines)
        let subject: String
        if let whereAt, !whereAt.isEmpty {
            subject = "\(brand) at \(whereAt)"
        } else {
            subject = brand
        }
        return assemble(
            subject: subject,
            openNow: openNow,
            hoursLine: hoursLine,
            hasMenu: false
        )
    }

    private static func assemble(
        subject: String,
        openNow: Bool,
        hoursLine: String,
        hasMenu: Bool
    ) -> String {
        var parts = [subject, openNow ? "open" : "closed"]
        let hours = hoursLine.trimmingCharacters(in: .whitespacesAndNewlines)
        if !hours.isEmpty {
            parts.append(hours)
        }
        if hasMenu {
            parts.append("menu available")
        }
        return parts.joined(separator: ", ")
    }
}

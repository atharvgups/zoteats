import Foundation

/// Compact hours line for a Langson / Gateway card.
/// The quietest pill stays the campus summary; each card carries that library’s clock.
public enum StudyLibraryCardHours: Sendable {
    /// Open: today’s LibCal span, else Waitz “Open until …”.
    /// Closed: “Opens at …” / “Opens tomorrow at …” when known.
    /// `nil` when the line would only repeat Closed (the status pill already says that).
    public static func line(
        isOpen: Bool,
        hoursSummary: String?,
        libraryHours: LibraryBuildingHours?,
        nowMinutes: Int = UCITime.nowMinutes()
    ) -> String? {
        if isOpen {
            if let span = todaySpan(libraryHours) {
                return span
            }
            return StudyIdleCopy.facilityOpenDetail(
                hoursSummary: hoursSummary,
                libraryHours: libraryHours
            )
        }

        let closed = StudyIdleCopy.facilityClosedDetail(
            hoursSummary: hoursSummary,
            nowMinutes: nowMinutes,
            libraryHours: libraryHours
        )
        if isRedundantClosedCopy(closed) {
            return todaySpan(libraryHours)
        }
        return closed
    }

    private static func todaySpan(_ hours: LibraryBuildingHours?) -> String? {
        guard let hours else { return nil }
        let rendered = hours.rendered.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !rendered.isEmpty else { return nil }
        if rendered.compare("Closed", options: .caseInsensitive) == .orderedSame { return nil }
        if rendered.compare("Open", options: .caseInsensitive) == .orderedSame { return nil }
        return rendered
    }

    private static func isRedundantClosedCopy(_ text: String) -> Bool {
        if text == StudyFacilityCrowding.closedDetail { return true }
        return text.compare("Closed", options: .caseInsensitive) == .orderedSame
    }
}

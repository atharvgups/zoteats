import Foundation

/// Study + Quietest widget empty/closed parity when every library is shut.
public enum QuietestLibraryGlance {
    public static let closedTitle = "Libraries closed"
    public static let closedDetail = "No open library floors reporting right now."

    /// Lock Screen rectangular secondary line — busy % or overnight closed copy.
    /// Never "No live data" for the closed path (that reads like a fetch failure).
    /// Prefer Waitz `Closed until …` Opens-at when reload already knows the reopen.
    public static func widgetRectangularDetail(
        percent: Int?,
        reopenMinutes: Int? = nil
    ) -> String {
        if let percent {
            return "\(percent)% full · quietest now"
        }
        return StudyIdleCopy.quietestClosedDetail(reopenMinutes: reopenMinutes)
    }

    /// Home small secondary line when there is no quietest % (libraries closed).
    public static func widgetHomeSecondary(
        percent: Int?,
        reopenMinutes: Int? = nil
    ) -> String? {
        percent == nil
            ? StudyIdleCopy.quietestClosedDetail(reopenMinutes: reopenMinutes)
            : nil
    }

    /// Dining Status medium tip — open quietest floor or overnight closed copy.
    public enum DiningStatusTip: Equatable, Sendable {
        case open(name: String, percent: Int, facilityID: Int?, updatedAt: Date)
        case librariesClosed(reopenMinutes: Int?)
    }

    /// Feed includes at least one Library facility (open or closed).
    public static func hasLibraryFacilities(_ facilities: [BusynessPoint]) -> Bool {
        facilities.contains { $0.category == "Library" }
    }

    /// Show the closed hero when libraries exist but none are open/reporting.
    public static func shouldShowClosed(from facilities: [BusynessPoint]) -> Bool {
        QuietestLibraryPick.best(from: facilities) == nil
            && hasLibraryFacilities(facilities)
    }

    /// Tip for the Dining Halls medium footer. Nil when the feed has no libraries.
    public static func diningStatusTip(from facilities: [BusynessPoint]) -> DiningStatusTip? {
        if let pick = QuietestLibraryPick.best(from: facilities) {
            return .open(
                name: pick.title,
                percent: pick.percent,
                facilityID: pick.facilityID,
                updatedAt: pick.updatedAt
            )
        }
        guard shouldShowClosed(from: facilities) else { return nil }
        return .librariesClosed(
            reopenMinutes: StudyIdleCopy.soonestReopenMinutes(from: facilities)
        )
    }
}

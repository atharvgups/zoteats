import Foundation

/// Study / Quietest closed chrome from Waitz `Closed until …` — reload already
/// parses reopen minutes (`QuietestLibraryReload`); this surfaces “Opens at …”
/// so overnight cards and widgets match Gym honesty.
public enum StudyIdleCopy {
    /// Soonest library-pool reopen from Waitz (sorted ascending).
    public static func soonestReopenMinutes(from facilities: [BusynessPoint]) -> Int? {
        QuietestLibraryReload.reopenMinutes(from: facilities).first
    }

    public static func opensAtLine(minutes: Int) -> String {
        "Opens at \(UCITime.format(minutes: minutes))"
    }

    /// Quietest / Dining Status closed secondary — Opens-at when known.
    public static func quietestClosedDetail(reopenMinutes: Int?) -> String {
        guard let minutes = reopenMinutes else {
            return QuietestLibraryGlance.closedDetail
        }
        return opensAtLine(minutes: minutes)
    }

    /// Per-facility closed secondary from Waitz `hoursSummary`.
    public static func facilityClosedDetail(hoursSummary: String?) -> String {
        if let minutes = WaitzHoursSummary.closedUntilMinutes(hoursSummary) {
            return opensAtLine(minutes: minutes)
        }
        return StudyFacilityCrowding.closedDetail
    }
}

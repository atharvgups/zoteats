import Foundation

/// Study / Quietest hours chrome from Waitz — Closed-until → “Opens at …”,
/// parseable open ranges → “Open until …”. Reload already parses reopen/
/// close minutes; this keeps cards and widgets honest.
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

    /// Per-facility open secondary — nil when Waitz only says `"open"`.
    public static func facilityOpenDetail(hoursSummary: String?) -> String? {
        WaitzHoursSummary.openUntilLine(hoursSummary)
    }
}

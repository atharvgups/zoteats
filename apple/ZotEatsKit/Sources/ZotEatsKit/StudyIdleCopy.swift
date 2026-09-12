import Foundation

/// Study / Quietest hours chrome from Waitz — Closed-until → “Opens at …” /
/// “Opens tomorrow at …” when that clock is past; parseable open ranges →
/// “Open until …”.
public enum StudyIdleCopy {
    /// Soonest library-pool reopen from Waitz (sorted ascending).
    public static func soonestReopenMinutes(from facilities: [BusynessPoint]) -> Int? {
        QuietestLibraryReload.reopenMinutes(from: facilities).first
    }

    public static func opensAtLine(minutes: Int) -> String {
        "Opens at \(UCITime.format(minutes: minutes))"
    }

    public static func opensTomorrowLine(minutes: Int) -> String {
        "Opens tomorrow at \(UCITime.format(minutes: minutes))"
    }

    /// Quietest / Dining Status closed secondary — Opens-at when known and
    /// still ahead; Opens-tomorrow when Waitz Closed-until is already past.
    public static func quietestClosedDetail(
        reopenMinutes: Int?,
        nowMinutes: Int = UCITime.nowMinutes()
    ) -> String {
        guard let minutes = reopenMinutes else {
            return QuietestLibraryGlance.closedDetail
        }
        if nowMinutes < minutes {
            return opensAtLine(minutes: minutes)
        }
        return opensTomorrowLine(minutes: minutes)
    }

    /// Per-facility closed secondary from Waitz `hoursSummary`, with optional
    /// LibCal building hours when Waitz has no Closed-until clock.
    public static func facilityClosedDetail(
        hoursSummary: String?,
        nowMinutes: Int = UCITime.nowMinutes(),
        libraryHours: LibraryBuildingHours? = nil
    ) -> String {
        if let minutes = WaitzHoursSummary.closedUntilMinutes(hoursSummary) {
            if nowMinutes < minutes {
                return opensAtLine(minutes: minutes)
            }
            return opensTomorrowLine(minutes: minutes)
        }
        if let libraryHours {
            if let open = libraryHours.openMinutes {
                if nowMinutes < open {
                    return opensAtLine(minutes: open)
                }
                return opensTomorrowLine(minutes: open)
            }
            if libraryHours.rendered != "Closed" {
                return libraryHours.rendered
            }
        }
        return StudyFacilityCrowding.closedDetail
    }

    /// Per-facility open secondary — Waitz range first, else LibCal today span.
    public static func facilityOpenDetail(
        hoursSummary: String?,
        libraryHours: LibraryBuildingHours? = nil
    ) -> String? {
        if let line = WaitzHoursSummary.openUntilLine(hoursSummary) {
            return line
        }
        if let libraryHours, libraryHours.rendered != "Closed", !libraryHours.rendered.isEmpty {
            if let close = libraryHours.closeMinutes {
                return "Open until \(UCITime.format(minutes: close))"
            }
            return libraryHours.rendered
        }
        return nil
    }
}

import Foundation

/// Which Study facility card should expand floors — only for deep links, never
/// quietest auto-expand (Atharv: opening Study must show libraries collapsed).
public enum StudyFacilityExpand {
    /// Prefer an applied or still-pending deep-link facility. Quietest is ignored
    /// so Langson / Science stay collapsed until the student taps.
    public static func targetID(
        pendingFacilityID: Int?,
        deepLinkFacilityID: Int?,
        quietestFacilityID: Int?
    ) -> Int? {
        _ = quietestFacilityID
        return pendingFacilityID ?? deepLinkFacilityID
    }

    /// Facility id on a Study deep link before `applyPending` clears it.
    public static func pendingFacilityID(from link: AnteatsDeepLink?) -> Int? {
        guard let link, link.tab == .study else { return nil }
        return link.facilityID
    }

    /// Pin after applying a Study deep link. `nil` facility (Libraries closed /
    /// bare `anteats://study`) clears any prior pin so Study doesn't keep
    /// scrolling to a stale closed library.
    public static func pinAfterApplying(linkFacilityID: Int?) -> Int? {
        linkFacilityID
    }

    /// Warm re-expand only when the link names a facility.
    public static func shouldExpandPulse(linkFacilityID: Int?) -> Bool {
        linkFacilityID != nil
    }
}

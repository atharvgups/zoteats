import Foundation

/// Which Study facility card should expand floors for a deep link / quietest tip.
public enum StudyFacilityExpand {
    /// Prefer an applied or still-pending deep-link facility over quietest auto-expand.
    public static func targetID(
        pendingFacilityID: Int?,
        deepLinkFacilityID: Int?,
        quietestFacilityID: Int?
    ) -> Int? {
        pendingFacilityID ?? deepLinkFacilityID ?? quietestFacilityID
    }

    /// Facility id on a Study deep link before `applyPending` clears it.
    public static func pendingFacilityID(from link: AnteatsDeepLink?) -> Int? {
        guard let link, link.tab == .study else { return nil }
        return link.facilityID
    }

    /// Pin after applying a Study deep link. `nil` facility (Libraries closed /
    /// bare `anteats://study`) clears any prior quietest pin so Study doesn't
    /// keep scrolling to a stale closed library.
    public static func pinAfterApplying(linkFacilityID: Int?) -> Int? {
        linkFacilityID
    }

    /// Warm re-expand only when the link names a facility.
    public static func shouldExpandPulse(linkFacilityID: Int?) -> Bool {
        linkFacilityID != nil
    }
}

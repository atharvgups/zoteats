import Foundation

/// Langson / Gateway (Waitz: Science Library).
/// Header tap always expands/collapses. Live floor % only while open —
/// closed libraries still toggle so collapsed-by-default isn't a no-op.
public enum StudyLibraryTap: Sendable {
    /// Live floor crowding only while open and Waitz has real sub-locations.
    public static func canRevealFloors(hasFloors: Bool, isOpen: Bool) -> Bool {
        hasFloors && StudyFacilityCrowding.showsLiveCrowding(isOpen: isOpen)
    }

    /// Header tap is never gated on open/closed. Atharv: tapping a library
    /// row must expand/collapse even when both buildings read Closed.
    public static func canToggleExpand() -> Bool { true }

    public static func floorsHint(floorCount: Int, isExpanded: Bool) -> String {
        if isExpanded { return "Hide floors" }
        if floorCount == 1 { return "1 floor" }
        if floorCount > 1 { return "\(floorCount) floors" }
        return "Floors"
    }

    /// Shown when the card expands but live floor % would be invented.
    public static func expandedEmptyDetail(isOpen: Bool) -> String {
        if !isOpen {
            return "Floor crowding updates when this library is open"
        }
        return "No floor breakdown right now"
    }
}

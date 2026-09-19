import Foundation

/// Langson / Gateway collapsed cards: comfortable to tap, not a thick slab
/// and not a single dense row. Today's hours live in the card — there is no
/// separate "Today's hours" strip.
public enum StudyLibraryCardLayout: Sendable {
    /// Inset inside each library card. 16pt read as chunky; 8pt reads compact.
    public static let contentPadding: CGFloat = 13
    /// Vertical rhythm between title, hours, crowding, and the floors hint.
    public static let stackSpacing: CGFloat = 7
    /// Gap between Langson and Gateway.
    public static let cardSpacing: CGFloat = 12
    public static let minTapHeight: CGFloat = 44
    /// Open crowding % — still readable, smaller than the old 28pt slab.
    public static let crowdingPercentSize: CGFloat = 24
    public static let occupancyBarHeight: CGFloat = 8
    public static let chevronSide: CGFloat = 22

    /// Giant % / dash row only while the building is open. Closed cards keep
    /// the status pill plus Opens-at / hours so they stay one comfortable block.
    public static func showsCrowdingChrome(isOpen: Bool) -> Bool {
        StudyFacilityCrowding.showsLiveCrowding(isOpen: isOpen)
    }
}

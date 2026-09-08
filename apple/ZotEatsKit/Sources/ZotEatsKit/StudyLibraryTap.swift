import Foundation

/// Langson / Gateway (Waitz: Science Library): tap reveals floors
/// only while open and the feed has real sub-locations. No invented %.
public enum StudyLibraryTap: Sendable {
    public static func canRevealFloors(hasFloors: Bool, isOpen: Bool) -> Bool {
        hasFloors && StudyFacilityCrowding.showsLiveCrowding(isOpen: isOpen)
    }
}

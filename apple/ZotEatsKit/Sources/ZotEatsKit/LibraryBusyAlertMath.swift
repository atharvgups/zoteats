import Foundation

/// High-signal library busyness — real Waitz % only, never a guessed occupancy.
public enum LibraryBusyAlertMath {
    /// Fire once a library building hits this live percent (and is open).
    public static let percentThreshold = 75

    /// Building-level libraries that just crossed the busy bar.
    public static func spikes(
        facilities: [BusynessPoint],
        alreadyNotifiedIDs: Set<Int>
    ) -> [BusynessPoint] {
        facilities.filter { point in
            guard point.category == "Library" else { return false }
            guard point.isOpen else { return false }
            guard point.source == .live else { return false }
            guard let percent = point.percent, percent >= percentThreshold else { return false }
            return !alreadyNotifiedIDs.contains(point.id)
        }
    }
}

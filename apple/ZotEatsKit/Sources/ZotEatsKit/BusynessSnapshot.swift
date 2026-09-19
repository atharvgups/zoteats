import Foundation

/// Occupancy / hours snapshot equality for Study reload skips.
/// Waitz normalizes stamp a fresh `updatedAt` every fetch — full `Equatable`
/// would always miss and churn the Study list. Compare live fields only.
public enum BusynessSnapshot {
    public static func equalsIgnoringFetchTime(_ lhs: BusynessPoint, _ rhs: BusynessPoint) -> Bool {
        lhs.id == rhs.id
            && lhs.name == rhs.name
            && lhs.category == rhs.category
            && lhs.count == rhs.count
            && lhs.capacity == rhs.capacity
            && lhs.percent == rhs.percent
            && lhs.level == rhs.level
            && lhs.isOpen == rhs.isOpen
            && lhs.hoursSummary == rhs.hoursSummary
            && lhs.source == rhs.source
            && equalsIgnoringFetchTime(lhs.subLocations, rhs.subLocations)
    }

    public static func equalsIgnoringFetchTime(
        _ lhs: [BusynessPoint]?,
        _ rhs: [BusynessPoint]?
    ) -> Bool {
        switch (lhs, rhs) {
        case (nil, nil):
            return true
        case (let l?, let r?):
            return equalsIgnoringFetchTime(l, r)
        default:
            return false
        }
    }

    public static func equalsIgnoringFetchTime(_ lhs: [BusynessPoint], _ rhs: [BusynessPoint]) -> Bool {
        guard lhs.count == rhs.count else { return false }
        for (a, b) in zip(lhs, rhs) {
            if !equalsIgnoringFetchTime(a, b) { return false }
        }
        return true
    }
}

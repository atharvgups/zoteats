import Foundation

/// Shared “quietest library spot” pick for Study, Quietest Library widget,
/// and the Dining Status tip — library-only and floor-aware so ARC gym
/// never wins “find a quiet library spot.”
public struct QuietestLibraryPick: Equatable, Sendable {
    public let title: String
    public let percent: Int
    /// Parent facility Waitz id when known (for expanding that card on Study).
    public let facilityID: Int?
    /// Waitz snapshot time for the winning facility/zone (Updated freshness).
    public let updatedAt: Date

    public init(title: String, percent: Int, facilityID: Int? = nil, updatedAt: Date = Date()) {
        self.title = title
        self.percent = percent
        self.facilityID = facilityID
        self.updatedAt = updatedAt
    }

    /// Quietest open library floor/zone. Prefers `category == "Library"`;
    /// falls back to all facilities only when no libraries are in the feed.
    /// Returns `nil` when nothing open reports a percent.
    /// Uses Waitz hour chrome (Closed-until / ranges), not raw `isOpen`.
    public static func best(
        from facilities: [BusynessPoint],
        nowMinutes: Int = UCITime.nowMinutes()
    ) -> QuietestLibraryPick? {
        let libraries = facilities.filter { $0.category == "Library" }
        let pool = libraries.isEmpty ? facilities : libraries

        var candidates: [QuietestLibraryPick] = []
        for facility in pool where facility.isEffectivelyOpen(nowMinutes: nowMinutes) {
            let short = shortLibraryName(facility.name)
            let floors = BusynessFloorGrouping.floors(from: facility.subLocations)
            let openByID = Dictionary(
                uniqueKeysWithValues: (facility.subLocations ?? []).map { ($0.id, $0.isOpen) }
            )
            let updatedByID = Dictionary(
                uniqueKeysWithValues: (facility.subLocations ?? []).map { ($0.id, $0.updatedAt) }
            )

            if !floors.isEmpty {
                for floor in floors {
                    for zone in floor.zones {
                        guard let percent = zone.percent else { continue }
                        guard openByID[zone.id] != false else { continue }
                        let title: String
                        if zone.displayName.caseInsensitiveCompare(floor.floorLabel) == .orderedSame {
                            title = "\(short) · \(floor.floorLabel)"
                        } else {
                            title = "\(short) · \(floor.floorLabel) · \(zone.displayName)"
                        }
                        candidates.append(
                            .init(
                                title: title,
                                percent: percent,
                                facilityID: facility.id,
                                updatedAt: updatedByID[zone.id] ?? facility.updatedAt
                            )
                        )
                    }
                }
            } else if let percent = facility.percent {
                candidates.append(
                    .init(
                        title: facility.name,
                        percent: percent,
                        facilityID: facility.id,
                        updatedAt: facility.updatedAt
                    )
                )
            }
        }

        if let best = candidates.min(by: { $0.percent < $1.percent }) {
            return best
        }

        // No floor zones reported — quietest open facility in the pool.
        return pool
            .filter { $0.isEffectivelyOpen(nowMinutes: nowMinutes) && $0.percent != nil }
            .min { ($0.percent ?? 101) < ($1.percent ?? 101) }
            .map {
                .init(
                    title: $0.name,
                    percent: $0.percent ?? 0,
                    facilityID: $0.id,
                    updatedAt: $0.updatedAt
                )
            }
    }

    /// "Langson Library" → "Langson"; "Science Library" → "Sci Lib".
    public static func shortLibraryName(_ name: String) -> String {
        name
            .replacingOccurrences(of: " Library", with: "")
            .replacingOccurrences(of: "Science", with: "Sci Lib")
    }
}

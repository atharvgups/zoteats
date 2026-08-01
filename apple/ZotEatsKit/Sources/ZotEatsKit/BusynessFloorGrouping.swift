import Foundation

// Presentation helper for Waitz library zones.
// Waitz lists sensor zones like "2nd Floor - Open Seating" and
// "2nd Floor - Grand Reading Room" as siblings — which reads as
// "two 2nd floors" in a flat list. Group by floor and strip the
// repeated prefix so the expand UI is scannable.

/// One named zone under a floor (or a floor that is itself a single zone).
public struct BusynessZoneRow: Identifiable, Equatable, Sendable {
    public let id: Int
    /// Short label under a floor header, e.g. "Open Seating".
    public let displayName: String
    /// Full Waitz name for accessibility, e.g. "2nd Floor - Open Seating".
    public let fullName: String
    public let percent: Int?
    public let level: BusynessLevel

    public init(id: Int, displayName: String, fullName: String, percent: Int?, level: BusynessLevel) {
        self.id = id
        self.displayName = displayName
        self.fullName = fullName
        self.percent = percent
        self.level = level
    }
}

/// A floor (or Basement) with one or more study zones underneath.
public struct BusynessFloorGroup: Identifiable, Equatable, Sendable {
    public var id: String { floorLabel }
    public let floorLabel: String
    public let sortIndex: Int
    public let zones: [BusynessZoneRow]

    public init(floorLabel: String, sortIndex: Int, zones: [BusynessZoneRow]) {
        self.floorLabel = floorLabel
        self.sortIndex = sortIndex
        self.zones = zones
    }
}

public enum BusynessFloorGrouping {
    /// Zones that don't help students pick a study spot (tiny entrance sensors).
    private static let ignoredExactNames: Set<String> = [
        "lobby",
        "entrance",
        "vestibule",
    ]

    /// Group Waitz sub-locations into floors for the Study expand UI.
    /// Drops Lobby/entrance noise, sorts Basement → 1st → 2nd → …, and
    /// shortens zone labels so the floor name isn't repeated on every row.
    public static func floors(from subLocations: [BusynessPoint]?) -> [BusynessFloorGroup] {
        guard let subLocations, !subLocations.isEmpty else { return [] }

        var buckets: [String: (sortIndex: Int, zones: [BusynessZoneRow])] = [:]

        for point in subLocations {
            let name = point.name.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !name.isEmpty else { continue }
            if ignoredExactNames.contains(name.lowercased()) { continue }

            let parsed = parse(name)
            let row = BusynessZoneRow(
                id: point.id,
                displayName: parsed.zoneLabel,
                fullName: name,
                percent: point.percent,
                level: point.level
            )
            var bucket = buckets[parsed.floorLabel] ?? (parsed.sortIndex, [])
            bucket.zones.append(row)
            buckets[parsed.floorLabel] = bucket
        }

        return buckets
            .map { floor, value in
                // Quietest zones first — that's what students are scanning for.
                let zones = value.zones.sorted { lhs, rhs in
                    switch (lhs.percent, rhs.percent) {
                    case (let l?, let r?): return l < r
                    case (.some, .none): return true
                    case (.none, .some): return false
                    case (.none, .none): return lhs.displayName < rhs.displayName
                    }
                }
                return BusynessFloorGroup(
                    floorLabel: floor,
                    sortIndex: value.sortIndex,
                    zones: zones
                )
            }
            .sorted { $0.sortIndex < $1.sortIndex }
    }

    /// Split "4th Floor - Open Seating" into floor + zone; leave "Basement" alone.
    static func parse(_ name: String) -> (floorLabel: String, zoneLabel: String, sortIndex: Int) {
        let parts = name.split(separator: "-", maxSplits: 1, omittingEmptySubsequences: false)
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }

        if parts.count == 2, looksLikeFloor(parts[0]) {
            return (parts[0], parts[1], sortIndex(for: parts[0]))
        }

        // Single token like "1st Floor" or "Basement" — the row IS the floor.
        return (name, name, sortIndex(for: name))
    }

    private static func looksLikeFloor(_ label: String) -> Bool {
        let lowered = label.lowercased()
        if lowered == "basement" || lowered == "mezzanine" { return true }
        return lowered.range(of: #"^\d+(st|nd|rd|th)\s+floor$"#, options: .regularExpression) != nil
    }

    /// Basement first, then numeric floors ascending, then anything else.
    static func sortIndex(for floorLabel: String) -> Int {
        let lowered = floorLabel.lowercased()
        if lowered == "basement" { return 0 }
        if let match = lowered.range(of: #"^(\d+)"#, options: .regularExpression) {
            let digits = Int(lowered[match]) ?? 99
            return digits
        }
        if lowered.contains("mezzanine") { return 35 }
        return 90
    }
}

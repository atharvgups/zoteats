import Foundation

/// Dedicated “what opens next?” campus glance — same hint as Open Now empty.
public enum NextCampusOpenPick {
    public struct Glance: Equatable, Sendable {
        public let openCount: Int
        public let nextOpen: CampusNextOpenHint.Hint?
        /// First hearted open place id/name when something is open.
        public let favoriteOpenID: String?
        public let favoriteOpenName: String?

        public init(
            openCount: Int,
            nextOpen: CampusNextOpenHint.Hint?,
            favoriteOpenID: String? = nil,
            favoriteOpenName: String? = nil
        ) {
            self.openCount = openCount
            self.nextOpen = nextOpen
            self.favoriteOpenID = favoriteOpenID
            self.favoriteOpenName = favoriteOpenName
        }
    }

    public static func glance(
        places: [CampusPlace],
        favoriteIDs: Set<String>
    ) -> Glance {
        let open = CampusPlaceSort.sortOpenForWidget(
            places: places,
            favoriteIDs: favoriteIDs
        )
        let favOpen = open.first { favoriteIDs.contains($0.id) }
        return Glance(
            openCount: open.count,
            nextOpen: open.isEmpty ? CampusNextOpenHint.best(from: places) : nil,
            favoriteOpenID: favOpen?.id,
            favoriteOpenName: favOpen?.name
        )
    }

    public static func headline(for glance: Glance) -> String {
        if glance.openCount > 0 {
            if glance.openCount == 1 { return "1 spot open" }
            return "\(glance.openCount) spots open"
        }
        return "Nothing open"
    }

    public static func detail(for glance: Glance) -> String {
        if glance.openCount > 0 {
            if let name = glance.favoriteOpenName, !name.isEmpty {
                return name
            }
            return "Tap for Campus"
        }
        return glance.nextOpen?.line ?? "Check back later"
    }
}

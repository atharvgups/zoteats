import Foundation

/// Campus list IA: Favorites shelf + deduped main list, with Twisted Root first
/// among remaining (non-favorited) rows.
///
/// Atharv (owner): keep Favorites distinct; never show the same place as both a
/// Favorites card and a full main-list card (that felt doubled when Twisted Root
/// was favorited AND sorted first). Twisted Root still leads the main list when
/// Favorites is empty — intentional vegan preference.
public enum CampusPlaceSort {
    /// Match brand/name — Twisted Root is the plant-based dining station; if a
    /// Campus retail row ever uses the same name, prefer it the same way.
    public static func isTwistedRootPreferred(_ place: CampusPlace) -> Bool {
        let haystack = "\(place.brand) \(place.name)".lowercased()
        return haystack.contains("twisted root") || haystack.contains("twistedroot")
    }

    /// Favorites first (open → name), then main list with favorites removed and
    /// Twisted Root floated first among the rest.
    public static func partition(
        places: [CampusPlace],
        favoriteIDs: Set<String>
    ) -> (favorites: [CampusPlace], main: [CampusPlace]) {
        let favorites = sortFavorites(places.filter { favoriteIDs.contains($0.id) })
        let main = sortMain(places.filter { !favoriteIDs.contains($0.id) })
        return (favorites, main)
    }

    public static func sortFavorites(_ places: [CampusPlace]) -> [CampusPlace] {
        places.sorted { lhs, rhs in
            let lhsOpen = lhs.isOpen()
            let rhsOpen = rhs.isOpen()
            if lhsOpen != rhsOpen { return lhsOpen }
            return lhs.name.localizedCaseInsensitiveCompare(rhs.name) == .orderedAscending
        }
    }

    /// Campus Open widget glance: open spots only, hearted first, then name.
    public static func sortOpenForWidget(
        places: [CampusPlace],
        favoriteIDs: Set<String>,
        nowMinutes: Int = UCITime.nowMinutes()
    ) -> [CampusPlace] {
        places
            .filter { $0.isOpen(nowMinutes: nowMinutes) }
            .sorted { lhs, rhs in
                let lhsFav = favoriteIDs.contains(lhs.id)
                let rhsFav = favoriteIDs.contains(rhs.id)
                if lhsFav != rhsFav { return lhsFav }
                return lhs.name.localizedCaseInsensitiveCompare(rhs.name) == .orderedAscending
            }
    }

    /// Non-favorited Campus rows — Twisted Root first, then open, then name.
    public static func sortMain(_ places: [CampusPlace]) -> [CampusPlace] {
        places.sorted { lhs, rhs in
            let lhsRoot = isTwistedRootPreferred(lhs)
            let rhsRoot = isTwistedRootPreferred(rhs)
            if lhsRoot != rhsRoot { return lhsRoot }
            let lhsOpen = lhs.isOpen()
            let rhsOpen = rhs.isOpen()
            if lhsOpen != rhsOpen { return lhsOpen }
            return lhs.name.localizedCaseInsensitiveCompare(rhs.name) == .orderedAscending
        }
    }

    /// Brand-group the main list after Twisted Root / open sorting. Favorite IDs
    /// must already be excluded so a favorited Starbucks location isn't doubled.
    public static func brandGroups(
        from places: [CampusPlace]
    ) -> [(brand: String, places: [CampusPlace])] {
        var order: [String] = []
        var byBrand: [String: [CampusPlace]] = [:]
        for place in places {
            if byBrand[place.brand] == nil { order.append(place.brand) }
            byBrand[place.brand, default: []].append(place)
        }
        return order.map { brand in
            let sorted = byBrand[brand]!.sorted { lhs, rhs in
                let lhsRoot = isTwistedRootPreferred(lhs)
                let rhsRoot = isTwistedRootPreferred(rhs)
                if lhsRoot != rhsRoot { return lhsRoot }
                let lhsOpen = lhs.isOpen()
                let rhsOpen = rhs.isOpen()
                if lhsOpen != rhsOpen { return lhsOpen }
                return lhs.name.localizedCaseInsensitiveCompare(rhs.name) == .orderedAscending
            }
            return (brand: brand, places: sorted)
        }
        .sorted { lhs, rhs in
            let lhsRoot = lhs.places.contains(where: isTwistedRootPreferred)
            let rhsRoot = rhs.places.contains(where: isTwistedRootPreferred)
            if lhsRoot != rhsRoot { return lhsRoot }
            let lhsOpen = lhs.places.contains { $0.isOpen() }
            let rhsOpen = rhs.places.contains { $0.isOpen() }
            if lhsOpen != rhsOpen { return lhsOpen }
            return lhs.brand.localizedCaseInsensitiveCompare(rhs.brand) == .orderedAscending
        }
    }
}

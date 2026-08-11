import Foundation

/// App Group bridge so the main app and widget extension share favorites
/// and Eat Filters. Falls back to `.standard` when the suite isn't available
/// (simulator without entitlements, unit tests).
public enum SharedDefaults {
    public static let appGroupID = "group.com.atharvgupta.zoteats"
    public static let favoritesKey = "zoteats.favoriteDishNames"
    public static let dietFiltersKey = "zoteats.dietFilters"
    public static let allergenAvoidsKey = "zoteats.allergenAvoids"

    public static var suite: UserDefaults {
        UserDefaults(suiteName: appGroupID) ?? .standard
    }

    public static func favoriteDishNames() -> [String] {
        suite.stringArray(forKey: favoritesKey)
            ?? UserDefaults.standard.stringArray(forKey: favoritesKey)
            ?? []
    }

    public static func setFavoriteDishNames(_ names: [String]) {
        suite.set(names, forKey: favoritesKey)
        // Keep standard in sync for older code paths / migration.
        UserDefaults.standard.set(names, forKey: favoritesKey)
    }

    public static func dietFilters() -> [String] {
        suite.stringArray(forKey: dietFiltersKey)
            ?? UserDefaults.standard.stringArray(forKey: dietFiltersKey)
            ?? []
    }

    public static func setDietFilters(_ tags: [String]) {
        suite.set(tags, forKey: dietFiltersKey)
        UserDefaults.standard.set(tags, forKey: dietFiltersKey)
    }

    public static func allergenAvoids() -> [String] {
        suite.stringArray(forKey: allergenAvoidsKey)
            ?? UserDefaults.standard.stringArray(forKey: allergenAvoidsKey)
            ?? []
    }

    public static func setAllergenAvoids(_ tags: [String]) {
        suite.set(tags, forKey: allergenAvoidsKey)
        UserDefaults.standard.set(tags, forKey: allergenAvoidsKey)
    }

    /// Put hearted dishes first (case-insensitive), then the rest of the menu
    /// in original order. Used by the Today's Menu widget.
    public static func prioritizeFavorites(
        dishes: [String],
        favorites: [String]
    ) -> (ordered: [String], favorited: Set<String>) {
        guard !favorites.isEmpty else {
            return (dishes, [])
        }
        let favoriteKeys = Set(favorites.map { $0.lowercased() })
        var matched: [String] = []
        var rest: [String] = []
        var favorited: Set<String> = []
        for dish in dishes {
            if favoriteKeys.contains(dish.lowercased()) {
                matched.append(dish)
                favorited.insert(dish)
            } else {
                rest.append(dish)
            }
        }
        return (matched + rest, favorited)
    }

    /// Apply Eat Filters, dedupe dish names, then float favorites — same pipeline
    /// the Today's Menu widget uses so Home Screen matches in-app Eat.
    public static func todaysMenuDishes(
        stations: [MenuStation],
        dietFilters: Set<String>,
        allergenAvoids: Set<String>,
        favorites: [String]
    ) -> (ordered: [String], favorited: Set<String>, filtersEmptiedMenu: Bool) {
        let hadItems = stations.contains { !$0.items.isEmpty }
        let filtered = MenuFilterMatching.filterStations(
            stations,
            dietFilters: dietFilters,
            allergenAvoids: allergenAvoids
        )
        var seen = Set<String>()
        let names = filtered
            .flatMap(\.items)
            .map(\.name)
            .filter { seen.insert($0.lowercased()).inserted }
        let prioritized = prioritizeFavorites(dishes: names, favorites: favorites)
        let filtersActive = !dietFilters.isEmpty || !allergenAvoids.isEmpty
        let filtersEmptiedMenu = filtersActive && hadItems && names.isEmpty
        return (prioritized.ordered, prioritized.favorited, filtersEmptiedMenu)
    }
}

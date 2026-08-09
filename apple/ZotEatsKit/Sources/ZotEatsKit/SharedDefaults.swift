import Foundation

/// App Group bridge so the main app and widget extension share favorites
/// (and later other glanceable prefs). Falls back to `.standard` when the
/// suite isn't available (simulator without entitlements, unit tests).
public enum SharedDefaults {
    public static let appGroupID = "group.com.atharvgupta.zoteats"
    public static let favoritesKey = "zoteats.favoriteDishNames"

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
}

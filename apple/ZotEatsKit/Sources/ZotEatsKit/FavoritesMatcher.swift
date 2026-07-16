import Foundation

/// Pure matching logic behind favorite-dish alerts: given the user's favorite
/// dish names and today's menus, which favorites are actually being served?
public enum FavoritesMatcher {
    public struct Match: Equatable, Sendable {
        public let dishName: String
        public let hallName: String
        public let period: String

        public init(dishName: String, hallName: String, period: String) {
            self.dishName = dishName
            self.hallName = hallName
            self.period = period
        }

        /// Stable dedupe key so a dish only triggers one alert per day.
        public func dedupeKey(dateISO: String) -> String {
            "\(dateISO)|\(dishName.lowercased())"
        }
    }

    /// Case-insensitive name matching (favorites are stored by name because
    /// dish ids rotate daily). One match per dish name — first hall/period wins.
    public static func matches(
        favorites: Set<String>,
        menus: [DiningMenu],
        hallNames: [String: String]
    ) -> [Match] {
        guard !favorites.isEmpty else { return [] }
        let wanted = Set(favorites.map { $0.lowercased() })

        var found: [String: Match] = [:]
        for menu in menus {
            for station in menu.stations {
                for item in station.items {
                    let key = item.name.lowercased()
                    guard wanted.contains(key), found[key] == nil else { continue }
                    found[key] = Match(
                        dishName: item.name,
                        hallName: hallNames[menu.locationId] ?? HallDirectory.displayName(for: menu.locationId),
                        period: menu.period
                    )
                }
            }
        }
        return found.values.sorted { $0.dishName < $1.dishName }
    }
}

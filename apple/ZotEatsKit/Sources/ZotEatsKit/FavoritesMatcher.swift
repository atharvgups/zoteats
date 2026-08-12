import Foundation

/// Pure matching logic behind favorite-dish alerts: given the user's favorite
/// dish names and today's menus, which favorites are actually being served?
public enum FavoritesMatcher {
    public struct Match: Equatable, Sendable {
        public let dishName: String
        public let hallName: String
        /// Anteater API location id for deep links (`anteatery`, …).
        public let locationId: String
        public let period: String

        public init(dishName: String, hallName: String, locationId: String, period: String) {
            self.dishName = dishName
            self.hallName = hallName
            self.locationId = locationId
            self.period = period
        }

        /// Stable dedupe key so a dish only triggers one alert per day.
        public func dedupeKey(dateISO: String) -> String {
            "\(dateISO)|\(dishName.lowercased())"
        }
    }

    /// Case-insensitive name matching (favorites are stored by name because
    /// dish ids rotate daily). One match per dish name — currently-serving
    /// halls/periods beat upcoming ones; otherwise first hit wins.
    public static func matches(
        favorites: Set<String>,
        menus: [DiningMenu],
        hallNames: [String: String],
        isServing: ((String, String) -> Bool)? = nil
    ) -> [Match] {
        guard !favorites.isEmpty else { return [] }
        let wanted = Set(favorites.map { $0.lowercased() })

        var found: [String: Match] = [:]
        for menu in menus {
            for station in menu.stations {
                for item in station.items {
                    let key = item.name.lowercased()
                    guard wanted.contains(key) else { continue }
                    let candidate = Match(
                        dishName: item.name,
                        hallName: hallNames[menu.locationId] ?? HallDirectory.displayName(for: menu.locationId),
                        locationId: menu.locationId,
                        period: menu.period
                    )
                    if let existing = found[key] {
                        let candidateServing = isServing?(candidate.locationId, candidate.period) ?? false
                        let existingServing = isServing?(existing.locationId, existing.period) ?? false
                        if candidateServing && !existingServing {
                            found[key] = candidate
                        }
                    } else {
                        found[key] = candidate
                    }
                }
            }
        }
        return found.values.sorted { $0.dishName < $1.dishName }
    }
}

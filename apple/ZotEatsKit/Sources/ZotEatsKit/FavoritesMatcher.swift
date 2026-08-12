import Foundation

/// Pure matching logic behind favorite-dish alerts: given the user's favorite
/// dish names and today's menus, which favorites are actually being served?
public enum FavoritesMatcher {
    /// Early menu-drop heads-up vs live "being served now" — each may ping once.
    public enum NotifyPhase: String, Sendable, Equatable {
        case upcoming
        case serving
    }

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

        /// Stable dedupe key — one alert per day / dish / meal / phase so an
        /// early "on today's menu" ping doesn't block the live serving upgrade.
        public func dedupeKey(dateISO: String, phase: NotifyPhase) -> String {
            let pill = MealPeriodPill.canonical(period).lowercased()
            return "\(dateISO)|\(dishName.lowercased())|\(pill)|\(phase.rawValue)"
        }

        /// Pre–phase-key format (`date|dish`) — suppress duplicate upcoming
        /// after upgrade; serving upgrades still fire.
        public func legacyDedupeKey(dateISO: String) -> String {
            "\(dateISO)|\(dishName.lowercased())"
        }
    }

    /// Whether this check should post a notification for `match`.
    public static func shouldNotify(
        match: Match,
        dateISO: String,
        servingNow: Bool,
        alreadyNotified: Set<String>
    ) -> Bool {
        let phase: NotifyPhase = servingNow ? .serving : .upcoming
        let key = match.dedupeKey(dateISO: dateISO, phase: phase)
        if alreadyNotified.contains(key) { return false }
        if !servingNow, alreadyNotified.contains(match.legacyDedupeKey(dateISO: dateISO)) {
            return false
        }
        return true
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

import Foundation

/// Glance rows for the Favorites Today widget — hearted dishes on a live board.
public enum FavoritesOnMenuPick {
    public struct Row: Equatable, Sendable {
        public let dishName: String
        public let hallID: String?
        public let hallName: String?
        public let period: String?

        public init(
            dishName: String,
            hallID: String? = nil,
            hallName: String? = nil,
            period: String? = nil
        ) {
            self.dishName = dishName
            self.hallID = hallID
            self.hallName = hallName
            self.period = period
        }
    }

    /// Hearted dishes served on this meal's timed stations (not Available all day).
    /// Weekend Lunch unions Brunch and keeps Twisted Root intact, so breakfast
    /// hearts like Home-Style Pancakes would otherwise stay on the Lunch strip.
    public static func servedItems(
        favorites: some Collection<String>,
        stations: [MenuStation],
        period: String? = nil
    ) -> [MenuItem] {
        guard !favorites.isEmpty else { return [] }
        let wanted = Set(favorites.map { $0.lowercased() })
        var seen = Set<String>()
        var result: [MenuItem] = []
        for station in stations {
            if isSharedAllDayStation(station.name) { continue }
            for item in station.items {
                let key = item.name.lowercased()
                guard wanted.contains(key), seen.insert(key).inserted else { continue }
                if isBreakfastOnlyFavorite(item.name, period: period) { continue }
                result.append(item)
            }
        }
        return result
    }

    /// Eat section title. "today" is only honest for the Irvine calendar day.
    public static func sectionTitle(dateISO: String, todayISO: String) -> String {
        if dateISO == todayISO { return "Favorites today" }
        if let weekday = EatPostedDays.weekdayName(dateISO) {
            return "Favorites on \(weekday)"
        }
        return "Favorites"
    }

    /// Pancakes / scramble / hash belong on Breakfast even when Brunch TR
    /// copies them onto the Lunch board.
    public static func isBreakfastOnlyFavorite(_ name: String, period: String?) -> Bool {
        guard let period, !period.isEmpty else { return false }
        if MealPeriodPill.canonical(period) == "Breakfast" { return false }
        return DiningService.isBreakfastStyleTwistedRootName(name)
    }

    /// Shared kitchen dump folded onto every meal — not the selected period.
    public static func isSharedAllDayStation(_ name: String) -> Bool {
        CampusMenuNormalize.isAvailableAllDay(name)
            || name.localizedCaseInsensitiveContains("all day")
    }

    /// Hearted dishes that appear in this meal's timed stations, preserving favorite order.
    public static func rows(
        favorites: [String],
        stations: [MenuStation],
        hallID: String? = nil,
        hallName: String? = nil,
        period: String? = nil,
        limit: Int = 6
    ) -> [Row] {
        guard !favorites.isEmpty, limit > 0 else { return [] }
        let onBoard = Set(
            servedItems(favorites: favorites, stations: stations, period: period)
                .map { $0.name.lowercased() }
        )
        var rows: [Row] = []
        var seen = Set<String>()
        for name in favorites {
            let key = name.lowercased()
            guard onBoard.contains(key), seen.insert(key).inserted else { continue }
            rows.append(
                Row(
                    dishName: name,
                    hallID: hallID,
                    hallName: hallName,
                    period: period
                )
            )
            if rows.count >= limit { break }
        }
        return rows
    }

    /// One hall/meal board to scan for hearted dishes.
    public struct Board: Equatable, Sendable {
        public let hallID: String
        public let hallName: String
        public let period: String
        public let stations: [MenuStation]

        public init(
            hallID: String,
            hallName: String,
            period: String,
            stations: [MenuStation]
        ) {
            self.hallID = hallID
            self.hallName = hallName
            self.period = period
            self.stations = stations
        }
    }

    public struct Pick: Equatable, Sendable {
        public let hallID: String
        public let hallName: String
        public let period: String
        public let rows: [Row]

        public init(hallID: String, hallName: String, period: String, rows: [Row]) {
            self.hallID = hallID
            self.hallName = hallName
            self.period = period
            self.rows = rows
        }
    }

    /// Prefer the board with the most hearted dishes (stable order on ties).
    public static func best(
        favorites: [String],
        boards: [Board],
        limit: Int = 6
    ) -> Pick? {
        guard !favorites.isEmpty, !boards.isEmpty, limit > 0 else { return nil }
        var best: Pick?
        for board in boards {
            let matched = rows(
                favorites: favorites,
                stations: board.stations,
                hallID: board.hallID,
                hallName: board.hallName,
                period: board.period,
                limit: limit
            )
            guard !matched.isEmpty else { continue }
            if let current = best, matched.count <= current.rows.count { continue }
            best = Pick(
                hallID: board.hallID,
                hallName: board.hallName,
                period: board.period,
                rows: matched
            )
        }
        return best
    }

    public static func emptyTitle(hasFavorites: Bool) -> String {
        hasFavorites ? "None of your favorites are on this meal" : "No favorites yet"
    }

    public static func emptyMessage(hasFavorites: Bool) -> String {
        hasFavorites
            ? "Hearted dishes show up here when they're being served."
            : "Heart dishes in Eat — they'll appear here when served."
    }
}

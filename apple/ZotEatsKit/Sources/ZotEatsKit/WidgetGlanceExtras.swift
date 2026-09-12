import Foundation

/// Extra strips for larger Dining Halls / combo widgets so Medium and Large
/// actually show more than the small three-hall list.
public enum WidgetGlanceExtras {
    public struct BoardStrip: Equatable, Sendable {
        public let hallID: String
        public let hallName: String
        public let dishes: [String]

        public init(hallID: String, hallName: String, dishes: [String]) {
            self.hallID = hallID
            self.hallName = hallName
            self.dishes = dishes
        }
    }

    public struct CampusRow: Equatable, Sendable {
        public let id: String
        public let name: String
        public let hours: String

        public init(id: String, name: String, hours: String) {
            self.id = id
            self.name = name
            self.hours = hours
        }
    }

    public static func comingSoonHalls(
        from halls: [DiningLocation],
        showComingSoon: Bool
    ) -> [DiningLocation] {
        showComingSoon ? halls : halls.filter { !$0.isComingSoon }
    }

    public static func boardStrip(
        locations: [DiningLocation],
        menu: DiningMenu?,
        nowMinutes: Int,
        dietFilters: Set<String>,
        allergenAvoids: Set<String>,
        favorites: [String],
        limit: Int
    ) -> BoardStrip? {
        guard let hall = TodaysMenuHallPick.auto(from: locations, nowMinutes: nowMinutes) else {
            return nil
        }
        guard let menu, !menu.stations.isEmpty, limit > 0 else { return nil }
        let built = SharedDefaults.todaysMenuDishes(
            stations: menu.stations,
            dietFilters: dietFilters,
            allergenAvoids: allergenAvoids,
            favorites: favorites
        )
        let dishes = Array(built.ordered.prefix(limit))
        guard !dishes.isEmpty else { return nil }
        return BoardStrip(hallID: hall.id, hallName: hall.name, dishes: dishes)
    }

    public static func campusRows(
        places: [CampusPlace],
        favoriteIDs: Set<String>,
        favoritesOnly: Bool,
        limit: Int
    ) -> (rows: [CampusRow], totalOpen: Int) {
        var open = CampusPlaceSort.sortOpenForWidget(
            places: places,
            favoriteIDs: favoriteIDs
        )
        if favoritesOnly {
            open = open.filter { favoriteIDs.contains($0.id) }
        }
        let rows = open.prefix(max(0, limit)).map { place in
            CampusRow(
                id: place.id,
                name: place.name,
                hours: CampusPlaceHoursLine.widgetOpenHours(
                    todayHours: place.todayHours,
                    closesAtMinutes: place.closesAtMinutes
                )
            )
        }
        return (rows, open.count)
    }
}

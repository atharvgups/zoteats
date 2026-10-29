import Foundation

/// Dated, verified dish inserts when both Anteater API and MyDiningHub omit a
/// board Atharv confirmed in person. Fetched from GitHub `main` so later dates
/// do not need an app update. Bundled copy covers this build if `main` 404s.
public enum MenuOverrideFeed {
    public static let feedURL = URL(
        string: "https://raw.githubusercontent.com/atharvgups/zoteats/main/apple/menu-overrides.json"
    )!

    public struct Item: Codable, Equatable, Sendable {
        public var id: String
        public var name: String
        public var description: String?
        public var calories: Int?
        public var dietaryTags: [String]

        public init(
            id: String,
            name: String,
            description: String? = nil,
            calories: Int? = nil,
            dietaryTags: [String] = []
        ) {
            self.id = id
            self.name = name
            self.description = description
            self.calories = calories
            self.dietaryTags = dietaryTags
        }
    }

    public struct Override: Codable, Equatable, Sendable {
        public var date: String
        public var hall: String
        public var period: String
        public var stationID: String
        public var stationName: String
        public var verified: Bool?
        public var note: String?
        public var items: [Item]

        public init(
            date: String,
            hall: String,
            period: String,
            stationID: String,
            stationName: String,
            verified: Bool? = true,
            note: String? = nil,
            items: [Item]
        ) {
            self.date = date
            self.hall = hall
            self.period = period
            self.stationID = stationID
            self.stationName = stationName
            self.verified = verified
            self.note = note
            self.items = items
        }
    }

    public struct Payload: Codable, Equatable, Sendable {
        public var overrides: [Override]
        public init(overrides: [Override] = []) { self.overrides = overrides }
    }

    /// In-binary fallback so Internal TestFlight shows tonight's dish before
    /// this file lands on `main`.
    public static let bundled: [Override] = [
        Override(
            date: "2026-10-28",
            hall: "anteatery",
            period: "Dinner",
            stationID: "1929",
            stationName: "The Twisted Root",
            verified: true,
            note: "Atharv confirmed in person: Anteatery served Cajun Tofu and White Rice at Twisted Root for dinner. Anteater API and MyDiningHub both omitted the dish.",
            items: [
                Item(
                    id: "override:anteatery-dinner-1929-cajun-tofu-2026-10-28",
                    name: "Cajun Tofu and White Rice",
                    dietaryTags: ["Vegan", "Vegetarian"]
                ),
            ]
        ),
    ]

    public static func decode(_ data: Data) -> [Override] {
        let decoder = JSONDecoder()
        if let payload = try? decoder.decode(Payload.self, from: data) {
            return payload.overrides
        }
        if let overrides = try? decoder.decode([Override].self, from: data) {
            return overrides
        }
        return []
    }

    public static func fetch(http: any HTTPFetching, url: URL = feedURL) async -> [Override] {
        do {
            let data = try await http.data(from: url)
            return decode(data)
        } catch {
            return bundled
        }
    }

    public static func hallMatches(_ overrideHall: String, menuHall: String) -> Bool {
        let wanted = overrideHall.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        let live = menuHall.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        if wanted == live { return true }
        if HallDirectory.campusHubKey(for: live) == wanted { return true }
        if HallDirectory.eatHallID(forHubKey: wanted) == live { return true }
        return false
    }

    public static func periodMatches(_ overridePeriod: String, menuPeriod: String) -> Bool {
        MealPeriodPill.canonical(overridePeriod)
            .caseInsensitiveCompare(MealPeriodPill.canonical(menuPeriod)) == .orderedSame
    }

    /// Insert verified dishes into the matching station. Creates that station
    /// when Anteater omitted it. `pinTwistedRootFirst` keeps lane order.
    public static func applying(_ overrides: [Override], to menu: DiningMenu) -> DiningMenu {
        let matching = overrides.filter {
            $0.date == menu.date
                && hallMatches($0.hall, menuHall: menu.locationId)
                && periodMatches($0.period, menuPeriod: menu.period)
                && !$0.items.isEmpty
        }
        guard !matching.isEmpty else { return menu }

        var stations = menu.stations
        for entry in matching {
            let sid = entry.stationID.trimmingCharacters(in: .whitespacesAndNewlines)
            let name = DiningService.displayStationName(entry.stationName, stationID: sid)
            let dishes = DiningService.applyStationTags(
                entry.items.map { item in
                    MenuItem(
                        id: item.id,
                        name: item.name,
                        description: item.description,
                        calories: item.calories,
                        servingSize: nil,
                        allergens: [],
                        dietaryTags: item.dietaryTags,
                        stationID: sid
                    )
                },
                station: name,
                stationID: sid
            )
            if let idx = stations.firstIndex(where: {
                DiningService.canMergeHubExtra(into: $0, extraStationID: sid)
            }) {
                var seen = Set(stations[idx].items.map { $0.name.lowercased() })
                var next = stations[idx].items
                for dish in dishes where seen.insert(dish.name.lowercased()).inserted {
                    next.append(dish)
                }
                stations[idx] = stations[idx].withItems(next)
            } else {
                let insertAt = stations.firstIndex {
                    DiningService.stationLane(
                        name: $0.name,
                        stationID: $0.stationID,
                        items: $0.items
                    ) > .twistedRoot
                } ?? stations.endIndex
                stations.insert(
                    MenuStation(name: name, items: dishes, stationID: sid),
                    at: insertAt
                )
            }
        }
        let pinned = DiningService.pinTwistedRootFirst(stations)
        return DiningMenu(
            locationId: menu.locationId,
            date: menu.date,
            period: menu.period,
            stations: pinned
        )
    }
}

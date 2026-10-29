import Foundation

/// Dated, verified dish inserts, special-event stations, and tag corrections
/// when Atharv confirms the live board in person. Fetched from GitHub `main`
/// so later dates do not need an app update. Bundled copy covers this build
/// if `main` 404s or lags the merge.
public enum MenuOverrideFeed {
    public static let feedURL = URL(
        string: "https://raw.githubusercontent.com/atharvgups/zoteats/main/apple/menu-overrides.json"
    )!

    public struct Item: Decodable, Equatable, Sendable {
        public var id: String
        public var name: String
        public var description: String?
        public var calories: Int?
        public var dietaryTags: [String]
        public var allergens: [String]

        public init(
            id: String,
            name: String,
            description: String? = nil,
            calories: Int? = nil,
            dietaryTags: [String] = [],
            allergens: [String] = []
        ) {
            self.id = id
            self.name = name
            self.description = description
            self.calories = calories
            self.dietaryTags = dietaryTags
            self.allergens = allergens
        }

        public init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            id = try container.decode(String.self, forKey: .id)
            name = try container.decode(String.self, forKey: .name)
            description = try container.decodeIfPresent(String.self, forKey: .description)
            calories = try container.decodeIfPresent(Int.self, forKey: .calories)
            dietaryTags = try container.decodeIfPresent([String].self, forKey: .dietaryTags) ?? []
            allergens = try container.decodeIfPresent([String].self, forKey: .allergens) ?? []
        }

        enum CodingKeys: String, CodingKey {
            case id, name, description, calories, dietaryTags, allergens
        }
    }

    /// Insert dishes onto an existing station, or create that station.
    /// `kind: "special"` is a takeover / event board in the rotating middle lane.
    public struct Override: Decodable, Equatable, Sendable {
        public var date: String
        public var hall: String
        public var period: String
        public var stationID: String
        public var stationName: String
        public var kind: String?
        public var verified: Bool?
        public var note: String?
        public var items: [Item]

        public init(
            date: String,
            hall: String,
            period: String,
            stationID: String,
            stationName: String,
            kind: String? = nil,
            verified: Bool? = true,
            note: String? = nil,
            items: [Item]
        ) {
            self.date = date
            self.hall = hall
            self.period = period
            self.stationID = stationID
            self.stationName = stationName
            self.kind = kind
            self.verified = verified
            self.note = note
            self.items = items
        }

        public var isSpecial: Bool {
            let kind = kind?.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() ?? ""
            if kind == "special" || kind == "event" || kind == "takeover" { return true }
            return DiningService.isSpecialEventStation(stationName: stationName)
        }
    }

    /// Patch a dish already on the board (wrong diet tags, missing allergen).
    /// If that dish is missing, insert the corrected row onto the named station.
    public struct Correction: Decodable, Equatable, Sendable {
        public var date: String
        public var hall: String
        public var period: String
        public var matchName: String
        public var stationID: String?
        public var stationName: String?
        public var verified: Bool?
        public var note: String?
        public var removeDietaryTags: [String]
        public var addAllergens: [String]
        public var description: String?
        public var calories: Int?
        public var dietaryTags: [String]?
        public var id: String?

        public init(
            date: String,
            hall: String,
            period: String,
            matchName: String,
            stationID: String? = nil,
            stationName: String? = nil,
            verified: Bool? = true,
            note: String? = nil,
            removeDietaryTags: [String] = [],
            addAllergens: [String] = [],
            description: String? = nil,
            calories: Int? = nil,
            dietaryTags: [String]? = nil,
            id: String? = nil
        ) {
            self.date = date
            self.hall = hall
            self.period = period
            self.matchName = matchName
            self.stationID = stationID
            self.stationName = stationName
            self.verified = verified
            self.note = note
            self.removeDietaryTags = removeDietaryTags
            self.addAllergens = addAllergens
            self.description = description
            self.calories = calories
            self.dietaryTags = dietaryTags
            self.id = id
        }

        public init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            date = try container.decode(String.self, forKey: .date)
            hall = try container.decode(String.self, forKey: .hall)
            period = try container.decode(String.self, forKey: .period)
            matchName = try container.decode(String.self, forKey: .matchName)
            stationID = try container.decodeIfPresent(String.self, forKey: .stationID)
            stationName = try container.decodeIfPresent(String.self, forKey: .stationName)
            verified = try container.decodeIfPresent(Bool.self, forKey: .verified)
            note = try container.decodeIfPresent(String.self, forKey: .note)
            removeDietaryTags = try container.decodeIfPresent([String].self, forKey: .removeDietaryTags) ?? []
            addAllergens = try container.decodeIfPresent([String].self, forKey: .addAllergens) ?? []
            description = try container.decodeIfPresent(String.self, forKey: .description)
            calories = try container.decodeIfPresent(Int.self, forKey: .calories)
            dietaryTags = try container.decodeIfPresent([String].self, forKey: .dietaryTags)
            id = try container.decodeIfPresent(String.self, forKey: .id)
        }

        enum CodingKeys: String, CodingKey {
            case date, hall, period, matchName, stationID, stationName
            case verified, note, removeDietaryTags, addAllergens
            case description, calories, dietaryTags, id
        }
    }

    public struct Payload: Decodable, Equatable, Sendable {
        public var overrides: [Override]
        public var corrections: [Correction]

        public init(overrides: [Override] = [], corrections: [Correction] = []) {
            self.overrides = overrides
            self.corrections = corrections
        }

        public init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            overrides = try container.decodeIfPresent([Override].self, forKey: .overrides) ?? []
            corrections = try container.decodeIfPresent([Correction].self, forKey: .corrections) ?? []
        }

        enum CodingKeys: String, CodingKey {
            case overrides, corrections
        }
    }

    public struct Feed: Equatable, Sendable {
        public var overrides: [Override]
        public var corrections: [Correction]

        public init(overrides: [Override] = [], corrections: [Correction] = []) {
            self.overrides = overrides
            self.corrections = corrections
        }

        public var isEmpty: Bool { overrides.isEmpty && corrections.isEmpty }
    }

    /// In-binary fallback so Internal TestFlight shows today's verified board
    /// before this file lands on `main`.
    public static let bundled: Feed = Feed(
        overrides: [
            Override(
                date: "2026-10-28",
                hall: "anteatery",
                period: "Dinner",
                stationID: "1929",
                stationName: "The Twisted Root",
                kind: "insert",
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
            Override(
                date: "2026-10-29",
                hall: "anteatery",
                period: "Lunch",
                stationID: "override:fable-takeover-2026-10-29",
                stationName: "Fable Station Takeover",
                kind: "special",
                verified: true,
                note: "Atharv photographed the Fable Station Takeover board at Anteatery lunch. Anteater /events lists the takeover with no dishes.",
                items: [
                    Item(
                        id: "override:anteatery-lunch-fable-chipotle-mushroom-soft-tacos-2026-10-29",
                        name: "Chipotle Mushroom Soft Tacos",
                        description: "Sauteed chipotle mushrooms, fire-roasted salsa and warm flour tortilla",
                        calories: 180,
                        dietaryTags: ["Vegan", "Vegetarian", "Plant Forward"]
                    ),
                ]
            ),
        ],
        corrections: [
            Correction(
                date: "2026-10-29",
                hall: "anteatery",
                period: "Lunch",
                matchName: "Thai Red Curry Bowl",
                stationID: "1926",
                stationName: "Fire and Ice",
                verified: true,
                note: "Atharv confirmed in person at Anteatery lunch: the Fire and Ice Thai Red Curry Bowl contains shrimp.",
                removeDietaryTags: ["Vegan", "Vegetarian", "Plant Forward", "Plant Powered"],
                addAllergens: ["Shellfish"],
                description: "Thai red curry with shrimp, sweet potatoes and green beans served with jasmine rice topped with cilantro"
            ),
        ]
    )

    public static func decode(_ data: Data) -> Feed {
        let decoder = JSONDecoder()
        if let payload = try? decoder.decode(Payload.self, from: data) {
            return Feed(overrides: payload.overrides, corrections: payload.corrections)
        }
        if let overrides = try? decoder.decode([Override].self, from: data) {
            return Feed(overrides: overrides)
        }
        return Feed()
    }

    public static func fetch(http: any HTTPFetching, url: URL = feedURL) async -> Feed {
        do {
            let data = try await http.data(from: url)
            let feed = decode(data)
            return feed.isEmpty ? bundled : feed
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

    public static func namesMatch(_ a: String, _ b: String) -> Bool {
        DiningService.collapsedStationName(a) == DiningService.collapsedStationName(b)
    }

    public static func applying(_ overrides: [Override], to menu: DiningMenu) -> DiningMenu {
        applying(Feed(overrides: overrides), to: menu)
    }

    public static func applying(_ feed: Feed, to menu: DiningMenu) -> DiningMenu {
        let inserted = applyingInserts(feed.overrides, to: menu)
        return applyingCorrections(feed.corrections, to: inserted)
    }

    /// Insert verified dishes into the matching station. Creates that station
    /// when Anteater omitted it. Special / takeover boards land in the rotating
    /// hot-entree lane; `pinTwistedRootFirst` keeps Twisted Root first.
    public static func applyingInserts(_ overrides: [Override], to menu: DiningMenu) -> DiningMenu {
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
                        allergens: item.allergens,
                        dietaryTags: item.dietaryTags,
                        stationID: sid
                    )
                },
                station: name,
                stationID: sid
            )
            if let idx = stations.firstIndex(where: {
                canJoin(station: $0, stationID: sid, stationName: name)
            }) {
                var seen = Set(stations[idx].items.map { $0.name.lowercased() })
                var next = stations[idx].items
                for dish in dishes where seen.insert(dish.name.lowercased()).inserted {
                    next.append(dish)
                }
                stations[idx] = stations[idx].withItems(next)
            } else {
                let lane = entry.isSpecial
                    ? DiningService.StationLane.hotEntree
                    : .twistedRoot
                let insertAt = stations.firstIndex {
                    DiningService.stationLane(
                        name: $0.name,
                        stationID: $0.stationID,
                        items: $0.items
                    ) > lane
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

    public static func applyingCorrections(_ corrections: [Correction], to menu: DiningMenu) -> DiningMenu {
        let matching = corrections.filter {
            $0.date == menu.date
                && hallMatches($0.hall, menuHall: menu.locationId)
                && periodMatches($0.period, menuPeriod: menu.period)
                && !$0.matchName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        }
        guard !matching.isEmpty else { return menu }

        var stations = menu.stations
        for entry in matching {
            let needle = entry.matchName.trimmingCharacters(in: .whitespacesAndNewlines)
            var patched = false
            for idx in stations.indices {
                if let stationID = entry.stationID?.trimmingCharacters(in: .whitespacesAndNewlines),
                   !stationID.isEmpty,
                   !DiningService.canMergeHubExtra(into: stations[idx], extraStationID: stationID),
                   stations[idx].stationID != stationID {
                    continue
                }
                var items = stations[idx].items
                var changed = false
                for itemIdx in items.indices where namesMatch(items[itemIdx].name, needle) {
                    items[itemIdx] = patchedItem(items[itemIdx], with: entry)
                    changed = true
                    patched = true
                }
                if changed {
                    stations[idx] = stations[idx].withItems(items)
                }
            }
            if patched { continue }

            let sid = entry.stationID?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
            let stationName = DiningService.displayStationName(
                entry.stationName,
                stationID: sid
            )
            let dish = patchedItem(
                MenuItem(
                    id: entry.id ?? "override:correction:\(menu.locationId)-\(menu.period)-\(sid)-\(needle)-\(menu.date)"
                        .lowercased()
                        .replacingOccurrences(of: " ", with: "-"),
                    name: needle,
                    description: nil,
                    calories: nil,
                    servingSize: nil,
                    allergens: [],
                    dietaryTags: entry.dietaryTags ?? [],
                    stationID: sid.isEmpty ? nil : sid
                ),
                with: entry
            )
            if let idx = stations.firstIndex(where: {
                canJoin(station: $0, stationID: sid, stationName: stationName)
            }) {
                stations[idx] = stations[idx].withItems(stations[idx].items + [dish])
            } else {
                let insertAt = stations.firstIndex {
                    DiningService.stationLane(
                        name: $0.name,
                        stationID: $0.stationID,
                        items: $0.items
                    ) > .twistedRoot
                } ?? stations.endIndex
                stations.insert(
                    MenuStation(
                        name: stationName,
                        items: [dish],
                        stationID: sid.isEmpty ? nil : sid
                    ),
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

    private static func canJoin(station: MenuStation, stationID: String, stationName: String) -> Bool {
        if !stationID.isEmpty,
           DiningService.canMergeHubExtra(into: station, extraStationID: stationID) {
            return true
        }
        if namesMatch(station.name, stationName), stationName != "Menu" {
            return true
        }
        return false
    }

    private static func patchedItem(_ item: MenuItem, with entry: Correction) -> MenuItem {
        let remove = Set(entry.removeDietaryTags.map { $0.lowercased() })
        var tags = item.dietaryTags.filter { !remove.contains($0.lowercased()) }
        if let replacement = entry.dietaryTags {
            tags = replacement.filter { !remove.contains($0.lowercased()) }
        }
        var allergens = item.allergens
        for allergen in entry.addAllergens {
            let key = allergen.lowercased()
            if !allergens.contains(where: { $0.lowercased() == key }) {
                allergens.append(allergen)
            }
        }
        return MenuItem(
            id: item.id,
            name: item.name,
            description: entry.description ?? item.description,
            calories: entry.calories ?? item.calories,
            servingSize: item.servingSize,
            allergens: allergens,
            dietaryTags: tags,
            nutrition: item.nutrition,
            stationID: item.stationID ?? entry.stationID
        )
    }
}

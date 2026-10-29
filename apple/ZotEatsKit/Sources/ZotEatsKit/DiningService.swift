import Foundation

// UCI dining data from the Anteater API (anteaterapi.com) — the maintained, public
// UCI data API used by ICSSC's PeterPlate. Port of main/services/dining.ts.
// Endpoints (base /v2/rest/dining):
//   GET /restaurants                 -> restaurants with their stations (id + name)
//   GET /restaurantToday?id=&date=   -> periods -> stationToDishes (station id -> dish ids)
//   GET /dishes/batch?ids=a,b,c      -> full dish objects (nutrition + diet/allergen flags)
//   GET /dateRange                   -> { earliest, latest } ISO dates with menu data
// Responses use the standard { ok, data } envelope. No API key required (rate-limited).
//
// Important: restaurantToday returns HTTP 404 + "No data for this day" when a menu
// isn't published yet. That is "not posted", never a user-facing failure.

public struct DiningService: Sendable {
    private let base = "https://anteaterapi.com/v2/rest/dining"
    private let http: any HTTPFetching
    private let cache: TTLCache
    private let now: @Sendable () -> Date

    private static let stationsTTL: TimeInterval = 24 * 60 * 60
    /// Short enough that a dish added to the live board mid-meal isn't stuck
    /// behind a 20-minute TTL until pull-to-refresh. Pull-to-refresh still
    /// bypasses this entirely.
    private static let todayTTL: TimeInterval = 10 * 60
    private static let dishesTTL: TimeInterval = 30 * 60
    private static let dateRangeTTL: TimeInterval = 60 * 60

    public init(
        http: any HTTPFetching = HTTPClient(),
        cache: TTLCache = TTLCache(),
        now: @escaping @Sendable () -> Date = { Date() }
    ) {
        self.http = http
        self.cache = cache
        self.now = now
    }

    // MARK: - Wire types

    private struct Envelope<T: Decodable & Sendable>: Decodable, Sendable {
        let ok: Bool?
        let data: T?
        let message: String?
    }

    private struct APIStation: Decodable, Sendable {
        let id: String
        let name: String
    }

    private struct APIRestaurant: Decodable, Sendable {
        let id: String
        let stations: [APIStation]?
    }

    private struct APIPeriod: Decodable, Sendable {
        let name: String
        let startTime: String?
        let endTime: String?
        let stationToDishes: [String: [String]]?
    }

    private struct APIRestaurantToday: Decodable, Sendable {
        let id: String
        let periods: [String: APIPeriod]?
    }

    private struct APIDateRange: Decodable, Sendable {
        let earliest: String
        let latest: String
    }

    /// Marketing / takeover cards from `GET /events`. Title + hall + time window
    /// only; the payload has no dishes, so Eat never invents SKUs from copy.
    private struct APIEvent: Decodable, Sendable {
        let title: String?
        let restaurantId: String?
        let description: String?
        let start: String?
        let end: String?
    }

    /// Inclusive ISO-date window the dining feed currently publishes.
    public struct PublishedDateRange: Sendable, Equatable {
        public let earliest: String
        public let latest: String

        public init(earliest: String, latest: String) {
            self.earliest = earliest
            self.latest = latest
        }

        public func contains(_ isoDate: String) -> Bool {
            isoDate >= earliest && isoDate <= latest
        }
    }

    private struct APIDietRestriction: Decodable, Sendable {
        let containsEggs: Bool?
        let containsFish: Bool?
        let containsMilk: Bool?
        let containsPeanuts: Bool?
        let containsSesame: Bool?
        let containsShellfish: Bool?
        let containsSoy: Bool?
        let containsTreeNuts: Bool?
        let containsWheat: Bool?
        let isGlutenFree: Bool?
        let isHalal: Bool?
        let isKosher: Bool?
        let isLocallyGrown: Bool?
        let isOrganic: Bool?
        let isVegan: Bool?
        let isVegetarian: Bool?

        var allergens: [String] {
            [
                (containsEggs, "Eggs"),
                (containsFish, "Fish"),
                (containsMilk, "Milk"),
                (containsPeanuts, "Peanuts"),
                (containsSesame, "Sesame"),
                (containsShellfish, "Shellfish"),
                (containsSoy, "Soy"),
                (containsTreeNuts, "Tree Nuts"),
                (containsWheat, "Wheat"),
            ].filter { $0.0 == true }.map(\.1)
        }

        var dietaryTags: [String] {
            var tags = [
                (isVegan, "Vegan"),
                (isVegetarian, "Vegetarian"),
                (isHalal, "Halal"),
                (isKosher, "Kosher"),
                (isGlutenFree, "Gluten-Free"),
                (isOrganic, "Organic"),
                (isLocallyGrown, "Locally Grown"),
            ].filter { $0.0 == true }.map(\.1)
            // Vegan is a subset of vegetarian — surface both so the Vegetarian
            // filter doesn't hide explicitly vegan dishes when the API only
            // sets isVegan.
            if tags.contains("Vegan"), !tags.contains("Vegetarian") {
                tags.append("Vegetarian")
            }
            return tags
        }
    }

    private struct APINutrition: Decodable, Sendable {
        let servingSize: String?
        let servingUnit: String?
        let calories: Double?
        let proteinG: Double?
        let totalCarbsG: Double?
        let totalFatG: Double?
        let saturatedFatG: Double?
        let transFatG: Double?
        let sodiumMg: Double?
        let sugarsG: Double?
        let dietaryFiberG: Double?

        // Anteater sometimes ships numeric fields as strings; accept both.
        init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            servingSize = try container.decodeIfPresent(String.self, forKey: .servingSize)
            servingUnit = try container.decodeIfPresent(String.self, forKey: .servingUnit)
            calories = Self.flexibleDouble(container, .calories)
            proteinG = Self.flexibleDouble(container, .proteinG)
            totalCarbsG = Self.flexibleDouble(container, .totalCarbsG)
            totalFatG = Self.flexibleDouble(container, .totalFatG)
            saturatedFatG = Self.flexibleDouble(container, .saturatedFatG)
            transFatG = Self.flexibleDouble(container, .transFatG)
            sodiumMg = Self.flexibleDouble(container, .sodiumMg)
            sugarsG = Self.flexibleDouble(container, .sugarsG)
            dietaryFiberG = Self.flexibleDouble(container, .dietaryFiberG)
        }

        private static func flexibleDouble(
            _ container: KeyedDecodingContainer<CodingKeys>, _ key: CodingKeys
        ) -> Double? {
            if let number = try? container.decodeIfPresent(Double.self, forKey: key) {
                return number
            }
            if let text = try? container.decodeIfPresent(String.self, forKey: key) {
                return Double(text)
            }
            return nil
        }

        private enum CodingKeys: String, CodingKey {
            case servingSize, servingUnit, calories
            case proteinG, totalCarbsG, totalFatG, saturatedFatG, transFatG
            case sodiumMg, sugarsG, dietaryFiberG
        }
    }

    private struct APIDish: Decodable, Sendable {
        let id: String
        let stationId: String
        let name: String
        let description: String?
        let ingredients: String?
        let dietRestriction: APIDietRestriction?
        let nutritionInfo: APINutrition?
    }

    // MARK: - Fetch helpers

    private func getData<T: Decodable & Sendable>(_ type: T.Type, path: String) async throws -> T {
        guard let url = URL(string: base + path) else {
            throw URLError(.badURL)
        }
        let envelope = try await http.json(Envelope<T>.self, from: url)
        if envelope.ok == false {
            throw HTTPError.badStatus(code: 502, url: url)
        }
        guard let data = envelope.data else {
            throw HTTPError.decoding(underlying: URLError(.cannotParseResponse), url: url)
        }
        return data
    }

    /// The live commons list — the source of truth for which halls exist,
    /// so a newly opened hall appears in the app without a code change.
    private func restaurants() async throws -> [APIRestaurant] {
        try await cache.remember("dining:restaurants", ttl: Self.stationsTTL) {
            try await getData([APIRestaurant].self, path: "/restaurants")
        }
    }

    private func stationMap() async throws -> [String: String] {
        var map: [String: String] = [:]
        for restaurant in try await restaurants() {
            for station in restaurant.stations ?? [] {
                map[station.id] = station.name
            }
        }
        return map
    }

    private func today(
        for hall: String,
        dateISO: String,
        forceRefresh: Bool = false
    ) async throws -> APIRestaurantToday {
        let key = "dining:today:\(hall):\(dateISO)"
        if forceRefresh {
            await cache.invalidate(key)
        }
        return try await cache.remember(key, ttl: Self.todayTTL) {
            do {
                return try await getData(
                    APIRestaurantToday.self,
                    path: "/restaurantToday?id=\(hall)&date=\(dateISO)"
                )
            } catch HTTPError.badStatus(let code, _) where code == 404 {
                // Unpublished day — empty periods, not a transport failure.
                return APIRestaurantToday(id: hall, periods: [:])
            }
        }
    }

    /// Days the Anteater dining feed currently has menus for (clamps the day strip).
    public func publishedDateRange(forceRefresh: Bool = false) async -> PublishedDateRange? {
        do {
            if forceRefresh {
                await cache.invalidate("dining:dateRange")
            }
            return try await cache.remember("dining:dateRange", ttl: Self.dateRangeTTL) {
                let raw = try await getData(APIDateRange.self, path: "/dateRange")
                return PublishedDateRange(earliest: raw.earliest, latest: raw.latest)
            }
        } catch {
            return nil
        }
    }

    /// ISO dates in `[fromISO, throughISO]` that actually have a posted board.
    /// `/dateRange` is a window — midweek days inside it can still 404.
    public func postedMenuDates(
        hall: String,
        fromISO: String,
        throughISO: String,
        forceRefresh: Bool = false
    ) async -> Set<String> {
        let dates = EatPostedDays.isoDates(from: fromISO, through: throughISO)
        return await withTaskGroup(of: String?.self, returning: Set<String>.self) { group in
            for iso in dates {
                group.addTask {
                    let periods = await self.mealPeriods(
                        for: hall,
                        dateISO: iso,
                        forceRefresh: forceRefresh
                    )
                    return periods.isEmpty ? nil : iso
                }
            }
            var posted: Set<String> = []
            for await iso in group {
                if let iso { posted.insert(iso) }
            }
            return posted
        }
    }

    /// Chunk sizes for `/dishes/batch`. A truncated payload used to be cached
    /// for 30 minutes and silently dropped entire stations.
    static let dishBatchChunkSizes = [40, 8, 1]

    static func chunks(_ ids: [String], size: Int) -> [[String]] {
        guard size > 0, !ids.isEmpty else { return ids.isEmpty ? [] : [ids] }
        var result: [[String]] = []
        var index = ids.startIndex
        while index < ids.endIndex {
            let end = ids.index(index, offsetBy: size, limitedBy: ids.endIndex) ?? ids.endIndex
            result.append(Array(ids[index..<end]))
            index = end
        }
        return result
    }

    private func dishes(ids: [String]) async throws -> [String: APIDish] {
        let unique = Array(Set(ids)).sorted()
        guard !unique.isEmpty else { return [:] }
        var result: [String: APIDish] = [:]
        var pending = unique
        for size in Self.dishBatchChunkSizes {
            guard !pending.isEmpty else { break }
            var stillMissing: [String] = []
            for chunk in Self.chunks(pending, size: size) {
                let fetched = try await fetchDishChunk(chunk)
                for id in chunk {
                    if let dish = fetched[id] {
                        result[id] = dish
                    } else {
                        stillMissing.append(id)
                    }
                }
            }
            pending = stillMissing
            if size == 1 { break }
        }
        return result
    }

    /// Fetch one id list. Incomplete payloads are not TTL-cached so a truncated
    /// batch can't hide stations until the 30-minute dish cache expires.
    private func fetchDishChunk(_ ids: [String]) async throws -> [String: APIDish] {
        let unique = Array(Set(ids)).sorted()
        guard !unique.isEmpty else { return [:] }
        let joined = unique.joined(separator: ",")
        let key = "dining:dishes:\(joined)"
        if let cached = await cache.get(key, as: [String: APIDish].self),
           unique.allSatisfy({ cached[$0] != nil }) {
            return cached
        }
        let encoded = joined.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? joined
        let dishes = try await getData([APIDish].self, path: "/dishes/batch?ids=\(encoded)")
        let map = Dictionary(dishes.map { ($0.id, $0) }, uniquingKeysWith: { first, _ in first })
        if unique.allSatisfy({ map[$0] != nil }) {
            await cache.set(key, value: map, ttl: Self.dishesTTL)
        }
        return map
    }

    /// Meal-period presentation order: the day's natural sequence, with
    /// untimed catch-alls ("All Day") at the end. Unknown names slot by
    /// serving time between the known ones.
    static func periodRank(_ name: String, startMinutes: Int?) -> (Int, Int) {
        let known: [String: Int] = [
            "breakfast": 0, "brunch": 1, "lunch": 2, "lite lunch": 3,
            "afternoon snack": 4, "dinner": 5, "limited dinner": 5,
            "evening snack": 6, "late night": 7, "overnight": 8,
        ]
        if let rank = known[name.lowercased()] { return (rank * 100, startMinutes ?? 0) }
        if name.lowercased().contains("all day") { return (10_000, 0) }
        // Unknown timed periods sort by their start; unknown untimed go late.
        return (startMinutes.map { $0 / 60 * 100 + 50 } ?? 9_000, startMinutes ?? 0)
    }

    /// Served periods in the day's natural order (the API returns an unordered dictionary).
    private static func servedPeriods(_ today: APIRestaurantToday) -> [APIPeriod] {
        (today.periods ?? [:]).values
            .filter { !($0.stationToDishes ?? [:]).isEmpty }
            .sorted { lhs, rhs in
                let l = periodRank(lhs.name, startMinutes: PacificTime.parseMinutes(lhs.startTime))
                let r = periodRank(rhs.name, startMinutes: PacificTime.parseMinutes(rhs.startTime))
                if l != r { return l < r }
                return lhs.name < rhs.name
            }
    }

    private static func menuItem(from dish: APIDish) -> MenuItem {
        let serving: String? = dish.nutritionInfo?.servingSize.map { size in
            if let unit = dish.nutritionInfo?.servingUnit {
                let combined = "\(size) \(unit)".trimmingCharacters(in: .whitespaces)
                // Anteater sometimes ships unit as bare "fl" for fluid ounces.
                if combined.range(of: #"^\d+(\.\d+)?\s*fl$"#, options: .regularExpression) != nil {
                    return combined.replacingOccurrences(of: "fl", with: "fl oz")
                }
                return combined
            }
            return size
        }
        let description = Self.collapseWhitespace(dish.description)
        let ingredients = Self.collapseWhitespace(dish.ingredients)
        let facts = dish.nutritionInfo.map { info in
            NutritionFacts(
                proteinG: info.proteinG,
                totalCarbsG: info.totalCarbsG,
                totalFatG: info.totalFatG,
                saturatedFatG: info.saturatedFatG,
                transFatG: info.transFatG,
                sodiumMg: info.sodiumMg,
                sugarsG: info.sugarsG,
                dietaryFiberG: info.dietaryFiberG,
                ingredients: ingredients
            )
        }
        return MenuItem(
            id: dish.id,
            name: Self.collapseWhitespace(dish.name) ?? dish.name,
            description: description,
            calories: dish.nutritionInfo?.calories.map { Int($0.rounded()) },
            servingSize: serving,
            allergens: dish.dietRestriction?.allergens ?? [],
            dietaryTags: dish.dietRestriction?.dietaryTags ?? [],
            nutrition: facts,
            stationID: dish.stationId
        )
    }

    /// Anteater names/descriptions often include double spaces ("Banana  Berry").
    static func collapseWhitespace(_ text: String?) -> String? {
        guard let text else { return nil }
        let collapsed = text
            .replacingOccurrences(of: #"\s+"#, with: " ", options: .regularExpression)
            .trimmingCharacters(in: .whitespacesAndNewlines)
        return collapsed.isEmpty ? nil : collapsed
    }

    /// The Twisted Root is UCI's dedicated plant-based station at **both**
    /// The Anteatery and Brandywine. The feed often ships every diet flag as
    /// false — trust the station so Vegan / Vegetarian filters never hide it.
    public static let twistedRootStationIDs: Set<String> = [
        "1929", // The Anteatery
        "1893", // Brandywine
    ]

    /// Brandywine Ember burgers stay the same day to day. Eat still treats
    /// Ember as the standing burger board, via `standingBurgerStationIDs`.
    public static let emberStationIDs: Set<String> = [
        "1878",
    ]

    /// Standing burger / grill boards that rarely change: Brandywine Ember and
    /// Anteatery Sizzle Grill. Name matching covers a future Oasis equivalent
    /// without a one-off id. Generic "grill" is not enough (September Grill).
    public static let standingBurgerStationIDs: Set<String> = [
        "1878", // Brandywine Ember
        "1935", // The Anteatery Sizzle Grill
    ]

    /// Dessert / sweets boards: Brandywine Honeycakes and Anteatery Bakery.
    public static let dessertStationIDs: Set<String> = [
        "1872",
        "1938",
    ]

    /// Pizza boards that sit directly above the burger station. "Oven" / "Hearth"
    /// still need a pizza or flatbread dish before they count; a named Pizza
    /// station does not.
    public static let pizzaStationIDs: Set<String> = [
        "1941", // The Anteatery Oven
        "1884", // Brandywine Hearth
    ]

    /// Eat / Campus station lanes. Twisted Root first, rotating hot stations,
    /// then sides, all-day, desserts, pizza, standing burger last.
    public enum StationLane: Int, Comparable, Sendable {
        case twistedRoot = 0
        case hotEntree = 1
        case other = 2
        case sides = 3
        case availableAllDay = 4
        case dessert = 5
        case pizza = 6
        case standingBurger = 7

        public static func < (lhs: Self, rhs: Self) -> Bool {
            lhs.rawValue < rhs.rawValue
        }
    }

    /// Hub / Anteater station id → Eat hall. Used so Honeycakes 1872 never
    /// lands on Anteatery and Oven 1941 never lands on Brandywine.
    public static let stationHallIDs: [String: String] = [
        "1926": "anteatery", // Fire and Ice
        "1929": "anteatery", // The Twisted Root
        "1932": "anteatery", // Home
        "1935": "anteatery", // Sizzle Grill
        "1938": "anteatery", // Bakery
        "1941": "anteatery", // Oven
        "1944": "anteatery", // Soups
        "1947": "anteatery", // Farmer's Market
        "1950": "anteatery", // Deli
        "1953": "anteatery", // Noodle Bar
        "1872": "brandywine", // Honeycakes
        "1875": "brandywine", // The Farm Stand- Salad
        "1878": "brandywine", // Ember
        "1881": "brandywine", // Grubb
        "1884": "brandywine", // Hearth
        "1887": "brandywine", // Compass
        "1890": "brandywine", // Crossroads
        "1893": "brandywine", // The Twisted Root
        "1896": "brandywine", // Soups
        "1899": "brandywine", // Saute
        "2166": "brandywine", // The Farm Stand- Deli
        "275501": "brandywine", // Promotions
    ]

    /// Known Twisted Root station → Eat hall. Shared brand, different kitchens.
    public static func hallID(forTwistedRootStation stationID: String) -> String? {
        guard twistedRootStationIDs.contains(stationID) else { return nil }
        return hallID(forStation: stationID)
    }

    public static func hallID(forStation stationID: String) -> String? {
        stationHallIDs[stationID]
    }

    /// False when a Hub extra is tagged with the other hall's station id.
    public static func stationBelongs(onHall hallID: String, stationID: String?) -> Bool {
        guard let stationID,
              let owner = Self.hallID(forStation: stationID)
        else { return true }
        return owner.caseInsensitiveCompare(hallID) == .orderedSame
    }

    public static func collapsedStationName(_ name: String) -> String {
        name.lowercased()
            .replacingOccurrences(of: #"\s+"#, with: " ", options: .regularExpression)
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }

    public static func isTwistedRoot(stationName: String, stationID: String? = nil) -> Bool {
        if let stationID, twistedRootStationIDs.contains(stationID) { return true }
        let lowered = collapsedStationName(stationName)
        return lowered.contains("twisted root") || lowered.contains("twistedroot")
    }

    /// Takeover / pop-up boards (Fable Station Takeover). Rotating middle lane,
    /// never dessert / pizza / burger.
    public static func isSpecialEventStation(stationName: String, stationID: String? = nil) -> Bool {
        if let stationID {
            let id = stationID.lowercased()
            if id.contains("event") || id.contains("takeover") || id.hasPrefix("override:fable") {
                return true
            }
        }
        let lowered = collapsedStationName(stationName)
        if lowered.isEmpty { return false }
        if lowered.contains("takeover") { return true }
        if lowered.contains("fable") { return true }
        if lowered.contains("special event") { return true }
        if lowered.contains("pop up") || lowered.contains("popup") { return true }
        return false
    }

    public static func isEmber(stationName: String, stationID: String? = nil) -> Bool {
        if let stationID, emberStationIDs.contains(stationID) { return true }
        let lowered = collapsedStationName(stationName)
        return lowered == "ember" || lowered.hasPrefix("ember ")
    }

    public static func isStandingBurger(stationName: String, stationID: String? = nil) -> Bool {
        if let stationID, standingBurgerStationIDs.contains(stationID) { return true }
        if isEmber(stationName: stationName, stationID: stationID) { return true }
        let lowered = collapsedStationName(stationName)
        if lowered.isEmpty { return false }
        if lowered.contains("sizzle") { return true }
        if lowered.contains("burger") { return true }
        return false
    }

    public static func isDessertStation(stationName: String, stationID: String? = nil) -> Bool {
        if let stationID, dessertStationIDs.contains(stationID) { return true }
        let lowered = collapsedStationName(stationName)
        if lowered.isEmpty { return false }
        let needles = [
            "honeycake", "bakery", "dessert", "sweets", "pastry",
            "ice cream", "icecream", "cookie", "pudding",
        ]
        if needles.contains(where: { lowered.contains($0) }) { return true }
        return lowered == "sweet" || lowered.hasPrefix("sweet ") || lowered.hasSuffix(" sweet")
    }

    public static func isSidesStation(stationName: String) -> Bool {
        let lowered = collapsedStationName(stationName)
        let needles = [
            "soup", "salad", "deli", "farmer", "farm stand", "farmstand",
            "side", "vegetable", "veggie",
        ]
        return needles.contains(where: { lowered.contains($0) })
    }

    public static func isAvailableAllDayStation(stationName: String) -> Bool {
        CampusMenuNormalize.isAvailableAllDay(stationName)
            || collapsedStationName(stationName) == "all day"
    }

    public static func dishLooksLikePizza(_ name: String) -> Bool {
        let lowered = collapsedStationName(name)
        return lowered.contains("pizza") || lowered.contains("flatbread")
    }

    public static func isPizzaStation(
        stationName: String,
        stationID: String? = nil,
        items: [MenuItem] = []
    ) -> Bool {
        if isTwistedRoot(stationName: stationName, stationID: stationID) { return false }
        if isStandingBurger(stationName: stationName, stationID: stationID) { return false }
        let lowered = collapsedStationName(stationName)
        if lowered.contains("pizza") || lowered.contains("pizzeria") { return true }
        let maybePizzaBoard: Bool = {
            if let stationID, pizzaStationIDs.contains(stationID) { return true }
            if lowered == "oven" || lowered.hasPrefix("oven ") || lowered.hasSuffix(" oven") {
                return true
            }
            if lowered.contains(" oven ") { return true }
            if lowered == "hearth" || lowered.hasPrefix("hearth ") || lowered.hasSuffix(" hearth") {
                return true
            }
            return false
        }()
        guard maybePizzaBoard else { return false }
        return items.contains { dishLooksLikePizza($0.name) }
    }

    public static func stationLane(
        name: String,
        stationID: String? = nil,
        items: [MenuItem] = []
    ) -> StationLane {
        if isTwistedRoot(stationName: name, stationID: stationID) { return .twistedRoot }
        if isSpecialEventStation(stationName: name, stationID: stationID) { return .hotEntree }
        if isStandingBurger(stationName: name, stationID: stationID) { return .standingBurger }
        if isAvailableAllDayStation(stationName: name) { return .availableAllDay }
        if isDessertStation(stationName: name, stationID: stationID) { return .dessert }
        if isPizzaStation(stationName: name, stationID: stationID, items: items) { return .pizza }
        if isSidesStation(stationName: name) { return .sides }
        let lowered = collapsedStationName(name)
        if lowered.contains("promotion") || lowered == "also served" {
            return .other
        }
        return .hotEntree
    }

    /// Prefer the live name; fall back to the brand so a missing station map
    /// never relabels Twisted Root as generic "Menu".
    public static func displayStationName(_ mapped: String?, stationID: String) -> String {
        let trimmed = mapped?
            .trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        if isTwistedRoot(stationName: trimmed, stationID: stationID) {
            return isTwistedRoot(stationName: trimmed) ? trimmed : "The Twisted Root"
        }
        return trimmed.isEmpty ? "Menu" : trimmed
    }

    public static func applyStationTags(
        _ items: [MenuItem],
        station: String,
        stationID: String? = nil
    ) -> [MenuItem] {
        guard isTwistedRoot(stationName: station, stationID: stationID) else { return items }
        return items.map { item in
            var tags = item.dietaryTags
            if !tags.contains(where: { $0.caseInsensitiveCompare("Vegan") == .orderedSame }) {
                tags.insert("Vegan", at: 0)
            }
            if !tags.contains(where: { $0.caseInsensitiveCompare("Vegetarian") == .orderedSame }) {
                tags.append("Vegetarian")
            }
            guard tags != item.dietaryTags else { return item }
            return MenuItem(
                id: item.id,
                name: item.name,
                description: item.description,
                calories: item.calories,
                servingSize: item.servingSize,
                allergens: item.allergens,
                dietaryTags: tags,
                nutrition: item.nutrition,
                stationID: item.stationID ?? stationID
            )
        }
    }

    /// Re-apply Twisted Root overrides on an already-built menu (UI filter path).
    public static func withStationDietOverrides(_ menu: DiningMenu) -> DiningMenu {
        DiningMenu(
            locationId: menu.locationId,
            date: menu.date,
            period: menu.period,
            stations: menu.stations.map { station in
                station.withItems(
                    applyStationTags(
                        station.items,
                        station: station.name,
                        stationID: station.stationID
                    )
                )
            }
        )
    }

    /// Twisted Root leads Eat and Campus food lists. Rotating hot stations
    /// come next, then sides, all-day, desserts, pizza, and the standing
    /// burger/grill board last. Relative order inside a lane is preserved.
    public static func pinTwistedRootFirst(_ stations: [MenuStation]) -> [MenuStation] {
        stations.enumerated()
            .sorted { lhs, rhs in
                let left = stationLane(
                    name: lhs.element.name,
                    stationID: lhs.element.stationID,
                    items: lhs.element.items
                )
                let right = stationLane(
                    name: rhs.element.name,
                    stationID: rhs.element.stationID,
                    items: rhs.element.items
                )
                if left != right { return left < right }
                return lhs.offset < rhs.offset
            }
            .map(\.element)
    }

    /// Marketing event from Anteater `/events` (title, hall, time; no dishes).
    public struct DiningEvent: Equatable, Sendable {
        public var title: String
        public var restaurantId: String
        public var start: Date?
        public var end: Date?

        public init(title: String, restaurantId: String, start: Date? = nil, end: Date? = nil) {
            self.title = title
            self.restaurantId = restaurantId
            self.start = start
            self.end = end
        }
    }

    public static func parseEventDate(_ raw: String?) -> Date? {
        guard let raw, !raw.isEmpty else { return nil }
        let withFraction = ISO8601DateFormatter()
        withFraction.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        if let date = withFraction.date(from: raw) { return date }
        let basic = ISO8601DateFormatter()
        basic.formatOptions = [.withInternetDateTime]
        return basic.date(from: raw)
    }

    /// True when this event is for this hall, covers the Irvine date, and
    /// overlaps the meal window. Events before 2024 (epoch placeholders) skip.
    public static func eventOverlapsMeal(
        _ event: DiningEvent,
        hallID: String,
        dateISO: String,
        periodStartMinutes: Int?,
        periodEndMinutes: Int?
    ) -> Bool {
        let title = event.title.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !title.isEmpty else { return false }
        guard MenuOverrideFeed.hallMatches(event.restaurantId, menuHall: hallID) else {
            return false
        }
        guard let start = event.start else { return false }
        let year = PacificTime.calendar.component(.year, from: start)
        if year < 2024 { return false }
        let startDay = PacificTime.todayISO(now: start)
        let endDay = PacificTime.todayISO(now: event.end ?? start)
        guard dateISO >= startDay, dateISO <= endDay else { return false }

        let eventStartMinutes: Int = {
            if dateISO == startDay { return PacificTime.nowMinutes(now: start) }
            return 0
        }()
        let eventEndMinutes: Int = {
            if let end = event.end {
                if dateISO == PacificTime.todayISO(now: end) {
                    return PacificTime.nowMinutes(now: end)
                }
                return 24 * 60
            }
            return eventStartMinutes + 3 * 60
        }()
        guard let periodStart = periodStartMinutes, let periodEnd = periodEndMinutes else {
            // Untimed meal (weekend Lunch clone): keep lunch-hours events off it.
            return false
        }
        return eventStartMinutes < periodEnd && eventEndMinutes > periodStart
    }

    /// Add takeover stations named from `/events`. Empty boards are dropped
    /// after override dishes land, so marketing copy never becomes a fake SKU.
    public static func attachingEvents(
        _ events: [DiningEvent],
        to menu: DiningMenu,
        periodStartMinutes: Int?,
        periodEndMinutes: Int?
    ) -> DiningMenu {
        let matching = events.filter {
            eventOverlapsMeal(
                $0,
                hallID: menu.locationId,
                dateISO: menu.date,
                periodStartMinutes: periodStartMinutes,
                periodEndMinutes: periodEndMinutes
            )
        }
        guard !matching.isEmpty else { return menu }
        var stations = menu.stations
        for event in matching {
            let name = event.title.trimmingCharacters(in: .whitespacesAndNewlines)
            if stations.contains(where: { collapsedStationName($0.name) == collapsedStationName(name) }) {
                continue
            }
            let sid = "event:\(menu.locationId):\(collapsedStationName(name).replacingOccurrences(of: " ", with: "-"))"
            let insertAt = stations.firstIndex {
                stationLane(name: $0.name, stationID: $0.stationID, items: $0.items) > .hotEntree
            } ?? stations.endIndex
            stations.insert(MenuStation(name: name, items: [], stationID: sid), at: insertAt)
        }
        return DiningMenu(
            locationId: menu.locationId,
            date: menu.date,
            period: menu.period,
            stations: pinTwistedRootFirst(stations)
        )
    }

    public static func droppingEmptyStations(_ menu: DiningMenu) -> DiningMenu {
        let kept = menu.stations.filter { !$0.items.isEmpty }
        guard kept != menu.stations else { return menu }
        return DiningMenu(
            locationId: menu.locationId,
            date: menu.date,
            period: menu.period,
            stations: kept
        )
    }

    // MARK: - Public API

    /// Every dining commons the live API lists (a new hall shows up here
    /// automatically) with today's hours, open state, and served meal periods.
    /// Pass `forceRefresh` at publish probes / pull-to-refresh so a stale
    /// empty or breakfast-only board — and tomorrow / next-open metadata —
    /// is not reused for up to 20 minutes.
    public func locations(forceRefresh: Bool = false) async -> [DiningLocation] {
        let dateISO = PacificTime.todayISO(now: now())
        let nowMinutes = PacificTime.nowMinutes(now: now())

        // Live hall list first; the maintained fallback keeps the UI alive offline.
        let hallIDs = (try? await restaurants().map(\.id)) ?? HallDirectory.fallbackIDs

        var results: [DiningLocation] = []
        await withTaskGroup(of: DiningLocation.self) { group in
            for hall in hallIDs {
                group.addTask {
                    await location(
                        for: hall,
                        dateISO: dateISO,
                        nowMinutes: nowMinutes,
                        forceRefresh: forceRefresh
                    )
                }
            }
            for await location in group {
                results.append(location)
            }
        }
        // TaskGroup completion order is nondeterministic; present halls in a stable order.
        var ordered = hallIDs.compactMap { id in results.first { $0.id == id } }
        return await withHonestOasis(ordered, dateISO: dateISO)
    }

    /// Anteater API wins when `/restaurants` lists Oasis with a menu.
    /// Else use Hub SKUs when they exist (even if the page still says Coming
    /// Soon). Else keep the tile with Hub weekday hours and no invented dishes.
    private func withHonestOasis(
        _ ordered: [DiningLocation],
        dateISO: String
    ) async -> [DiningLocation] {
        if ordered.contains(where: {
            HallDirectory.isOasis($0.id) && !$0.isComingSoon && !$0.availablePeriods.isEmpty
        }) {
            return ordered
        }
        var next = ordered.filter { !HallDirectory.isOasis($0.id) }
        let hub = CampusService(http: http, cache: cache, now: now)
        let urlKey = HallDirectory.campusHubKey(for: HallDirectory.oasisComingSoonID)
            ?? "the-oasis-dining-hall"
        let recipes = (try? await hub.menu(
            for: urlKey,
            placeName: HallDirectory.displayName(for: HallDirectory.oasisComingSoonID),
            date: dateISO,
            allowTypicalFallback: false
        )) ?? []
        if !recipes.isEmpty {
            next.append(Self.oasisLocationFromHubRecipes(recipes, dateISO: dateISO, now: now()))
            return next
        }
        next.append(Self.oasisComingSoonLocation(dateISO: dateISO, now: now()))
        return next
    }

    /// Hub posted SKUs. Meal-period names become available periods. Attach
    /// Hub weekday hours so the tile can show until/opens like the other halls.
    private static func oasisLocationFromHubRecipes(
        _ recipes: [MenuStation],
        dateISO: String,
        now: Date
    ) -> DiningLocation {
        let names = recipes.map(\.name).filter { !$0.trimmingCharacters(in: .whitespaces).isEmpty }
        let weekday = PacificTime.weekdayName(now: now)
        let nowMinutes = PacificTime.nowMinutes(now: now)
        let windows = OasisSchedule.mealWindows(on: dateISO, weekday: weekday)
        let next = OasisSchedule.nextService(after: dateISO)
        return DiningLocation(
            id: HallDirectory.oasisComingSoonID,
            name: HallDirectory.displayName(for: HallDirectory.oasisComingSoonID),
            area: HallDirectory.area(for: HallDirectory.oasisComingSoonID),
            openNow: OasisSchedule.isOpen(on: dateISO, weekday: weekday, nowMinutes: nowMinutes),
            todayHours: OasisSchedule.todayHours(on: dateISO, weekday: weekday),
            availablePeriods: names,
            periods: windows,
            hoursApproximate: true,
            opensTomorrowAtMinutes: next?.dayOffset == 1 ? next?.minutes : nil,
            opensTomorrowPeriod: next?.dayOffset == 1 ? next?.period : nil,
            opensNextAtMinutes: (next?.dayOffset ?? 0) >= 2 ? next?.minutes : nil,
            opensNextDayOffset: (next?.dayOffset ?? 0) >= 2 ? next?.dayOffset : nil,
            opensNextWeekday: (next?.dayOffset ?? 0) >= 2 ? next?.weekday : nil,
            opensNextPeriod: (next?.dayOffset ?? 0) >= 2 ? next?.period : nil,
            opensNextDateISO: (next?.dayOffset ?? 0) >= 2 ? next?.iso : nil
        )
    }

    /// Placeholder tile while no official Oasis dishes exist. Hub weekday
    /// hours are real; the board stays empty.
    public static func oasisComingSoonLocation(
        dateISO: String = UCITime.todayISO(),
        now: Date = Date()
    ) -> DiningLocation {
        let weekday = PacificTime.weekdayName(now: now)
        let nowMinutes = PacificTime.nowMinutes(now: now)
        let windows = OasisSchedule.mealWindows(on: dateISO, weekday: weekday)
        let next = OasisSchedule.nextService(after: dateISO)
        return DiningLocation(
            id: HallDirectory.oasisComingSoonID,
            name: HallDirectory.displayName(for: HallDirectory.oasisComingSoonID),
            area: HallDirectory.area(for: HallDirectory.oasisComingSoonID),
            openNow: OasisSchedule.isOpen(on: dateISO, weekday: weekday, nowMinutes: nowMinutes),
            todayHours: OasisSchedule.todayHours(on: dateISO, weekday: weekday),
            availablePeriods: [],
            periods: windows,
            hoursApproximate: true,
            opensTomorrowAtMinutes: next?.dayOffset == 1 ? next?.minutes : nil,
            opensTomorrowPeriod: next?.dayOffset == 1 ? next?.period : nil,
            opensNextAtMinutes: (next?.dayOffset ?? 0) >= 2 ? next?.minutes : nil,
            opensNextDayOffset: (next?.dayOffset ?? 0) >= 2 ? next?.dayOffset : nil,
            opensNextWeekday: (next?.dayOffset ?? 0) >= 2 ? next?.weekday : nil,
            opensNextPeriod: (next?.dayOffset ?? 0) >= 2 ? next?.period : nil,
            opensNextDateISO: (next?.dayOffset ?? 0) >= 2 ? next?.iso : nil,
            comingSoonSubtitle: OasisComingSoonCopy.unpostedCard
        )
    }

    /// Meal-period windows for a hall on a specific Irvine ISO date.
    /// Empty when unpublished (404) or offline — never throws.
    public func mealPeriods(
        for hall: String,
        dateISO: String,
        forceRefresh: Bool = false
    ) async -> [MealPeriodWindow] {
        do {
            let periods = Self.servedPeriods(
                try await today(for: hall, dateISO: dateISO, forceRefresh: forceRefresh)
            )
            return periods.map {
                MealPeriodWindow(
                    name: $0.name,
                    startMinutes: PacificTime.parseMinutes($0.startTime),
                    endMinutes: PacificTime.parseMinutes($0.endTime)
                )
            }
        } catch {
            return []
        }
    }

    private func location(
        for hall: String,
        dateISO: String,
        nowMinutes: Int,
        forceRefresh: Bool = false
    ) async -> DiningLocation {
        let calendar = PacificTime.calendar
        let tomorrowDate = calendar.date(byAdding: .day, value: 1, to: now()) ?? now()
        let tomorrowISO = PacificTime.todayISO(now: tomorrowDate)
        // Force-refresh must also re-fetch tomorrow / next-open boards — otherwise
        // pull-to-refresh can leave "Closed for today" / Monday chrome stuck on a
        // cached empty next day while today's board updates.
        async let tomorrowWindows = mealPeriods(
            for: hall,
            dateISO: tomorrowISO,
            forceRefresh: forceRefresh
        )

        do {
            let periods = Self.servedPeriods(
                try await today(for: hall, dateISO: dateISO, forceRefresh: forceRefresh)
            )
            let starts = periods.compactMap { PacificTime.parseMinutes($0.startTime) }
            let ends = periods.compactMap { PacificTime.parseMinutes($0.endTime) }
            let openNow = periods.contains { period in
                guard let start = PacificTime.parseMinutes(period.startTime),
                      let end = PacificTime.parseMinutes(period.endTime)
                else { return false }
                return nowMinutes >= start && nowMinutes < end
            }
            let todayHours: String? = (starts.isEmpty || ends.isEmpty)
                ? nil
                : "\(PacificTime.formatMinutes(starts.min()!)) – \(PacificTime.formatMinutes(ends.max()!))"
            let tomorrow = await Self.tomorrowOpening(from: tomorrowWindows)
            let next = await nextOpenBeyondTomorrow(
                hall: hall,
                tomorrowMinutes: tomorrow.minutes,
                forceRefresh: forceRefresh
            )
            return DiningLocation(
                id: hall,
                name: HallDirectory.displayName(for: hall),
                area: HallDirectory.area(for: hall),
                openNow: openNow,
                todayHours: todayHours,
                availablePeriods: periods.map(\.name),
                periods: periods.map {
                    MealPeriodWindow(
                        name: $0.name,
                        startMinutes: PacificTime.parseMinutes($0.startTime),
                        endMinutes: PacificTime.parseMinutes($0.endTime)
                    )
                },
                hoursApproximate: false,
                opensTomorrowAtMinutes: tomorrow.minutes,
                opensTomorrowPeriod: tomorrow.period,
                opensNextAtMinutes: next?.minutes,
                opensNextDayOffset: next?.dayOffset,
                opensNextWeekday: next?.weekday,
                opensNextPeriod: next?.period,
                opensNextDateISO: next?.dateISO
            )
        } catch {
            let tomorrow = await Self.tomorrowOpening(from: tomorrowWindows)
            let next = await nextOpenBeyondTomorrow(
                hall: hall,
                tomorrowMinutes: tomorrow.minutes,
                forceRefresh: forceRefresh
            )
            return DiningLocation(
                id: hall,
                name: HallDirectory.displayName(for: hall),
                area: HallDirectory.area(for: hall),
                openNow: false,
                todayHours: nil,
                availablePeriods: [],
                periods: [],
                hoursApproximate: false,
                opensTomorrowAtMinutes: tomorrow.minutes,
                opensTomorrowPeriod: tomorrow.period,
                opensNextAtMinutes: next?.minutes,
                opensNextDayOffset: next?.dayOffset,
                opensNextWeekday: next?.weekday,
                opensNextPeriod: next?.period,
                opensNextDateISO: next?.dateISO
            )
        }
    }

    /// When tomorrow is unpublished, scan further days inside `/dateRange`.
    private func nextOpenBeyondTomorrow(
        hall: String,
        tomorrowMinutes: Int?,
        forceRefresh: Bool = false
    ) async -> DiningNextOpen.Result? {
        guard tomorrowMinutes == nil else { return nil }
        let latest = await publishedDateRange(forceRefresh: forceRefresh)?.latest
        return await DiningNextOpen.find(
            from: now(),
            latestISO: latest,
            periodsForDay: { iso in
                await mealPeriods(for: hall, dateISO: iso, forceRefresh: forceRefresh)
            }
        )
    }

    /// Earliest timed meal on tomorrow's board (for after-hours status).
    private static func tomorrowOpening(
        from periods: [MealPeriodWindow]
    ) -> (minutes: Int?, period: String?) {
        guard let minutes = OpeningAlertPlanner.earliestOpening(periods: periods) else {
            return (nil, nil)
        }
        let period = periods.first { $0.startMinutes == minutes }?.name
        return (minutes, period)
    }

    /// Always-visible Eat meal chips. Unposted meals stay tappable and show
    /// the empty board instead of invented dishes.
    public static let mealSelectorPills = [
        "Breakfast", "Lunch", "Afternoon Snack", "Dinner", "Late Night",
    ]

    /// Primary meal pills present on a board. Chronological: Breakfast, Lunch,
    /// Afternoon Snack, Dinner, Late Night last. Brunch maps into Breakfast;
    /// Evening Snack / Overnight map into Late Night; All Day is folded into
    /// each meal as "Available all day" (no own pill).
    /// Prefer `mealSelectorPills` for the Eat chip row so unposted meals stay tappable.
    public static func primaryPeriods(from available: [String]) -> [String] {
        var result: [String] = []
        if available.contains(where: { $0.caseInsensitiveCompare("Breakfast") == .orderedSame })
            || available.contains(where: { $0.caseInsensitiveCompare("Brunch") == .orderedSame }) {
            result.append("Breakfast")
        }
        if available.contains(where: { $0.caseInsensitiveCompare("Lunch") == .orderedSame }) {
            result.append("Lunch")
        }
        if available.contains(where: { MealPeriodPill.isAfternoonSnack($0.lowercased()) }) {
            result.append("Afternoon Snack")
        }
        if available.contains(where: {
            $0.caseInsensitiveCompare("Dinner") == .orderedSame
                || $0.caseInsensitiveCompare("Limited Dinner") == .orderedSame
        }) {
            result.append("Dinner")
        }
        if available.contains(where: { MealPeriodPill.isLateNight($0.lowercased()) }) {
            result.append("Late Night")
        }
        return result
    }

    /// Whether this Eat chip has a real posted period (not an invented menu).
    public static func pillIsPosted(_ pill: String, available: [String]) -> Bool {
        primaryPeriods(from: available).contains { $0.caseInsensitiveCompare(pill) == .orderedSame }
    }

    /// Resolve a primary pill to the real API period name for a hall.
    public static func resolvePeriod(_ primary: String, available: [String]) -> String {
        let match: (String) -> String? = { name in
            available.first { $0.caseInsensitiveCompare(name) == .orderedSame }
        }
        switch primary.lowercased() {
        case "breakfast":
            return match("Breakfast") ?? match("Brunch") ?? primary
        case "lunch":
            // Posted Lunch only for the board. Brunch fallback is for
            // chrome / widgets — menuPeriodNames will not scrape Brunch
            // onto an unposted Lunch pill (that duplicated Breakfast).
            return match("Lunch") ?? match("Brunch") ?? primary
        case "dinner":
            return match("Dinner") ?? match("Limited Dinner") ?? primary
        case "afternoon snack":
            return available.first(where: { MealPeriodPill.isAfternoonSnack($0.lowercased()) }) ?? primary
        case "late night":
            return match("Late Night")
                ?? match("Evening Snack")
                ?? match("Overnight")
                ?? available.first(where: { MealPeriodPill.isLateNight($0.lowercased()) })
                ?? primary
        default:
            return match(primary) ?? primary
        }
    }

    /// Chip label for an Eat pill. Weekend boards that only posted Brunch
    /// show "Brunch" on the Breakfast chip so the row is not a fake B/L pair.
    /// Overnight / Evening Snack always read as Late Night.
    public static func mealPillLabel(_ pill: String, available: [String]) -> String {
        if MealPeriodPill.canonical(pill) == "Late Night" { return "Late Night" }
        guard pillIsPosted(pill, available: available) else { return pill }
        let resolved = resolvePeriod(pill, available: available)
        return MealPeriodDisplay.label(live: resolved, pill: pill)
    }

    public static func isWeekend(dateISO: String) -> Bool {
        guard let weekday = EatPostedDays.weekdayName(dateISO) else { return false }
        return weekday == "Saturday" || weekday == "Sunday"
    }

    /// Eat chips. Late Night is weekdays only, and only when that board posted.
    public static func visibleMealPills(available: [String], dateISO: String) -> [String] {
        mealSelectorPills.filter { pill in
            guard MealPeriodPill.canonical(pill) == "Late Night" else { return true }
            return !isWeekend(dateISO: dateISO) && pillIsPosted(pill, available: available)
        }
    }

    /// Periods to scrape for a primary pill. Each pill keeps that period's
    /// dishes — Lunch does not union Brunch (weekend Brunch is Breakfast ∪
    /// All-Day, so the union made Breakfast and Lunch identical). Unposted
    /// Lunch stays empty instead of copying the Brunch board already on
    /// Breakfast. Breakfast still falls through to Brunch when that is the
    /// only morning period.
    public static func menuPeriodNames(primary: String, available: [String]) -> [String] {
        func match(_ needle: String) -> String? {
            available.first { $0.caseInsensitiveCompare(needle) == .orderedSame }
        }
        if MealPeriodPill.canonical(primary) == "Lunch" {
            // Posted Lunch only. Do not scrape Brunch — that board belongs
            // on the Breakfast chip when Lunch was never published.
            guard let lunch = match("Lunch") else { return [] }
            return lunch.localizedCaseInsensitiveContains("all day") ? [] : [lunch]
        }
        let resolved = resolvePeriod(primary, available: available)
        guard !resolved.localizedCaseInsensitiveContains("all day"),
              let name = match(resolved)
        else { return [] }
        return [name]
    }

    /// Weekend Brunch is often Breakfast plus the All-Day grill. After Lunch
    /// unions Brunch, drop dishes that are only on Breakfast so eggs and
    /// oatmeal do not show under the Lunch pill. Dishes that Lunch itself
    /// posted stay, even if Breakfast also lists them.
    public static func subtractingBreakfastOnlyBrunchDishes(
        from merged: [MenuStation],
        lunch: [MenuStation],
        breakfast: [MenuStation]
    ) -> [MenuStation] {
        let breakfastKeys = hubBoardNameKeys(from: breakfast.flatMap(\.items))
        guard !breakfastKeys.isEmpty else { return merged }
        let lunchKeys = hubBoardNameKeys(from: lunch.flatMap(\.items))
        return merged.compactMap { station in
            // Weekend Brunch Twisted Root is the midday plant-based board.
            // Those dishes often also appear at Breakfast; do not erase the
            // station from Lunch after the Brunch union (Atharv Sat Oct 3).
            if isTwistedRoot(stationName: station.name, stationID: station.stationID) {
                return station
            }
            let kept = station.items.filter { item in
                appearsOnHubBoard(item, keys: lunchKeys) || !appearsOnHubBoard(item, keys: breakfastKeys)
            }
            return kept.isEmpty ? nil : station.withItems(kept)
        }
    }

    /// Eggs, hash, scramble stay on Breakfast even when Brunch copies them.
    /// Shawarma / grain bowls that Brunch also lists are midday, not 9am.
    public static func isBreakfastStyleTwistedRootName(_ name: String) -> Bool {
        let n = name.lowercased()
        let tokens = [
            "scramble", "hash", "egg", "oatmeal", "sausage", "bacon",
            "pancake", "waffle", "breakfast", "yogurt", "muffin", "chia",
            "french toast",
        ]
        return tokens.contains { n.contains($0) }
    }

    /// Twisted Root names from Brunch / Lunch. Breakfast uses this to drop
    /// midday entrees Anteater and Hub copy onto the 9am board.
    public static func middayTwistedRootKeys(from groups: [[MenuStation]]) -> Set<String> {
        let items = groups.flatMap { group in
            group.filter { isTwistedRoot(stationName: $0.name, stationID: $0.stationID) }
                .flatMap(\.items)
        } + groups.flatMap { group in
            group.flatMap(\.items).filter { isTwistedRoot(stationName: "", stationID: $0.stationID) }
        }
        return hubBoardNameKeys(from: items)
    }

    public static func middayTwistedRootKeys(hubStations: [MenuStation]) -> Set<String> {
        let midday = hubStations.filter { station in
            let name = station.name.lowercased()
            return name.contains("brunch") || (name.contains("lunch") && !name.contains("brunch"))
        }
        return middayTwistedRootKeys(from: [midday])
    }

    /// Keep hash/eggs on Breakfast. Drop shawarma and other Brunch Twisted
    /// Root copies Atharv says are served at lunch (Sun Oct 4).
    public static func subtractingMiddayTwistedRootFromBreakfast(
        from stations: [MenuStation],
        midday: [MenuStation]
    ) -> [MenuStation] {
        let middayKeys = middayTwistedRootKeys(from: [midday])
        guard !middayKeys.isEmpty else { return stations }
        return stations.compactMap { station in
            guard isTwistedRoot(stationName: station.name, stationID: station.stationID) else {
                return station
            }
            let kept = station.items.filter {
                shouldKeepTwistedRootOnBreakfast($0, middayKeys: middayKeys)
            }
            return kept.isEmpty ? nil : station.withItems(kept)
        }
    }

    static func shouldKeepTwistedRootOnBreakfast(
        _ item: MenuItem,
        middayKeys: Set<String>
    ) -> Bool {
        if isBreakfastStyleTwistedRootName(item.name) { return true }
        return !appearsOnHubBoard(item, keys: middayKeys)
    }

    /// Union stations from several meal periods. Same station id (or name when
    /// the id is unknown) keeps one section; items are deduped by name.
    public static func mergeStations(_ groups: [MenuStation]...) -> [MenuStation] {
        mergeStationLists(Array(groups))
    }

    public static func mergeKey(for station: MenuStation) -> String? {
        if let id = station.stationID?.trimmingCharacters(in: .whitespacesAndNewlines),
           !id.isEmpty {
            return "id:\(id)"
        }
        let name = station.name.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        return name.isEmpty ? nil : "name:\(name)"
    }

    public static func mergeStationLists(_ groups: [[MenuStation]]) -> [MenuStation] {
        var displayName: [String: String] = [:]
        var order: [String] = []
        var items: [String: [MenuItem]] = [:]
        var seen: [String: Set<String>] = [:]
        var ids: [String: String] = [:]

        for group in groups {
            for station in group {
                guard let key = mergeKey(for: station) else { continue }
                if displayName[key] == nil {
                    displayName[key] = station.name.trimmingCharacters(in: .whitespacesAndNewlines)
                    order.append(key)
                    items[key] = []
                    seen[key] = []
                }
                if ids[key] == nil,
                   let stationID = station.stationID?.trimmingCharacters(in: .whitespacesAndNewlines),
                   !stationID.isEmpty {
                    ids[key] = stationID
                }
                for item in station.items {
                    let nameKey = item.name.lowercased()
                    if seen[key]!.insert(nameKey).inserted {
                        items[key]!.append(item)
                    }
                }
            }
        }
        return order.compactMap { key in
            guard let name = displayName[key], let list = items[key], !list.isEmpty else {
                return nil
            }
            return MenuStation(name: name, items: list, stationID: ids[key])
        }
    }

    /// Hub meal-period sections that belong on this Eat pill. Match by pill
    /// name, not list position. Lunch stays Lunch; Breakfast uses Brunch
    /// only when Hub posted no Breakfast; Dinner never picks up brunch.
    public static func hubMealStations(
        matchingPeriod period: String,
        in hubStations: [MenuStation]
    ) -> [MenuStation] {
        let lowerPeriod = period.lowercased()
        if lowerPeriod.contains("brunch") {
            return hubStations.filter { $0.name.lowercased().contains("brunch") }
        }
        let pill = MealPeriodPill.canonical(period)
        let hasBreakfast = hubStations.contains {
            let name = $0.name.lowercased()
            return name.contains("breakfast") && !name.contains("brunch")
        }
        let hasLunch = hubStations.contains {
            let name = $0.name.lowercased()
            return name.contains("lunch") && !name.contains("brunch")
        }
        return hubStations.filter { station in
            let name = station.name.lowercased()
            switch pill {
            case "Lunch":
                // Do not pull Brunch onto Lunch — weekend Brunch is the
                // breakfast board plus All Day, which made the pills match.
                return hasLunch && name.contains("lunch") && !name.contains("brunch")
            case "Breakfast":
                if hasBreakfast {
                    return name.contains("breakfast") && !name.contains("brunch")
                }
                return name.contains("brunch")
            case "Dinner":
                return name.contains("dinner")
            default:
                return name.caseInsensitiveCompare(period) == .orderedSame
            }
        }
    }

    /// Official Hub names for this meal. All-Day Twisted Root is not copied
    /// onto this list: dropping stays meal-specific so an All-Day staple
    /// cannot hide a breakfast or dinner dish. Lunch drops Hub Breakfast-only
    /// dishes that arrived via Brunch.
    public static func hubBoardItems(
        matchingPeriod period: String,
        hubStations: [MenuStation]
    ) -> [MenuItem] {
        let matching = hubMealStations(matchingPeriod: period, in: hubStations)
            .flatMap(\.items)
        return excludingBreakfastOnlyBrunchItems(matching, period: period, hubStations: hubStations)
    }

    /// Twisted Root Hub lists on All Day and on no timed meal. Those are
    /// actually served all day, so extras may add them to every pill. A dish
    /// Hub also filed on Breakfast / Lunch / Dinner stays on that meal only.
    static func allDayOnlyTwistedRootItems(in hubStations: [MenuStation]) -> [MenuItem] {
        let timed = hubStations
            .filter { station in
                let name = station.name.lowercased()
                if name.contains("all day") { return false }
                return name.contains("breakfast")
                    || name.contains("brunch")
                    || name.contains("lunch")
                    || name.contains("dinner")
            }
            .flatMap(\.items)
        let timedKeys = hubBoardNameKeys(from: timed)
        let allDayItems = hubStations
            .filter { $0.name.localizedCaseInsensitiveContains("all day") }
            .flatMap(\.items)
        var seen = Set<String>()
        var extras: [MenuItem] = []
        for item in allDayItems {
            guard isTwistedRoot(stationName: "", stationID: item.stationID) else { continue }
            let key = item.name.lowercased()
            if !seen.insert(key).inserted { continue }
            if appearsOnHubBoard(item, keys: timedKeys) { continue }
            extras.append(item)
        }
        return extras
    }

    static func excludingBreakfastOnlyBrunchItems(
        _ items: [MenuItem],
        period: String,
        hubStations: [MenuStation]
    ) -> [MenuItem] {
        guard MealPeriodPill.canonical(period) == "Lunch" else { return items }
        let breakfast = hubStations
            .filter {
                let name = $0.name.lowercased()
                return name.contains("breakfast") && !name.contains("brunch")
            }
            .flatMap(\.items)
        let breakfastKeys = hubBoardNameKeys(from: breakfast)
        guard !breakfastKeys.isEmpty else { return items }
        let lunch = hubStations
            .filter { $0.name.lowercased().contains("lunch") }
            .flatMap(\.items)
        let lunchKeys = hubBoardNameKeys(from: lunch)
        return items.filter { item in
            appearsOnHubBoard(item, keys: lunchKeys) || !appearsOnHubBoard(item, keys: breakfastKeys)
        }
    }

    static func hubBoardNameKeys(from items: [MenuItem]) -> Set<String> {
        Set(items.flatMap { dietLookupKeys(for: $0.name) })
    }

    static func appearsOnHubBoard(_ item: MenuItem, keys: Set<String>) -> Bool {
        dietLookupKeys(for: item.name).contains { keys.contains($0) }
    }

    /// Each timed meal is its own family. All Day is ignored. Brunch is not
    /// Lunch — weekend Brunch copies Breakfast, and treating them as one
    /// family leaked eggs onto the Lunch pill.
    static func hubMealFamily(for period: String) -> String? {
        let lower = period.lowercased()
        if lower.contains("all day") { return nil }
        if MealPeriodPill.isLateNight(lower) { return "late night" }
        if MealPeriodPill.isAfternoonSnack(lower) { return "afternoon snack" }
        if lower.contains("brunch") { return "brunch" }
        if lower.contains("lunch") { return "lunch" }
        if lower.contains("breakfast") { return "breakfast" }
        if lower.contains("dinner") { return "dinner" }
        return nil
    }

    static func appearsOnOtherHubMealFamily(
        _ item: MenuItem,
        period: String,
        hubStations: [MenuStation]
    ) -> Bool {
        guard let live = hubMealFamily(for: period) else { return false }
        let other = hubStations
            .filter { station in
                guard let family = hubMealFamily(for: station.name) else { return false }
                return family != live
            }
            .flatMap(\.items)
        return appearsOnHubBoard(item, keys: hubBoardNameKeys(from: other))
    }

    /// Hub meal items whose station id belongs on this Eat hall.
    static func hubMealHasStationTags(onHall hallID: String, board: [MenuItem]) -> Bool {
        board.contains { item in
            guard let sid = item.stationID?.trimmingCharacters(in: .whitespacesAndNewlines),
                  !sid.isEmpty
            else { return false }
            return stationBelongs(onHall: hallID, stationID: sid)
        }
    }

    /// Hub dishes filed on this Anteater station (same id, or this hall's Twisted Root).
    static func hubItems(
        matching station: MenuStation,
        onHall hallID: String,
        from board: [MenuItem]
    ) -> [MenuItem] {
        board.filter { item in
            guard let sid = item.stationID?.trimmingCharacters(in: .whitespacesAndNewlines),
                  !sid.isEmpty,
                  stationBelongs(onHall: hallID, stationID: sid)
            else { return false }
            return canMergeHubExtra(into: station, extraStationID: sid)
        }
    }

    /// Anteater `restaurantToday` sometimes copies another hall's recipe, or
    /// leaves a leftover on Twisted Root after the kitchen moved on. When Hub
    /// published this meal with station tags, Twisted Root is Hub-only: keep
    /// only dishes Hub filed on that hall's station, and drop the section if
    /// Hub didn't list one. Other stations still reconcile when Hub tagged
    /// them. A generic Hub payload (no station ids) or an empty meal leaves
    /// the Anteater board untouched. Available-all-day stays Anteater.
    public static func droppingOffBoardAnteaterItems(
        onMenu menu: DiningMenu,
        hubStations: [MenuStation]
    ) -> DiningMenu {
        let board = hubBoardItems(matchingPeriod: menu.period, hubStations: hubStations)
        guard !board.isEmpty else { return menu }
        let hubTagged = hubMealHasStationTags(onHall: menu.locationId, board: board)
        let stations = menu.stations.compactMap { station -> MenuStation? in
            if CampusMenuNormalize.isAvailableAllDay(station.name) {
                return station
            }
            let hubForStation = hubItems(
                matching: station,
                onHall: menu.locationId,
                from: board
            )
            let isTwisted = isTwistedRoot(stationName: station.name, stationID: station.stationID)
            if isTwisted, hubTagged {
                let lunchPill = MealPeriodPill.canonical(menu.period) == "Lunch"
                // Weekend Lunch Hub often tags only all-day fries on TR,
                // or nothing at all. That is not the midday board — keep
                // Anteater Brunch TR (Atharv Sat Oct 3). Dinner leftovers
                // still drop when Hub tagged other stations and not TR.
                if hubForStation.isEmpty {
                    return lunchPill ? station : nil
                }
                if lunchPill {
                    let allDayKeys = hubBoardNameKeys(from: hubStations
                        .filter { $0.name.localizedCaseInsensitiveContains("all day") }
                        .flatMap(\.items))
                    let hubIsOnlyAllDayStaples = hubForStation.allSatisfy {
                        appearsOnHubBoard($0, keys: allDayKeys)
                    }
                    if hubIsOnlyAllDayStaples { return station }
                }
                let keys = hubBoardNameKeys(from: hubForStation)
                let kept = station.items.filter { appearsOnHubBoard($0, keys: keys) }
                if MealPeriodPill.canonical(menu.period) == "Breakfast" {
                    let middayKeys = middayTwistedRootKeys(hubStations: hubStations)
                    let breakfastKept = kept.filter {
                        shouldKeepTwistedRootOnBreakfast($0, middayKeys: middayKeys)
                    }
                    return breakfastKept.isEmpty ? nil : station.withItems(breakfastKept)
                }
                return kept.isEmpty ? nil : station.withItems(kept)
            }
            guard !hubForStation.isEmpty else { return station }
            let keys = hubBoardNameKeys(from: hubForStation)
            let kept = station.items.filter { appearsOnHubBoard($0, keys: keys) }
            return kept.isEmpty ? nil : station.withItems(kept)
        }
        return DiningMenu(
            locationId: menu.locationId,
            date: menu.date,
            period: menu.period,
            stations: stations
        )
    }

    /// Hub dishes on this meal that Anteater dropped — Lunch/Brunch extras
    /// that aren't All-Day grill/salad staples and aren't already on the board.
    /// Twisted Root extras that Hub filed on this meal still union even when
    /// Hub also lists them on All Day. All-Day fries/rice that Hub copies onto
    /// every meal stay off the Twisted Root section (Atharv Fri board).
    public static func hubExclusiveItems(
        onMenu menu: DiningMenu,
        hubStations: [MenuStation]
    ) -> [MenuItem] {
        let matching = excludingBreakfastOnlyBrunchItems(
            hubMealStations(matchingPeriod: menu.period, in: hubStations).flatMap(\.items),
            period: menu.period,
            hubStations: hubStations
        )
        let allDayItems = hubStations
            .filter { $0.name.localizedCaseInsensitiveContains("all day") }
            .flatMap(\.items)
        let allDayKeys = hubBoardNameKeys(from: allDayItems)
        var seen = Set(menu.stations.flatMap(\.items).flatMap { dietLookupKeys(for: $0.name) })
        var extras: [MenuItem] = []
        func consider(_ item: MenuItem) {
            let keys = dietLookupKeys(for: item.name)
            if keys.contains(where: { seen.contains($0) }) { return }
            if !stationBelongs(onHall: menu.locationId, stationID: item.stationID) { return }
            let twisted = isTwistedRoot(stationName: "", stationID: item.stationID)
            let onAllDay = appearsOnHubBoard(item, keys: allDayKeys)
            let onOtherMeal = appearsOnOtherHubMealFamily(
                item, period: menu.period, hubStations: hubStations
            )
            // Grill fries / rice Hub dumps on All Day plus every meal are not
            // tonight's Twisted Root entrees. Meal-tagged TR food (tofu) still
            // unions even when Hub also lists it on All Day.
            if onAllDay, onOtherMeal { return }
            if twisted, MealPeriodPill.canonical(menu.period) == "Breakfast" {
                let middayKeys = middayTwistedRootKeys(hubStations: hubStations)
                if !shouldKeepTwistedRootOnBreakfast(item, middayKeys: middayKeys) { return }
            }
            if !twisted, onAllDay { return }
            if !twisted, onOtherMeal { return }
            for key in keys { seen.insert(key) }
            extras.append(item)
        }
        for item in matching { consider(item) }
        return extras
    }

    /// Same station id always merges. Twisted Root extras may join a brand
    /// section whose id is still unknown — but Anteatery `1929` must never
    /// land on Brandywine `1893` just because both are named Twisted Root.
    public static func canMergeHubExtra(into station: MenuStation, extraStationID: String) -> Bool {
        let extraID = extraStationID.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !extraID.isEmpty else { return false }
        let existingID = station.stationID?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        if !existingID.isEmpty, existingID == extraID { return true }
        let stationTwisted = isTwistedRoot(stationName: station.name, stationID: station.stationID)
        let extraTwisted = isTwistedRoot(stationName: "", stationID: extraID)
        guard stationTwisted, extraTwisted else { return false }
        if existingID.isEmpty { return true }
        return existingID == extraID
    }

    public static func insertingHubExtras(
        _ extras: [MenuItem],
        into menu: DiningMenu,
        stationNames: [String: String] = [:]
    ) -> DiningMenu {
        guard !extras.isEmpty else {
            let pinned = pinTwistedRootFirst(menu.stations)
            guard pinned != menu.stations else { return menu }
            return DiningMenu(
                locationId: menu.locationId,
                date: menu.date,
                period: menu.period,
                stations: pinned
            )
        }
        var stations = menu.stations
        var leftover: [MenuItem] = []

        func merge(into index: Int, items: [MenuItem], stationID: String?) {
            let station = stations[index]
            var seen = Set(station.items.map { $0.name.lowercased() })
            var next = station.items
            let tagged = applyStationTags(
                items,
                station: station.name,
                stationID: station.stationID ?? stationID
            )
            for item in tagged where seen.insert(item.name.lowercased()).inserted {
                next.append(item)
            }
            stations[index] = station.withItems(next)
        }

        func insertBeforeAllDay(_ station: MenuStation) {
            if let idx = stations.firstIndex(where: { CampusMenuNormalize.isAvailableAllDay($0.name) }) {
                stations.insert(station, at: idx)
            } else {
                stations.append(station)
            }
        }

        for item in extras {
            let sid = item.stationID?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
            if sid.isEmpty {
                leftover.append(item)
                continue
            }
            if !stationBelongs(onHall: menu.locationId, stationID: sid) {
                continue
            }
            if let idx = stations.firstIndex(where: {
                canMergeHubExtra(into: $0, extraStationID: sid)
            }) {
                merge(into: idx, items: [item], stationID: sid)
                continue
            }
            let name = displayStationName(stationNames[sid], stationID: sid)
            if let idx = stations.firstIndex(where: {
                $0.name.caseInsensitiveCompare(name) == .orderedSame
                    && canMergeHubExtra(into: $0, extraStationID: sid)
            }) {
                merge(into: idx, items: [item], stationID: sid)
                continue
            }
            insertBeforeAllDay(MenuStation(
                name: name,
                items: applyStationTags([item], station: name, stationID: sid),
                stationID: sid
            ))
        }

        if !leftover.isEmpty {
            insertBeforeAllDay(MenuStation(name: "Also served", items: leftover))
        }

        stations = pinTwistedRootFirst(stations)

        return DiningMenu(
            locationId: menu.locationId,
            date: menu.date,
            period: menu.period,
            stations: stations
        )
    }

    /// Full menu for a hall + meal period, grouped by station with nutrition/diet flags.
    /// All Day stations fold into the bottom as "Available all day".
    /// Unpublished days (API 404) return an empty menu — never throw.
    public func menu(
        for hall: String,
        period: String,
        date: String? = nil,
        forceRefresh: Bool = false
    ) async throws -> DiningMenu {
        let dateISO = date ?? PacificTime.todayISO(now: now())
        if HallDirectory.isOasis(hall) {
            let listed = ((try? await restaurants()) ?? []).contains {
                HallDirectory.isOasis($0.id)
            }
            if !listed {
                if let hubMenu = await oasisHubMenu(
                    period: period,
                    dateISO: dateISO,
                    forceRefresh: forceRefresh
                ) {
                    return await applyingOverrides(hubMenu, forceRefresh: forceRefresh)
                }
                return await applyingOverrides(
                    DiningMenu(locationId: hall, date: dateISO, period: period, stations: []),
                    forceRefresh: forceRefresh
                )
            }
        }
        let today = try await today(for: hall, dateISO: dateISO, forceRefresh: forceRefresh)
        let available = (today.periods ?? [:]).values.map(\.name)

        // No periods published for this day yet (404 mapped to empty, or blank payload).
        guard !available.isEmpty else {
            return await applyingOverrides(
                DiningMenu(locationId: hall, date: dateISO, period: period, stations: []),
                forceRefresh: forceRefresh
            )
        }

        let resolved = Self.resolvePeriod(period, available: available)
        let periodNames = Self.menuPeriodNames(primary: period, available: available)
        // Unposted Lunch (weekend Brunch-only board) must stay empty — do
        // not invent dishes or copy the Brunch already shown on Breakfast.
        // Dated overrides may still insert a verified dish onto that pill.
        guard !periodNames.isEmpty else {
            return await applyingOverrides(
                DiningMenu(locationId: hall, date: dateISO, period: period, stations: []),
                forceRefresh: forceRefresh
            )
        }
        let stationNames = try await stationMap()

        var mealStations: [MenuStation] = []
        var scraped: [String: [MenuStation]] = [:]
        for name in periodNames {
            let more = try await stations(
                for: name, in: today, stationNames: stationNames
            )
            scraped[name] = more
            mealStations = Self.mergeStations(mealStations, more)
        }
        if MealPeriodPill.canonical(period) == "Lunch",
           let breakfastName = available.first(where: {
               $0.caseInsensitiveCompare("Breakfast") == .orderedSame
           }) {
            let breakfastStations = try await stations(
                for: breakfastName, in: today, stationNames: stationNames
            )
            let lunchStations = scraped.first { key, _ in
                key.caseInsensitiveCompare("Lunch") == .orderedSame
            }?.value ?? []
            mealStations = Self.subtractingBreakfastOnlyBrunchDishes(
                from: mealStations,
                lunch: lunchStations,
                breakfast: breakfastStations
            )
        }
        if MealPeriodPill.canonical(period) == "Breakfast",
           scraped.contains(where: {
               $0.key.caseInsensitiveCompare("Breakfast") == .orderedSame
           }),
           let brunchName = available.first(where: {
               $0.caseInsensitiveCompare("Brunch") == .orderedSame
           }) {
            // Only when Breakfast and Brunch both exist. A Breakfast pill
            // that fell through to Brunch-only keeps the full midday board.
            let brunchStations: [MenuStation]
            if let cached = scraped.first(where: {
                $0.key.caseInsensitiveCompare("Brunch") == .orderedSame
            })?.value {
                brunchStations = cached
            } else {
                brunchStations = try await stations(
                    for: brunchName, in: today, stationNames: stationNames
                )
            }
            mealStations = Self.subtractingMiddayTwistedRootFromBreakfast(
                from: mealStations,
                midday: brunchStations
            )
        }

        let periodMatched = periodNames.contains { name in
            available.contains { $0.caseInsensitiveCompare(name) == .orderedSame }
        }
        // Weekend Brunch is timed and equals Breakfast ∪ All Day. Folding
        // All Day onto Breakfast makes the Breakfast pill match Brunch/Lunch.
        let brunchIsTimed = (today.periods ?? [:]).values.contains { period in
            period.name.localizedCaseInsensitiveContains("brunch")
                && PacificTime.parseMinutes(period.startTime) != nil
                && PacificTime.parseMinutes(period.endTime) != nil
        }
        let skipAllDayOnBreakfast = brunchIsTimed
            && MealPeriodPill.canonical(period) == "Breakfast"
        if periodMatched,
           !skipAllDayOnBreakfast,
           !resolved.localizedCaseInsensitiveContains("all day"),
           available.contains(where: { $0.localizedCaseInsensitiveContains("all day") }) {
            let allDayName = available.first { $0.localizedCaseInsensitiveContains("all day") }!
            let allDayStations = try await stations(
                for: allDayName, in: today, stationNames: stationNames
            )
            if !allDayStations.isEmpty {
                let items = allDayStations.flatMap(\.items)
                var seen = Set<String>()
                let unique = items.filter { seen.insert($0.name.lowercased()).inserted }
                if !unique.isEmpty {
                    mealStations.append(MenuStation(name: "Available all day", items: unique))
                }
            }
        }

        let built = DiningMenu(
            locationId: hall,
            date: dateISO,
            period: resolved,
            stations: Self.pinTwistedRootFirst(mealStations)
        )
        // Anteater API often leaves every is* flag false; the dining hub carries
        // much richer recipe_attributes. Merge by dish name (soft-fail).
        let enriched = await enrichDietTags(built, stationNames: stationNames, forceRefresh: forceRefresh)
        let periodMatch = (today.periods ?? [:]).values.first {
            $0.name.caseInsensitiveCompare(resolved) == .orderedSame
        }
        return await applyingOverrides(
            enriched,
            forceRefresh: forceRefresh,
            periodStartMinutes: PacificTime.parseMinutes(periodMatch?.startTime),
            periodEndMinutes: PacificTime.parseMinutes(periodMatch?.endTime)
        )
    }

    /// Official Hub SKUs when Anteater still omits Oasis. Empty Hub / typical
    /// packs resolve to nil so Eat never invents a board.
    private func oasisHubMenu(
        period: String,
        dateISO: String,
        forceRefresh: Bool
    ) async -> DiningMenu? {
        let hub = CampusService(http: http, cache: cache, now: now)
        let urlKey = HallDirectory.campusHubKey(for: HallDirectory.oasisComingSoonID)
            ?? "the-oasis-dining-hall"
        let stations = (try? await hub.menu(
            for: urlKey,
            placeName: HallDirectory.displayName(for: HallDirectory.oasisComingSoonID),
            date: dateISO,
            forceRefresh: forceRefresh,
            allowTypicalFallback: false
        )) ?? []
        guard !stations.isEmpty else { return nil }
        let available = stations.map(\.name)
        let resolved = Self.resolvePeriod(period, available: available)
        let names = Self.menuPeriodNames(primary: period, available: available)
        let matched = names.compactMap { name in
            stations.first { $0.name.caseInsensitiveCompare(name) == .orderedSame }
        }
        // Empty names means this pill is not posted — do not dump every Hub
        // station onto Lunch when the only morning board is Brunch.
        guard !names.isEmpty else {
            return DiningMenu(
                locationId: HallDirectory.oasisComingSoonID,
                date: dateISO,
                period: period,
                stations: []
            )
        }
        let board = matched.isEmpty ? stations : Self.mergeStationLists([matched])
        return DiningMenu(
            locationId: HallDirectory.oasisComingSoonID,
            date: dateISO,
            period: resolved,
            stations: Self.pinTwistedRootFirst(board)
        )
    }

    /// Dated verified inserts / corrections from GitHub `menu-overrides.json`,
    /// plus Anteater `/events` takeover labels. Bundled fallback covers this
    /// build if `main` lags. Empty event stations drop after dishes land.
    private func applyingOverrides(
        _ menu: DiningMenu,
        forceRefresh: Bool,
        periodStartMinutes: Int? = nil,
        periodEndMinutes: Int? = nil
    ) async -> DiningMenu {
        if forceRefresh {
            await cache.invalidate("menu-overrides")
            await cache.invalidate("dining:events")
        }
        async let feedTask: MenuOverrideFeed.Feed = cache.remember("menu-overrides", ttl: Self.todayTTL) {
            await MenuOverrideFeed.fetch(http: self.http)
        }
        async let eventsTask: [DiningEvent] = diningEvents(forceRefresh: forceRefresh)
        let feed = await feedTask
        let events = await eventsTask
        let withEvents = Self.attachingEvents(
            events,
            to: menu,
            periodStartMinutes: periodStartMinutes,
            periodEndMinutes: periodEndMinutes
        )
        let applied = MenuOverrideFeed.applying(feed, to: withEvents)
        return Self.droppingEmptyStations(applied)
    }

    private func diningEvents(forceRefresh: Bool) async -> [DiningEvent] {
        if forceRefresh {
            await cache.invalidate("dining:events")
        }
        return await cache.remember("dining:events", ttl: Self.todayTTL) {
            do {
                let raw = try await getData([APIEvent].self, path: "/events")
                return raw.compactMap { row in
                    let title = row.title?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
                    let hall = row.restaurantId?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
                    guard !title.isEmpty, !hall.isEmpty else { return nil }
                    return DiningEvent(
                        title: title,
                        restaurantId: hall,
                        start: Self.parseEventDate(row.start),
                        end: Self.parseEventDate(row.end)
                    )
                }
            } catch {
                return []
            }
        }
    }

    /// Overlay dining-hub dietary tags / allergens onto Anteater menu items.
    private func enrichDietTags(
        _ menu: DiningMenu,
        stationNames: [String: String] = [:],
        forceRefresh: Bool = false
    ) async -> DiningMenu {
        guard let hubKey = HallDirectory.campusHubKey(for: menu.locationId) else { return menu }
        let hubStations: [MenuStation]
        do {
            hubStations = try await CampusService(http: http, cache: cache, now: now)
                .menu(
                    for: hubKey,
                    date: menu.date,
                    forceRefresh: forceRefresh,
                    allowTypicalFallback: false
                )
        } catch {
            return menu
        }
        guard !hubStations.isEmpty else { return menu }

        var tagsByKey: [String: [String]] = [:]
        var allergensByKey: [String: [String]] = [:]
        for item in hubStations.flatMap(\.items) {
            for key in Self.dietLookupKeys(for: item.name) {
                if !item.dietaryTags.isEmpty {
                    tagsByKey[key] = Self.mergeUnique(tagsByKey[key] ?? [], item.dietaryTags)
                }
                if !item.allergens.isEmpty {
                    allergensByKey[key] = Self.mergeUnique(allergensByKey[key] ?? [], item.allergens)
                }
            }
        }
        var tagged = menu
        if !tagsByKey.isEmpty || !allergensByKey.isEmpty {
            let stations = menu.stations.map { station in
                station.withItems(
                    station.items.map { item in
                        let hubTags = Self.dietLookupKeys(for: item.name)
                            .compactMap { tagsByKey[$0] }.first ?? []
                        let hubAllergens = Self.dietLookupKeys(for: item.name)
                            .compactMap { allergensByKey[$0] }.first ?? []
                        let tags = Self.mergeUnique(item.dietaryTags, hubTags)
                        let allergens = Self.mergeUnique(item.allergens, hubAllergens)
                        guard tags != item.dietaryTags || allergens != item.allergens else { return item }
                        return MenuItem(
                            id: item.id,
                            name: item.name,
                            description: item.description,
                            calories: item.calories,
                            servingSize: item.servingSize,
                            allergens: allergens,
                            dietaryTags: tags,
                            nutrition: item.nutrition,
                            stationID: item.stationID
                        )
                    }
                )
            }
            tagged = DiningMenu(
                locationId: menu.locationId,
                date: menu.date,
                period: menu.period,
                stations: stations
            )
        }

        let onBoard = Self.droppingOffBoardAnteaterItems(onMenu: tagged, hubStations: hubStations)
        let extras = Self.hubExclusiveItems(onMenu: onBoard, hubStations: hubStations)
        let combined = Self.insertingHubExtras(extras, into: onBoard, stationNames: stationNames)
        let reconciled: DiningMenu
        if MealPeriodPill.canonical(combined.period) == "Breakfast" {
            let midday = Self.hubMealStations(matchingPeriod: "Lunch", in: hubStations)
            let trimmed = Self.subtractingMiddayTwistedRootFromBreakfast(
                from: combined.stations,
                midday: midday
            )
            if trimmed != combined.stations {
                reconciled = DiningMenu(
                    locationId: combined.locationId,
                    date: combined.date,
                    period: combined.period,
                    stations: Self.pinTwistedRootFirst(trimmed)
                )
            } else {
                reconciled = combined
            }
        } else {
            reconciled = combined
        }
        return reconciled
    }

    /// Match Anteater names to hub names ("Vegan Mac & Cheese UCI" ↔ "Vegan Mac & Cheese").
    static func dietLookupKeys(for name: String) -> [String] {
        let lower = (collapseWhitespace(name) ?? name)
            .lowercased()
            .trimmingCharacters(in: .whitespacesAndNewlines)
        var keys = [lower]

        var stripped = lower
        // Anteater sometimes prefixes "AE "; hub omits it.
        if stripped.hasPrefix("ae ") {
            stripped = String(stripped.dropFirst(3)).trimmingCharacters(in: .whitespaces)
            keys.append(stripped)
        }
        for suffix in [" sandwich", " burger", " wrap"] {
            if stripped.hasSuffix(suffix) {
                let base = String(stripped.dropLast(suffix.count)).trimmingCharacters(in: .whitespaces)
                if !base.isEmpty { keys.append(base) }
            }
        }

        let withoutUCI = stripped.replacingOccurrences(
            of: #"\s+uci$"#, with: "", options: .regularExpression
        )
        if withoutUCI != stripped { keys.append(withoutUCI) }

        for variant in keys {
            let normalized = variant.replacingOccurrences(
                of: #"[^a-z0-9]+"#, with: "", options: .regularExpression
            )
            if !normalized.isEmpty { keys.append(normalized) }
        }
        // Preserve order, drop dupes.
        var seen = Set<String>()
        return keys.filter { seen.insert($0).inserted }
    }

    private static func mergeUnique(_ base: [String], _ extra: [String]) -> [String] {
        var seen = Set(base.map { $0.lowercased() })
        var result = base
        for tag in extra where seen.insert(tag.lowercased()).inserted {
            result.append(tag)
        }
        // Vegan ⇒ Vegetarian for filter matching.
        if result.contains(where: { $0.caseInsensitiveCompare("Vegan") == .orderedSame }),
           !result.contains(where: { $0.caseInsensitiveCompare("Vegetarian") == .orderedSame }) {
            result.append("Vegetarian")
        }
        return result
    }

    private func stations(
        for period: String,
        in today: APIRestaurantToday,
        stationNames: [String: String]
    ) async throws -> [MenuStation] {
        guard let match = (today.periods ?? [:]).values
            .first(where: { $0.name.lowercased() == period.lowercased() })
        else { return [] }

        let stationToDishes = match.stationToDishes ?? [:]
        let allIDs = stationToDishes.values.flatMap(\.self)
        let dishMap = try await dishes(ids: allIDs)

        var stations: [MenuStation] = []
        for (stationID, dishIDs) in stationToDishes.sorted(by: { $0.key < $1.key }) {
            var seenNames = Set<String>()
            let stationName = Self.displayStationName(stationNames[stationID], stationID: stationID)
            let items = dishIDs
                .compactMap { dishMap[$0] }
                .map(Self.menuItem(from:))
                .filter { seenNames.insert($0.name.lowercased()).inserted }
            if !items.isEmpty {
                stations.append(MenuStation(
                    name: stationName,
                    items: Self.applyStationTags(items, station: stationName, stationID: stationID),
                    stationID: stationID
                ))
            }
        }
        return stations
    }
}

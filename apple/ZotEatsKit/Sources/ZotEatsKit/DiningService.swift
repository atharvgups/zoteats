import Foundation

// UCI dining data from the Anteater API (anteaterapi.com) — the maintained, public
// UCI data API used by ICSSC's PeterPlate. Port of main/services/dining.ts.
// Endpoints (base /v2/rest/dining):
//   GET /restaurants                 -> restaurants with their stations (id + name)
//   GET /restaurantToday?id=&date=   -> periods -> stationToDishes (station id -> dish ids)
//   GET /dishes/batch?ids=a,b,c      -> full dish objects (nutrition + diet/allergen flags)
// Responses use the standard { ok, data } envelope. No API key required (rate-limited).

public struct DiningService: Sendable {
    private let base = "https://anteaterapi.com/v2/rest/dining"
    private let http: any HTTPFetching
    private let cache: TTLCache
    private let now: @Sendable () -> Date

    private static let stationsTTL: TimeInterval = 24 * 60 * 60
    private static let todayTTL: TimeInterval = 20 * 60
    private static let dishesTTL: TimeInterval = 30 * 60

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

        // The API sometimes returns calories as a string; accept both.
        init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            servingSize = try container.decodeIfPresent(String.self, forKey: .servingSize)
            servingUnit = try container.decodeIfPresent(String.self, forKey: .servingUnit)
            if let number = try? container.decodeIfPresent(Double.self, forKey: .calories) {
                calories = number
            } else if let text = try? container.decodeIfPresent(String.self, forKey: .calories) {
                calories = Double(text)
            } else {
                calories = nil
            }
        }

        private enum CodingKeys: String, CodingKey {
            case servingSize, servingUnit, calories
        }
    }

    private struct APIDish: Decodable, Sendable {
        let id: String
        let stationId: String
        let name: String
        let description: String?
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

    private func today(for hall: String, dateISO: String) async throws -> APIRestaurantToday {
        try await cache.remember("dining:today:\(hall):\(dateISO)", ttl: Self.todayTTL) {
            try await getData(APIRestaurantToday.self, path: "/restaurantToday?id=\(hall)&date=\(dateISO)")
        }
    }

    private func dishes(ids: [String]) async throws -> [String: APIDish] {
        let unique = Array(Set(ids)).sorted()
        guard !unique.isEmpty else { return [:] }
        let joined = unique.joined(separator: ",")
        let encoded = joined.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? joined
        return try await cache.remember("dining:dishes:\(joined)", ttl: Self.dishesTTL) {
            let dishes = try await getData([APIDish].self, path: "/dishes/batch?ids=\(encoded)")
            return Dictionary(dishes.map { ($0.id, $0) }, uniquingKeysWith: { first, _ in first })
        }
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
            if let unit = dish.nutritionInfo?.servingUnit { return "\(size) \(unit)" }
            return size
        }
        let description = dish.description?.trimmingCharacters(in: .whitespacesAndNewlines)
        return MenuItem(
            id: dish.id,
            name: dish.name,
            description: (description?.isEmpty ?? true) ? nil : description,
            calories: dish.nutritionInfo?.calories.map { Int($0.rounded()) },
            servingSize: serving,
            allergens: dish.dietRestriction?.allergens ?? [],
            dietaryTags: dish.dietRestriction?.dietaryTags ?? []
        )
    }

    /// The Twisted Root is UCI's dedicated plant-based station at **both**
    /// The Anteatery and Brandywine. The feed often ships every diet flag as
    /// false — trust the station so Vegan / Vegetarian filters never hide it.
    public static let twistedRootStationIDs: Set<String> = [
        "1929", // The Anteatery
        "1893", // Brandywine
    ]

    public static func isTwistedRoot(stationName: String, stationID: String? = nil) -> Bool {
        if let stationID, twistedRootStationIDs.contains(stationID) { return true }
        let lowered = stationName.lowercased()
            .replacingOccurrences(of: #"\s+"#, with: " ", options: .regularExpression)
            .trimmingCharacters(in: .whitespacesAndNewlines)
        return lowered.contains("twisted root") || lowered.contains("twistedroot")
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
                dietaryTags: tags
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
                MenuStation(
                    name: station.name,
                    items: applyStationTags(station.items, station: station.name)
                )
            }
        )
    }

    // MARK: - Public API

    /// Every dining commons the live API lists (a new hall shows up here
    /// automatically) with today's hours, open state, and served meal periods.
    public func locations() async -> [DiningLocation] {
        let dateISO = PacificTime.todayISO(now: now())
        let nowMinutes = PacificTime.nowMinutes(now: now())

        // Live hall list first; the maintained fallback keeps the UI alive offline.
        let hallIDs = (try? await restaurants().map(\.id)) ?? HallDirectory.fallbackIDs

        var results: [DiningLocation] = []
        await withTaskGroup(of: DiningLocation.self) { group in
            for hall in hallIDs {
                group.addTask {
                    await location(for: hall, dateISO: dateISO, nowMinutes: nowMinutes)
                }
            }
            for await location in group {
                results.append(location)
            }
        }
        // TaskGroup completion order is nondeterministic; present halls in a stable order.
        return hallIDs.compactMap { id in results.first { $0.id == id } }
    }

    private func location(for hall: String, dateISO: String, nowMinutes: Int) async -> DiningLocation {
        do {
            let periods = Self.servedPeriods(try await today(for: hall, dateISO: dateISO))
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
                hoursApproximate: false
            )
        } catch {
            return DiningLocation(
                id: hall,
                name: HallDirectory.displayName(for: hall),
                area: HallDirectory.area(for: hall),
                openNow: false,
                todayHours: nil,
                availablePeriods: [],
                periods: [],
                hoursApproximate: false
            )
        }
    }

    /// Primary meal pills students actually use. Brunch maps into Breakfast;
    /// All Day is folded into each meal as "Available all day" (no own pill).
    public static func primaryPeriods(from available: [String]) -> [String] {
        var result: [String] = []
        if available.contains(where: { $0.caseInsensitiveCompare("Breakfast") == .orderedSame })
            || available.contains(where: { $0.caseInsensitiveCompare("Brunch") == .orderedSame }) {
            result.append("Breakfast")
        }
        if available.contains(where: { $0.caseInsensitiveCompare("Lunch") == .orderedSame }) {
            result.append("Lunch")
        }
        if available.contains(where: {
            $0.caseInsensitiveCompare("Dinner") == .orderedSame
                || $0.caseInsensitiveCompare("Limited Dinner") == .orderedSame
        }) {
            result.append("Dinner")
        }
        return result
    }

    /// Resolve a primary pill to the real API period name for a hall.
    public static func resolvePeriod(_ primary: String, available: [String]) -> String {
        let match: (String) -> String? = { name in
            available.first { $0.caseInsensitiveCompare(name) == .orderedSame }
        }
        switch primary.lowercased() {
        case "breakfast":
            return match("Breakfast") ?? match("Brunch") ?? primary
        case "dinner":
            return match("Dinner") ?? match("Limited Dinner") ?? primary
        default:
            return match(primary) ?? primary
        }
    }

    /// Full menu for a hall + meal period, grouped by station with nutrition/diet flags.
    /// All Day stations fold into the bottom as "Available all day".
    public func menu(for hall: String, period: String, date: String? = nil) async throws -> DiningMenu {
        let dateISO = date ?? PacificTime.todayISO(now: now())
        let today = try await today(for: hall, dateISO: dateISO)
        let available = (today.periods ?? [:]).values.map(\.name)
        let resolved = Self.resolvePeriod(period, available: available)
        let stationNames = try await stationMap()

        var mealStations = try await stations(
            for: resolved, in: today, stationNames: stationNames
        )

        let periodMatched = available.contains {
            $0.caseInsensitiveCompare(resolved) == .orderedSame
        }
        if periodMatched,
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

        return DiningMenu(locationId: hall, date: dateISO, period: resolved, stations: mealStations)
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
            let stationName = stationNames[stationID] ?? "Menu"
            let items = dishIDs
                .compactMap { dishMap[$0] }
                .map(Self.menuItem(from:))
                .filter { seenNames.insert($0.name.lowercased()).inserted }
            if !items.isEmpty {
                stations.append(MenuStation(
                    name: stationName,
                    items: Self.applyStationTags(items, station: stationName, stationID: stationID)
                ))
            }
        }
        return stations
    }
}

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
    private let dayCache: DayCache
    private let now: @Sendable () -> Date

    private static let stationsTTL: TimeInterval = 24 * 60 * 60
    private static let todayTTL: TimeInterval = 20 * 60
    private static let dishesTTL: TimeInterval = 30 * 60

    public init(
        http: any HTTPFetching = HTTPClient(),
        cache: TTLCache = TTLCache(),
        dayCache: DayCache = .shared,
        now: @escaping @Sendable () -> Date = { Date() }
    ) {
        self.http = http
        self.cache = cache
        self.dayCache = dayCache
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
            [
                (isVegan, "Vegan"),
                (isVegetarian, "Vegetarian"),
                (isHalal, "Halal"),
                (isKosher, "Kosher"),
                (isGlutenFree, "Gluten-Free"),
                (isOrganic, "Organic"),
                (isLocallyGrown, "Locally Grown"),
            ].filter { $0.0 == true }.map(\.1)
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

    /// Every dining payload is stable for the day (menus, dish details, hours),
    /// so responses go through the day cache: pull once, reuse until midnight —
    /// across launches. `fresh` (explicit user refresh) forces the network.
    private func getData<T: Decodable & Sendable>(_ type: T.Type, path: String, fresh: Bool = false) async throws -> T {
        guard let url = URL(string: base + path) else {
            throw URLError(.badURL)
        }
        let day = PacificTime.todayISO(now: now())

        if !fresh,
           let cached = await dayCache.data(for: "dining:\(path)", day: day),
           let decoded = try? Self.decodeEnvelope(type, from: cached, url: url) {
            return decoded
        }

        let raw = try await http.data(from: url)
        let decoded = try Self.decodeEnvelope(type, from: raw, url: url)
        // Persist only responses that decoded cleanly.
        await dayCache.store(raw, key: "dining:\(path)", day: day)
        return decoded
    }

    private static func decodeEnvelope<T: Decodable & Sendable>(_ type: T.Type, from data: Data, url: URL) throws -> T {
        let envelope: Envelope<T>
        do {
            envelope = try JSONDecoder().decode(Envelope<T>.self, from: data)
        } catch {
            throw HTTPError.decoding(underlying: error, url: url)
        }
        if envelope.ok == false {
            throw HTTPError.badStatus(code: 502, url: url)
        }
        guard let payload = envelope.data else {
            throw HTTPError.decoding(underlying: URLError(.cannotParseResponse), url: url)
        }
        return payload
    }

    /// The live commons list — the source of truth for which halls exist,
    /// so a newly opened hall appears in the app without a code change.
    private func restaurants(fresh: Bool = false) async throws -> [APIRestaurant] {
        try await cache.remember("dining:restaurants", ttl: Self.stationsTTL, fresh: fresh) {
            try await getData([APIRestaurant].self, path: "/restaurants", fresh: fresh)
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

    private func today(for hall: String, dateISO: String, fresh: Bool = false) async throws -> APIRestaurantToday {
        try await cache.remember("dining:today:\(hall):\(dateISO)", ttl: Self.todayTTL, fresh: fresh) {
            try await getData(APIRestaurantToday.self, path: "/restaurantToday?id=\(hall)&date=\(dateISO)", fresh: fresh)
        }
    }

    private func dishes(ids: [String], fresh: Bool = false) async throws -> [String: APIDish] {
        let unique = Array(Set(ids)).sorted()
        guard !unique.isEmpty else { return [:] }
        let joined = unique.joined(separator: ",")
        let encoded = joined.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? joined
        return try await cache.remember("dining:dishes:\(joined)", ttl: Self.dishesTTL, fresh: fresh) {
            let dishes = try await getData([APIDish].self, path: "/dishes/batch?ids=\(encoded)", fresh: fresh)
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

    // MARK: - Public API

    /// Every dining commons the live API lists (a new hall shows up here
    /// automatically) with today's hours, open state, and served meal periods.
    /// `fresh` (pull-to-refresh) bypasses both cache layers.
    public func locations(fresh: Bool = false) async -> [DiningLocation] {
        let dateISO = PacificTime.todayISO(now: now())
        let nowMinutes = PacificTime.nowMinutes(now: now())

        // Live hall list first; the maintained fallback keeps the UI alive offline.
        let hallIDs = (try? await restaurants(fresh: fresh).map(\.id)) ?? HallDirectory.fallbackIDs

        var results: [DiningLocation] = []
        await withTaskGroup(of: DiningLocation.self) { group in
            for hall in hallIDs {
                group.addTask {
                    await location(for: hall, dateISO: dateISO, nowMinutes: nowMinutes, fresh: fresh)
                }
            }
            for await location in group {
                results.append(location)
            }
        }
        // TaskGroup completion order is nondeterministic; present halls in a stable order.
        return hallIDs.compactMap { id in results.first { $0.id == id } }
    }

    private func location(for hall: String, dateISO: String, nowMinutes: Int, fresh: Bool = false) async -> DiningLocation {
        do {
            let periods = Self.servedPeriods(try await today(for: hall, dateISO: dateISO, fresh: fresh))
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

    /// Full menu for a hall + meal period, grouped by station with nutrition/diet flags.
    /// `fresh` (pull-to-refresh) bypasses both cache layers.
    public func menu(for hall: String, period: String, date: String? = nil, fresh: Bool = false) async throws -> DiningMenu {
        let dateISO = date ?? PacificTime.todayISO(now: now())
        let today: APIRestaurantToday
        do {
            today = try await self.today(for: hall, dateISO: dateISO, fresh: fresh)
        } catch HTTPError.badStatus(404, _) {
            // The API 404s for days whose menu isn't published yet (common when
            // browsing ahead to a weekend). That's "not posted", not an error.
            return DiningMenu(locationId: hall, date: dateISO, period: period, stations: [])
        }

        guard let match = (today.periods ?? [:]).values
            .first(where: { $0.name.lowercased() == period.lowercased() })
        else {
            return DiningMenu(locationId: hall, date: dateISO, period: period, stations: [])
        }

        let stationToDishes = match.stationToDishes ?? [:]
        let allIDs = stationToDishes.values.flatMap(\.self)
        async let dishMapTask = dishes(ids: allIDs, fresh: fresh)
        async let stationMapTask = stationMap()
        let (dishMap, stationNames) = try await (dishMapTask, stationMapTask)

        var stations: [MenuStation] = []
        for (stationID, dishIDs) in stationToDishes.sorted(by: { $0.key < $1.key }) {
            // The API occasionally lists multiple dish ids that resolve to the same
            // dish name within one station; keep the first of each.
            var seenNames = Set<String>()
            let items = dishIDs
                .compactMap { dishMap[$0] }
                .map(Self.menuItem(from:))
                .filter { seenNames.insert($0.name.lowercased()).inserted }
            if !items.isEmpty {
                stations.append(MenuStation(name: stationNames[stationID] ?? "Menu", items: items))
            }
        }

        return DiningMenu(locationId: hall, date: dateISO, period: period, stations: stations)
    }
}

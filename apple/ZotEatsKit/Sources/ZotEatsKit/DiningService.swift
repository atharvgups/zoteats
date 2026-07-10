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

    private func stationMap() async throws -> [String: String] {
        try await cache.remember("dining:stations", ttl: Self.stationsTTL) {
            let restaurants = try await getData([APIRestaurant].self, path: "/restaurants")
            var map: [String: String] = [:]
            for restaurant in restaurants {
                for station in restaurant.stations ?? [] {
                    map[station.id] = station.name
                }
            }
            return map
        }
    }

    private func today(for hall: DiningLocationID, dateISO: String) async throws -> APIRestaurantToday {
        try await cache.remember("dining:today:\(hall.rawValue):\(dateISO)", ttl: Self.todayTTL) {
            try await getData(APIRestaurantToday.self, path: "/restaurantToday?id=\(hall.rawValue)&date=\(dateISO)")
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

    /// Served periods in chronological order (the API returns an unordered dictionary).
    private static func servedPeriods(_ today: APIRestaurantToday) -> [APIPeriod] {
        (today.periods ?? [:]).values
            .filter { !($0.stationToDishes ?? [:]).isEmpty }
            .sorted { lhs, rhs in
                let l = PacificTime.parseMinutes(lhs.startTime) ?? Int.max
                let r = PacificTime.parseMinutes(rhs.startTime) ?? Int.max
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

    /// Both dining commons with today's hours, open state, and served meal periods.
    public func locations() async -> [DiningLocation] {
        let dateISO = PacificTime.todayISO(now: now())
        let nowMinutes = PacificTime.nowMinutes(now: now())

        var results: [DiningLocation] = []
        await withTaskGroup(of: DiningLocation.self) { group in
            for hall in DiningLocationID.allCases {
                group.addTask {
                    await location(for: hall, dateISO: dateISO, nowMinutes: nowMinutes)
                }
            }
            for await location in group {
                results.append(location)
            }
        }
        // TaskGroup completion order is nondeterministic; present halls in a stable order.
        return DiningLocationID.allCases.compactMap { id in results.first { $0.id == id } }
    }

    private func location(for hall: DiningLocationID, dateISO: String, nowMinutes: Int) async -> DiningLocation {
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
                name: hall.displayName,
                area: hall.area,
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
                name: hall.displayName,
                area: hall.area,
                openNow: false,
                todayHours: nil,
                availablePeriods: [],
                periods: [],
                hoursApproximate: false
            )
        }
    }

    /// Full menu for a hall + meal period, grouped by station with nutrition/diet flags.
    public func menu(for hall: DiningLocationID, period: String, date: String? = nil) async throws -> DiningMenu {
        let dateISO = date ?? PacificTime.todayISO(now: now())
        let today = try await today(for: hall, dateISO: dateISO)

        guard let match = (today.periods ?? [:]).values
            .first(where: { $0.name.lowercased() == period.lowercased() })
        else {
            return DiningMenu(locationId: hall, date: dateISO, period: period, stations: [])
        }

        let stationToDishes = match.stationToDishes ?? [:]
        let allIDs = stationToDishes.values.flatMap(\.self)
        async let dishMapTask = dishes(ids: allIDs)
        async let stationMapTask = stationMap()
        let (dishMap, stationNames) = try await (dishMapTask, stationMapTask)

        var stations: [MenuStation] = []
        for (stationID, dishIDs) in stationToDishes.sorted(by: { $0.key < $1.key }) {
            let items = dishIDs.compactMap { dishMap[$0] }.map(Self.menuItem(from:))
            if !items.isEmpty {
                stations.append(MenuStation(name: stationNames[stationID] ?? "Menu", items: items))
            }
        }

        return DiningMenu(locationId: hall, date: dateISO, period: period, stations: stations)
    }
}

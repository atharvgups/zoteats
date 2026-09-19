import Foundation

// UCI dining menus. Two public sources, merged so a station that exists in
// either one is not silently dropped:
//
// 1. Dining hub GraphQL (`getLocationRecipes`) — the same Elevate mesh the
//    Campus tab uses. WEEKLY `dateSkuMap` is the station→SKU assignment; the
//    bundled `products.items` list is incomplete, which is why Anteater API's
//    scraper (and previously this client) dropped whole stations such as
//    Noodle Bar when the SKU was missing from that bundle.
// 2. Anteater API (`restaurantToday` + `dishes/batch`) — nutrition/diet flags
//    and a fallback when the hub is down.
//
// Dish details are resolved from dishes/batch (chunked), then hub products,
// then a name-only Commerce_products lookup. Empty days stay empty — we never
// invent items. A last-good snapshot is served (marked stale) when both
// sources fail after retry.

public struct DiningService: Sendable {
    private let base = "https://anteaterapi.com/v2/rest/dining"
    private let http: any HTTPFetching
    private let cache: TTLCache
    private let now: @Sendable () -> Date

    private static let stationsTTL: TimeInterval = 24 * 60 * 60
    private static let todayTTL: TimeInterval = 20 * 60
    private static let dishesTTL: TimeInterval = 30 * 60
    private static let lastGoodTTL: TimeInterval = 24 * 60 * 60
    private static let dishBatchSize = 40

    public init(
        http: any HTTPFetching = HTTPClient(),
        cache: TTLCache = TTLCache(),
        now: @escaping @Sendable () -> Date = { Date() }
    ) {
        self.http = http
        self.cache = cache
        self.now = now
    }

    // MARK: - Anteater API wire types

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

    // MARK: - Hub wire types

    private struct HubLocationsData: Decodable, Sendable {
        let getLocations: [HubLocation]?
    }

    private struct HubLocation: Decodable, Sendable {
        let commerceAttributes: HubCommerce?
        let aemAttributes: HubAEM?
    }

    private struct HubCommerce: Decodable, Sendable {
        let url_key: String?
        let hasActiveMenus: Bool?
        let children: [HubStation]?
    }

    private struct HubAEM: Decodable, Sendable {
        let name: String?
        let hoursOfOperation: HubHours?
    }

    private struct HubHours: Decodable, Sendable {
        let schedule: [CampusService.RawSchedule]?
    }

    private struct HubStation: Decodable, Sendable {
        let id: Int?
        let name: String?
        let position: Int?
    }

    private struct HubMealPeriodsData: Decodable, Sendable {
        let Commerce_mealPeriods: [HubMealPeriod]?
    }

    private struct HubMealPeriod: Decodable, Sendable {
        let name: String
        let id: Int
        let position: Int?
    }

    private struct HubRecipesData: Decodable, Sendable {
        let getLocationRecipes: HubRecipes?
    }

    private struct HubRecipes: Decodable, Sendable {
        let locationRecipesMap: HubRecipesMap?
        let products: HubProducts?
    }

    private struct HubRecipesMap: Decodable, Sendable {
        let dateSkuMap: [HubDateSKUs]?
    }

    private struct HubDateSKUs: Decodable, Sendable {
        let date: String?
        let stations: [HubStationSKUs]?
    }

    private struct HubStationSKUs: Decodable, Sendable {
        let id: Int?
        let skus: HubSKUBag?
    }

    private struct HubSKUBag: Decodable, Sendable {
        let simple: [String]?
    }

    private struct HubProducts: Decodable, Sendable {
        let items: [HubProduct]?
    }

    private struct HubProduct: Decodable, Sendable {
        let sku: String?
        let name: String?
        let attributes: [HubAttribute]?
    }

    private struct HubAttribute: Decodable, Sendable {
        let name: String?
        let values: [String]

        private enum CodingKeys: String, CodingKey { case name, value }

        init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            name = try container.decodeIfPresent(String.self, forKey: .name)
            if let list = try? container.decodeIfPresent([String].self, forKey: .value) {
                values = list
            } else if let single = try? container.decodeIfPresent(String.self, forKey: .value) {
                values = [single]
            } else {
                values = []
            }
        }
    }

    private struct HubProductsBySKU: Decodable, Sendable {
        let Commerce_products: HubProducts?
    }

    private struct StationDraft {
        var name: String
        var position: Int
        var dishIDs: [String]
    }

    enum DiningFetchError: Error {
        case noDataForDay
    }

    // MARK: - Anteater API helpers

    private func getData<T: Decodable & Sendable>(_ type: T.Type, path: String) async throws -> T {
        guard let url = URL(string: base + path) else {
            throw URLError(.badURL)
        }
        let envelope: Envelope<T>
        do {
            envelope = try await http.json(Envelope<T>.self, from: url)
        } catch let error as HTTPError {
            if case .badStatus(let code, _) = error, code == 404 {
                throw DiningFetchError.noDataForDay
            }
            throw error
        }
        if envelope.ok == false {
            let message = envelope.message ?? ""
            if message.localizedCaseInsensitiveContains("no data") {
                throw DiningFetchError.noDataForDay
            }
            throw HTTPError.badStatus(code: 502, url: url)
        }
        guard let data = envelope.data else {
            throw HTTPError.decoding(underlying: URLError(.cannotParseResponse), url: url)
        }
        return data
    }

    private func restaurants() async throws -> [APIRestaurant] {
        try await cache.remember("dining:restaurants", ttl: Self.stationsTTL) {
            try await getData([APIRestaurant].self, path: "/restaurants")
        }
    }

    private func stationMap() async throws -> [String: String] {
        var map: [String: String] = [:]
        if let hub = try? await hubStationDirectory() {
            for (id, station) in hub { map[id] = station.name }
        }
        if let restaurants = try? await restaurants() {
            for restaurant in restaurants {
                for station in restaurant.stations ?? [] {
                    if map[station.id] == nil {
                        map[station.id] = station.name.trimmingCharacters(in: .whitespaces)
                    }
                }
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

        var combined: [String: APIDish] = [:]
        for chunk in stride(from: 0, to: unique.count, by: Self.dishBatchSize).map({
            Array(unique[$0..<min($0 + Self.dishBatchSize, unique.count)])
        }) {
            let joined = chunk.joined(separator: ",")
            let encoded = joined.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? joined
            let batch: [String: APIDish] = try await cache.remember("dining:dishes:\(joined)", ttl: Self.dishesTTL) {
                let dishes = try await FetchRetry.run {
                    try await getData([APIDish].self, path: "/dishes/batch?ids=\(encoded)")
                }
                return Dictionary(dishes.map { ($0.id, $0) }, uniquingKeysWith: { first, _ in first })
            }
            for (id, dish) in batch { combined[id] = dish }
        }
        return combined
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
        return (startMinutes.map { $0 / 60 * 100 + 50 } ?? 9_000, startMinutes ?? 0)
    }

    /// Served periods in the day's natural order (the API returns an unordered dictionary).
    /// A period with only empty station arrays is not served.
    private static func servedPeriods(_ today: APIRestaurantToday) -> [APIPeriod] {
        (today.periods ?? [:]).values
            .filter { period in
                (period.stationToDishes ?? [:]).values.contains { !$0.isEmpty }
            }
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

    // MARK: - Hub helpers

    private func hubLocations() async throws -> [HubLocation] {
        try await cache.remember("dining:hub:locations", ttl: Self.stationsTTL) {
            let query = """
            query($campusUrlKey:String!){getLocations(campusUrlKey:$campusUrlKey){\
            commerceAttributes{url_key hasActiveMenus children{id name position}}\
            aemAttributes{name hoursOfOperation{schedule}}}}
            """
            let data = try await FetchRetry.run {
                try await ElevateMesh.get(
                    HubLocationsData.self,
                    query: query,
                    variables: #"{"campusUrlKey":"campus"}"#,
                    http: http
                )
            }
            return data.getLocations ?? []
        }
    }

    private func hubStationDirectory() async throws -> [String: (name: String, position: Int)] {
        var map: [String: (name: String, position: Int)] = [:]
        for location in try await hubLocations() {
            for station in location.commerceAttributes?.children ?? [] {
                guard let id = station.id else { continue }
                let name = (station.name ?? "Menu").trimmingCharacters(in: .whitespaces)
                map[String(id)] = (name, station.position ?? 0)
            }
        }
        return map
    }

    private func hubMealPeriods() async throws -> [HubMealPeriod] {
        try await cache.remember("dining:hub:mealPeriods", ttl: Self.stationsTTL) {
            let query = "query{Commerce_mealPeriods(sort_order:ASC){name id position}}"
            let data = try await FetchRetry.run {
                try await ElevateMesh.get(
                    HubMealPeriodsData.self,
                    query: query,
                    variables: "{}",
                    http: http
                )
            }
            return data.Commerce_mealPeriods ?? []
        }
    }

    private func recipes(
        urlKey: String,
        dateISO: String,
        periodID: Int,
        viewType: String
    ) async throws -> HubRecipes {
        let key = "dining:hub:recipes:\(urlKey):\(dateISO):\(periodID):\(viewType)"
        return try await cache.remember(key, ttl: Self.todayTTL) {
            let query = """
            query getLocationRecipes($locationUrlKey:String!,$date:String!,$mealPeriod:Int,$viewType:Commerce_MenuViewType!){\
            getLocationRecipes(campusUrlKey:"campus",locationUrlKey:$locationUrlKey,date:$date,mealPeriod:$mealPeriod,viewType:$viewType){\
            locationRecipesMap{dateSkuMap{date stations{id skus{simple}}}}\
            products{items{sku name attributes{name value}}}}}
            """
            let variables = #"{"locationUrlKey":"\#(urlKey)","date":"\#(dateISO)","mealPeriod":\#(periodID),"viewType":"\#(viewType)"}"#
            let data = try await FetchRetry.run {
                try await ElevateMesh.get(
                    HubRecipesData.self,
                    query: query,
                    variables: variables,
                    http: http
                )
            }
            return data.getLocationRecipes ?? HubRecipes(locationRecipesMap: nil, products: nil)
        }
    }

    private func commerceProducts(skus: [String]) async throws -> [String: MenuItem] {
        let unique = Array(Set(skus)).sorted()
        guard !unique.isEmpty else { return [:] }
        var combined: [String: MenuItem] = [:]
        for chunk in stride(from: 0, to: unique.count, by: 20).map({
            Array(unique[$0..<min($0 + 20, unique.count)])
        }) {
            let listed = chunk.map { "\"\($0)\"" }.joined(separator: ",")
            let query = """
            query($skus:[String!]){Commerce_products(filter:{sku:{in:$skus}},pageSize:50){items{sku name}}}
            """
            let data: HubProductsBySKU = try await cache.remember(
                "dining:hub:products:\(chunk.joined(separator: ","))",
                ttl: Self.dishesTTL
            ) {
                try await FetchRetry.run {
                    try await ElevateMesh.get(
                        HubProductsBySKU.self,
                        query: query,
                        variables: #"{"skus":[\#(listed)]}"#,
                        http: http
                    )
                }
            }
            for product in data.Commerce_products?.items ?? [] {
                guard let sku = product.sku, let name = product.name, !name.isEmpty else { continue }
                combined[sku] = MenuItem(
                    id: sku, name: name, description: nil, calories: nil,
                    servingSize: nil, allergens: [], dietaryTags: []
                )
            }
        }
        return combined
    }

    private func hubStationSKUs(
        urlKey: String,
        dateISO: String,
        periodID: Int
    ) async throws -> (stations: [String: [String]], products: [HubProduct]) {
        async let daily = recipes(urlKey: urlKey, dateISO: dateISO, periodID: periodID, viewType: "DAILY")
        async let weekly = recipes(urlKey: urlKey, dateISO: Self.weekStartISO(for: dateISO), periodID: periodID, viewType: "WEEKLY")
        let (dailyRecipes, weeklyRecipes) = try await (daily, weekly)

        var byStation: [String: [String]] = [:]
        func ingest(_ recipes: HubRecipes) {
            for day in recipes.locationRecipesMap?.dateSkuMap ?? [] {
                guard day.date == dateISO else { continue }
                for station in day.stations ?? [] {
                    guard let id = station.id else { continue }
                    let skus = (station.skus?.simple ?? []).filter { !$0.isEmpty }
                    guard !skus.isEmpty else { continue }
                    var existing = byStation[String(id)] ?? []
                    for sku in skus where !existing.contains(sku) {
                        existing.append(sku)
                    }
                    byStation[String(id)] = existing
                }
            }
        }
        ingest(weeklyRecipes)
        ingest(dailyRecipes)

        var products: [HubProduct] = []
        var seen = Set<String>()
        for product in (weeklyRecipes.products?.items ?? []) + (dailyRecipes.products?.items ?? []) {
            guard let sku = product.sku, seen.insert(sku).inserted else { continue }
            products.append(product)
        }
        return (byStation, products)
    }

    private static let dietaryTagIDs: [String: String] = [
        "96": "Vegan", "99": "Vegetarian", "133": "Halal",
        "87": "Kosher", "78": "Gluten-Free", "102": "Locally Grown",
    ]

    private static func menuItem(from product: HubProduct) -> MenuItem? {
        guard let sku = product.sku else { return nil }
        var name = product.name ?? ""
        var description: String?
        var calories: Int?
        var serving: String?
        var allergens: [String] = []
        var dietaryTags: [String] = []

        for attribute in product.attributes ?? [] {
            switch attribute.name {
            case "marketing_name":
                if let value = attribute.values.first, !value.isEmpty { name = value }
            case "marketing_description":
                let value = attribute.values.first?.trimmingCharacters(in: .whitespacesAndNewlines)
                description = (value?.isEmpty ?? true) ? nil : value
            case "calories":
                if let value = attribute.values.first, let parsed = Double(value) {
                    calories = Int(parsed.rounded())
                }
            case "serving_combined":
                if let value = attribute.values.first, !value.isEmpty, value != "N/A" { serving = value }
            case "allergen_statement":
                if let value = attribute.values.first,
                   let list = value.components(separatedBy: ":").last {
                    allergens = list.components(separatedBy: ",")
                        .map { $0.trimmingCharacters(in: .whitespaces) }
                        .filter { !$0.isEmpty }
                }
            case "recipe_attributes":
                dietaryTags = attribute.values.flatMap { $0.components(separatedBy: ",") }
                    .compactMap { dietaryTagIDs[$0.trimmingCharacters(in: .whitespaces)] }
            default:
                break
            }
        }
        guard !name.isEmpty else { return nil }
        return MenuItem(
            id: sku, name: name, description: description, calories: calories,
            servingSize: serving, allergens: allergens, dietaryTags: dietaryTags
        )
    }

    private func locationFromHub(
        id: String,
        dateISO: String,
        nowMinutes: Int,
        isToday: Bool
    ) async -> DiningLocation? {
        guard let urlKey = HallDirectory.hubURLKey(for: id),
              let raw = try? await hubLocations().first(where: { $0.commerceAttributes?.url_key == urlKey })
        else { return nil }

        let weekday = weekdayName(for: dateISO)
        let windows = CampusService.todayWindows(
            schedules: raw.aemAttributes?.hoursOfOperation?.schedule ?? [],
            todayISO: dateISO,
            weekday: weekday
        )
        let openNow = isToday && windows.contains { $0.contains(minute: nowMinutes) }
        let todayHours = CampusService.format(windows: windows)

        var periods: [MealPeriodWindow] = []
        if let schedule = raw.aemAttributes?.hoursOfOperation?.schedule {
            let active = schedule.first { item in
                item.type == "special"
                    && (item.start_date ?? "9999") <= dateISO
                    && (item.end_date ?? "0000") >= dateISO
            } ?? schedule.first { $0.type == "standard" }
            for meal in active?.meal_periods ?? [] {
                guard let name = meal.meal_period, !name.isEmpty else { continue }
                let window = CampusService.window(from: meal.opening_hours, weekday: weekday)
                // Skip catch-all "off" periods so we don't advertise meals that aren't served.
                if window == nil && (meal.opening_hours ?? "").lowercased().contains("off") {
                    continue
                }
                if window == nil && (meal.opening_hours ?? "").trimmingCharacters(in: .whitespaces).isEmpty {
                    continue
                }
                periods.append(MealPeriodWindow(
                    name: name,
                    startMinutes: window?.start,
                    endMinutes: window?.end
                ))
            }
        }
        periods.sort {
            Self.periodRank($0.name, startMinutes: $0.startMinutes) < Self.periodRank($1.name, startMinutes: $1.startMinutes)
        }

        return DiningLocation(
            id: id,
            name: HallDirectory.displayName(for: id),
            area: HallDirectory.area(for: id),
            openNow: openNow,
            todayHours: todayHours,
            availablePeriods: periods.map(\.name),
            periods: periods,
            hoursApproximate: false
        )
    }

    /// Sunday of the Irvine week that contains `dateISO`.
    /// WEEKLY recipes keyed on the target day itself drop stations that are
    /// still present when the same week is fetched from Sunday.
    static func weekStartISO(for dateISO: String) -> String {
        let parser = DateFormatter()
        parser.dateFormat = "yyyy-MM-dd"
        parser.timeZone = PacificTime.timeZone
        parser.locale = Locale(identifier: "en_US_POSIX")
        guard let date = parser.date(from: dateISO) else { return dateISO }
        var calendar = PacificTime.calendar
        calendar.firstWeekday = 1
        let start = calendar.date(from: calendar.dateComponents([.yearForWeekOfYear, .weekOfYear], from: date))
        return start.map { PacificTime.todayISO(now: $0) } ?? dateISO
    }

    private func weekdayName(for dateISO: String) -> String {
        let parser = DateFormatter()
        parser.dateFormat = "yyyy-MM-dd"
        parser.timeZone = PacificTime.timeZone
        parser.locale = Locale(identifier: "en_US_POSIX")
        guard let date = parser.date(from: dateISO) else {
            return PacificTime.weekdayName(now: now())
        }
        return PacificTime.weekdayName(now: date)
    }

    // MARK: - Public API

    /// Every dining commons the live sources list, with hours and meal periods
    /// for `date` (defaults to today in Irvine).
    public func locations(date: String? = nil) async -> [DiningLocation] {
        let dateISO = date ?? PacificTime.todayISO(now: now())
        let nowMinutes = PacificTime.nowMinutes(now: now())
        let isToday = dateISO == PacificTime.todayISO(now: now())

        var apiIDs = (try? await restaurants().map(\.id)) ?? []
        if apiIDs.isEmpty { apiIDs = HallDirectory.fallbackIDs }

        var results: [String: DiningLocation] = [:]
        await withTaskGroup(of: (String, DiningLocation).self) { group in
            for hall in apiIDs {
                group.addTask {
                    (hall, await location(for: hall, dateISO: dateISO, nowMinutes: nowMinutes, isToday: isToday))
                }
            }
            for await (id, location) in group {
                results[id] = location
            }
        }

        // Hub fills halls the Anteater API 404s or doesn't know (Oasis).
        for id in HallDirectory.preferredOrder {
            let existing = results[id]
            let needsHub = existing == nil || existing?.availablePeriods.isEmpty == true
            if needsHub, let hub = await locationFromHub(
                id: id, dateISO: dateISO, nowMinutes: nowMinutes, isToday: isToday
            ) {
                results[id] = hub
            }
        }

        var order = HallDirectory.preferredOrder
        for id in apiIDs where !order.contains(id) { order.append(id) }
        return order.compactMap { results[$0] }
    }

    private func location(
        for hall: String,
        dateISO: String,
        nowMinutes: Int,
        isToday: Bool
    ) async -> DiningLocation {
        do {
            let periods = Self.servedPeriods(try await today(for: hall, dateISO: dateISO))
            let starts = periods.compactMap { PacificTime.parseMinutes($0.startTime) }
            let ends = periods.compactMap { PacificTime.parseMinutes($0.endTime) }
            let openNow = isToday && periods.contains { period in
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
    public func menu(for hall: String, period: String, date: String? = nil) async throws -> DiningMenu {
        let dateISO = date ?? PacificTime.todayISO(now: now())
        let lastGoodKey = "dining:lastGood:\(hall):\(dateISO):\(period.lowercased())"

        do {
            let built = try await FetchRetry.run {
                try await buildMenu(for: hall, period: period, dateISO: dateISO)
            }
            if !built.stations.isEmpty {
                await cache.set(lastGoodKey, value: built, ttl: Self.lastGoodTTL)
            }
            return built
        } catch {
            if let stale = await cache.getStale(lastGoodKey, as: DiningMenu.self), !stale.stations.isEmpty {
                return stale.markingStale()
            }
            throw error
        }
    }

    private func buildMenu(for hall: String, period: String, dateISO: String) async throws -> DiningMenu {
        async let hubTask = hubAssignment(for: hall, period: period, dateISO: dateISO)
        async let apiTask = apiAssignment(for: hall, period: period, dateISO: dateISO)
        async let namesTask = stationMap()

        let hub = try? await hubTask
        let api: (stations: [String: [String]], error: Error?)
        do {
            api = (try await apiTask, nil)
        } catch DiningFetchError.noDataForDay {
            api = ([:], nil)
        } catch {
            api = ([:], error)
        }
        let names = (try? await namesTask) ?? [:]

        if hub == nil && api.error != nil && api.stations.isEmpty {
            throw api.error!
        }

        var drafts: [String: StationDraft] = [:]
        func add(stationID: String, dishIDs: [String]) {
            guard !dishIDs.isEmpty else { return }
            let trimmedName = (names[stationID] ?? drafts[stationID]?.name ?? "Menu")
                .trimmingCharacters(in: .whitespaces)
            var draft = drafts[stationID] ?? StationDraft(
                name: trimmedName.isEmpty ? "Menu" : trimmedName,
                position: Int(stationID) ?? 0,
                dishIDs: []
            )
            for id in dishIDs where !draft.dishIDs.contains(id) {
                draft.dishIDs.append(id)
            }
            drafts[stationID] = draft
        }
        for (id, skus) in hub?.stations ?? [:] { add(stationID: id, dishIDs: skus) }
        for (id, skus) in api.stations { add(stationID: id, dishIDs: skus) }

        let allIDs = drafts.values.flatMap(\.dishIDs)
        var itemsByID: [String: MenuItem] = [:]

        if let apiDishes = try? await dishes(ids: allIDs) {
            for (id, dish) in apiDishes {
                itemsByID[id] = Self.menuItem(from: dish)
            }
        }
        for product in hub?.products ?? [] {
            guard let sku = product.sku, itemsByID[sku] == nil,
                  let item = Self.menuItem(from: product)
            else { continue }
            itemsByID[sku] = item
        }
        let unresolved = allIDs.filter { itemsByID[$0] == nil }
        if !unresolved.isEmpty, let named = try? await commerceProducts(skus: unresolved) {
            for (id, item) in named where itemsByID[id] == nil {
                itemsByID[id] = item
            }
        }

        var warnings: [String] = []
        var stations: [MenuStation] = []
        for (stationID, draft) in drafts.sorted(by: {
            if $0.value.position != $1.value.position { return $0.value.position < $1.value.position }
            return $0.key < $1.key
        }) {
            var seenNames = Set<String>()
            let items = draft.dishIDs
                .compactMap { itemsByID[$0] }
                .filter { seenNames.insert($0.name.lowercased()).inserted }
            let missing = draft.dishIDs.filter { itemsByID[$0] == nil }
            if items.isEmpty {
                if !missing.isEmpty {
                    warnings.append("\(draft.name) was on the menu but its dishes didn't load.")
                }
                continue
            }
            if !missing.isEmpty {
                warnings.append("\(draft.name) is missing \(missing.count) dish\(missing.count == 1 ? "" : "es").")
            }
            stations.append(MenuStation(name: draft.name, items: items, id: stationID))
        }

        if drafts.isEmpty, hub == nil, api.stations.isEmpty {
            warnings.append("No menu source responded for this hall, day, and meal.")
        }

        return DiningMenu(
            locationId: hall,
            date: dateISO,
            period: period,
            stations: stations,
            isStale: false,
            fetchedAt: now(),
            warnings: warnings
        )
    }

    private func hubAssignment(
        for hall: String,
        period: String,
        dateISO: String
    ) async throws -> (stations: [String: [String]], products: [HubProduct]) {
        guard let urlKey = HallDirectory.hubURLKey(for: hall) else {
            return ([:], [])
        }
        let periods = try await hubMealPeriods()
        guard let periodID = periods.first(where: { $0.name.lowercased() == period.lowercased() })?.id else {
            return ([:], [])
        }
        return try await hubStationSKUs(urlKey: urlKey, dateISO: dateISO, periodID: periodID)
    }

    private func apiAssignment(
        for hall: String,
        period: String,
        dateISO: String
    ) async throws -> [String: [String]] {
        let today = try await today(for: hall, dateISO: dateISO)
        guard let match = (today.periods ?? [:]).values
            .first(where: { $0.name.lowercased() == period.lowercased() })
        else { return [:] }
        var result: [String: [String]] = [:]
        for (stationID, dishIDs) in match.stationToDishes ?? [:] {
            let ids = dishIDs.filter { !$0.isEmpty }
            if !ids.isEmpty { result[stationID] = ids }
        }
        return result
    }
}

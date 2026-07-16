import Foundation

// Campus retail dining (Starbucks, Panda Express, Subway, Zot N Go, food courts)
// from UCI's dining hub (uci.mydininghub.com), which is backed by a public
// GraphQL mesh on elevate-dxp.com. No real auth: the two header values below are
// static constants embedded in the site's own public JS bundle (the community
// icssc/anteater-api scraper uses the same path). They are unofficial internals
// and may rotate, so failures should degrade gracefully.
//
// Hours model: each location has one "standard" weekly schedule plus dated
// "special" overrides (finals week, breaks, summer phases). The active schedule
// is the special whose date window contains today, else the standard. Hours are
// schema.org-style strings per meal period, e.g. "Mo-Fr 07:30-16:00; Sa-Su off".

public struct CampusService: Sendable {
    private static let meshURL = "https://api.elevate-dxp.com/api/mesh/c087f756-cc72-4649-a36f-3a41b700c519/graphql"
    private static let locationsTTL: TimeInterval = 60 * 60
    private static let menuTTL: TimeInterval = 30 * 60

    /// Residential commons already covered by the Eat tab.
    private static let excludedKeys: Set<String> = ["the-anteatery", "brandywine"]

    private let http: any HTTPFetching
    private let cache: TTLCache
    private let now: @Sendable () -> Date

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
        let data: T?
    }

    private struct LocationsData: Decodable, Sendable {
        let getLocations: [RawLocation]?
    }

    private struct RawLocation: Decodable, Sendable {
        let commerceAttributes: CommerceAttrs?
        let aemAttributes: AEMAttrs?
    }

    private struct CommerceAttrs: Decodable, Sendable {
        let url_key: String?
        let hasActiveMenus: Bool?
    }

    private struct AEMAttrs: Decodable, Sendable {
        let name: String?
        let hoursOfOperation: HoursOfOperation?
    }

    private struct HoursOfOperation: Decodable, Sendable {
        let schedule: [RawSchedule]?
    }

    struct RawSchedule: Decodable, Sendable {
        let name: String?
        let type: String?
        let start_date: String?
        let end_date: String?
        let meal_periods: [RawMealPeriod]?
    }

    struct RawMealPeriod: Decodable, Sendable {
        let meal_period: String?
        let opening_hours: String?
    }

    private struct MenuData: Decodable, Sendable {
        let getLocationMealPeriodRecipes: RawMenu?
    }

    private struct RawMenu: Decodable, Sendable {
        let locationMealPeriodRecipesData: RawMenuMaps?
        let products: [RawProduct]?
    }

    private struct RawMenuMaps: Decodable, Sendable {
        let mealPeriodSkuMap: [RawMealPeriodSkus]?
    }

    private struct RawMealPeriodSkus: Decodable, Sendable {
        let name: String?
        let skus: [String]?
    }

    private struct RawProduct: Decodable, Sendable {
        let name: String?
        let sku: String?
        let attributes: [RawAttribute]?
    }

    /// Attribute values arrive as either a string or an array of strings.
    private struct RawAttribute: Decodable, Sendable {
        let name: String?
        let values: [String]

        private enum CodingKeys: String, CodingKey {
            case name, value
        }

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

    // MARK: - Fetch

    private func graphQL<T: Decodable & Sendable>(_ type: T.Type, query: String, variables: String) async throws -> T {
        var components = URLComponents(string: Self.meshURL)!
        components.queryItems = [
            URLQueryItem(name: "query", value: query),
            URLQueryItem(name: "variables", value: variables),
        ]
        guard let url = components.url else { throw URLError(.badURL) }
        // Static, public header values from the site's own JS bundle (see header comment).
        let headers = [
            "Referer": "https://uci.mydininghub.com/",
            "Origin": "https://uci.mydininghub.com",
            "store": "ch_uci_en",
            "x-api-key": "ElevateAPIProd",
            "magento-store-code": "ch_uci",
            "magento-website-code": "ch_uci",
            "magento-store-view-code": "ch_uci_en",
        ]
        let data = try await http.data(from: url, headers: headers)
        let envelope = try JSONDecoder().decode(Envelope<T>.self, from: data)
        guard let payload = envelope.data else {
            throw HTTPError.decoding(underlying: URLError(.cannotParseResponse), url: url)
        }
        return payload
    }

    // MARK: - Public API

    /// All campus retail spots with today's hours and open state, commons excluded.
    public func places() async throws -> [CampusPlace] {
        let currentDate = now()
        let todayISO = PacificTime.todayISO(now: currentDate)
        return try await cache.remember("campus:places:\(todayISO)", ttl: Self.locationsTTL) {
            let query = """
            query($campusUrlKey:String!){getLocations(campusUrlKey:$campusUrlKey){\
            commerceAttributes{url_key hasActiveMenus}aemAttributes{name hoursOfOperation{schedule}}}}
            """
            let data = try await graphQL(LocationsData.self, query: query, variables: #"{"campusUrlKey":"campus"}"#)
            return (data.getLocations ?? []).compactMap { raw -> CampusPlace? in
                guard let key = raw.commerceAttributes?.url_key,
                      !Self.excludedKeys.contains(key),
                      let name = raw.aemAttributes?.name?
                          .replacingOccurrences(of: "\u{00AD}", with: "") // soft hyphens in feed
                          .trimmingCharacters(in: .whitespacesAndNewlines),
                      !name.isEmpty
                else { return nil }

                let windows = Self.todayWindows(
                    schedules: raw.aemAttributes?.hoursOfOperation?.schedule ?? [],
                    todayISO: todayISO,
                    weekday: PacificTime.weekdayName(now: currentDate)
                )
                let nowMinutes = PacificTime.nowMinutes(now: currentDate)
                let openNow = windows.contains { $0.contains(minute: nowMinutes) }
                return CampusPlace(
                    id: key,
                    name: name,
                    category: Self.categorize(name),
                    openNow: openNow,
                    todayHours: Self.format(windows: windows),
                    hasMenu: raw.commerceAttributes?.hasActiveMenus ?? false,
                    opensAtMinutes: openNow ? nil : windows.map(\.start).filter { $0 > nowMinutes }.min()
                )
            }
            .sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
        }
    }

    /// Published menu for a retail spot, grouped by meal period.
    /// Empty when the venue doesn't publish menus (brand-app-only places).
    public func menu(for placeID: String, date: String? = nil) async throws -> [MenuStation] {
        let dateISO = date ?? PacificTime.todayISO(now: now())
        return try await cache.remember("campus:menu:\(placeID):\(dateISO)", ttl: Self.menuTTL) {
            let query = """
            query($campusUrlKey:String!,$locationUrlKey:String!,$date:String!){\
            getLocationMealPeriodRecipes(campusUrlKey:$campusUrlKey,locationUrlKey:$locationUrlKey,date:$date){\
            locationMealPeriodRecipesData{mealPeriodSkuMap{id name skus}}\
            products{name sku attributes{name value}}}}
            """
            let variables = #"{"campusUrlKey":"campus","locationUrlKey":"\#(placeID)","date":"\#(dateISO)"}"#
            let data = try await graphQL(MenuData.self, query: query, variables: variables)
            guard let menu = data.getLocationMealPeriodRecipes else { return [] }

            var products: [String: MenuItem] = [:]
            for raw in menu.products ?? [] {
                guard let sku = raw.sku, let item = Self.menuItem(from: raw) else { continue }
                products[sku] = item
            }

            return (menu.locationMealPeriodRecipesData?.mealPeriodSkuMap ?? []).compactMap { period in
                guard let name = period.name else { return nil }
                var seen = Set<String>()
                let items = (period.skus ?? [])
                    .compactMap { products[$0] }
                    .filter { seen.insert($0.name.lowercased()).inserted }
                return items.isEmpty ? nil : MenuStation(name: name, items: items)
            }
        }
    }

    // MARK: - Hours parsing

    struct TimeWindow: Equatable {
        let start: Int
        let end: Int

        func contains(minute: Int) -> Bool {
            if end > start { return minute >= start && minute < end }
            // Window crossing midnight, e.g. 21:00–02:00.
            return minute >= start || minute < (end % (24 * 60))
        }
    }

    /// Resolve today's open windows: dated special schedule wins over standard;
    /// within a schedule, union the windows of all meal periods.
    static func todayWindows(schedules: [RawSchedule], todayISO: String, weekday: String) -> [TimeWindow] {
        let active = schedules.first { schedule in
            schedule.type == "special"
                && (schedule.start_date ?? "9999") <= todayISO
                && (schedule.end_date ?? "0000") >= todayISO
        } ?? schedules.first { $0.type == "standard" }

        guard let active else { return [] }
        var windows: [TimeWindow] = []
        for period in active.meal_periods ?? [] {
            if let window = window(from: period.opening_hours, weekday: weekday), !windows.contains(window) {
                windows.append(window)
            }
        }
        return windows.sorted { $0.start < $1.start }
    }

    private static let dayAbbreviations = ["Sunday": "Su", "Monday": "Mo", "Tuesday": "Tu", "Wednesday": "We", "Thursday": "Th", "Friday": "Fr", "Saturday": "Sa"]
    private static let dayOrder = ["Mo", "Tu", "We", "Th", "Fr", "Sa", "Su"]

    /// Parse a schema.org opening_hours string ("Mo-Fr 07:30-16:00; Sa-Su off")
    /// for one weekday. The first rule mentioning the day wins (the feed emits
    /// contradictory trailing rules; the site honors the first).
    static func window(from openingHours: String?, weekday: String) -> TimeWindow? {
        guard let openingHours, let dayCode = dayAbbreviations[weekday] else { return nil }
        for rule in openingHours.components(separatedBy: ";") {
            let trimmed = rule.trimmingCharacters(in: .whitespaces)
            guard !trimmed.isEmpty else { continue }
            let parts = trimmed.components(separatedBy: " ")
            guard let daySpec = parts.first, ruleCovers(daySpec: daySpec, dayCode: dayCode) else { continue }
            let remainder = parts.dropFirst().joined(separator: " ")
            if remainder.lowercased().contains("off") || remainder.isEmpty { return nil }
            // "07:30-16:00"
            let times = remainder.components(separatedBy: "-")
            guard times.count == 2,
                  let start = PacificTime.parseMinutes(times[0].trimmingCharacters(in: .whitespaces)),
                  let end = PacificTime.parseMinutes(times[1].trimmingCharacters(in: .whitespaces))
            else { return nil }
            return TimeWindow(start: start, end: end == start ? start : end)
        }
        return nil
    }

    /// "Mo-Fr", "Sa-Su", "Mo", "Mo,We,Fr" -> does it cover dayCode?
    private static func ruleCovers(daySpec: String, dayCode: String) -> Bool {
        for token in daySpec.components(separatedBy: ",") {
            if token == dayCode { return true }
            let bounds = token.components(separatedBy: "-")
            if bounds.count == 2,
               let lo = dayOrder.firstIndex(of: bounds[0]),
               let hi = dayOrder.firstIndex(of: bounds[1]),
               let day = dayOrder.firstIndex(of: dayCode),
               lo <= hi, (lo...hi).contains(day) {
                return true
            }
        }
        return false
    }

    static func format(windows: [TimeWindow]) -> String? {
        guard !windows.isEmpty else { return nil }
        return windows
            .map { "\(PacificTime.formatMinutes($0.start)) – \(PacificTime.formatMinutes($0.end % (24 * 60)))" }
            .joined(separator: ", ")
    }

    // MARK: - Categorization & product mapping

    static func categorize(_ name: String) -> String {
        let lowered = name.lowercased()
        if lowered.contains("zot n go") || lowered.contains("market") { return "Markets" }
        if lowered.contains("pub") { return "Restaurants & Pubs" }
        if ["starbucks", "java", "cafe", "café", "einstein", "jamba", "panera", "green room"]
            .contains(where: lowered.contains) {
            return "Coffee & Cafés"
        }
        return "Food Courts"
    }

    /// Dietary tag ids from the hub's recipe_attributes vocabulary, mapped to the
    /// same labels the Eat tab uses (verified via attribute metadata query).
    private static let dietaryTagIDs: [String: String] = [
        "96": "Vegan",
        "99": "Vegetarian",
        "133": "Halal",
        "87": "Kosher",
        "78": "Gluten-Free",
        "102": "Locally Grown",
    ]

    private static func menuItem(from raw: RawProduct) -> MenuItem? {
        guard let sku = raw.sku else { return nil }
        var name = raw.name ?? ""
        var description: String?
        var calories: Int?
        var serving: String?
        var allergens: [String] = []
        var dietaryTags: [String] = []

        for attribute in raw.attributes ?? [] {
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
                // "Contains: Eggs, Milk" -> ["Eggs", "Milk"]
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
            id: sku,
            name: name,
            description: description,
            calories: calories,
            servingSize: serving,
            allergens: allergens,
            dietaryTags: dietaryTags
        )
    }
}

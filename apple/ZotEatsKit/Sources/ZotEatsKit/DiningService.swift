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
    private static let todayTTL: TimeInterval = 20 * 60
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
        var posted: Set<String> = []
        var iso = fromISO
        var steps = 0
        while iso <= throughISO, steps < 28 {
            let periods = await mealPeriods(for: hall, dateISO: iso, forceRefresh: forceRefresh)
            if !periods.isEmpty {
                posted.insert(iso)
            }
            guard let next = UCITime.nextISO(after: iso) else { break }
            iso = next
            steps += 1
        }
        return posted
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
            nutrition: facts
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
                dietaryTags: tags,
                nutrition: item.nutrition
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
        // Hub already advertises The Oasis (Coming Soon) while Anteater API still
        // only lists Anteatery + Brandywine — surface an honest card, no fake menu.
        if !ordered.contains(where: { HallDirectory.isOasis($0.id) }) {
            ordered.append(Self.oasisComingSoonLocation())
        }
        return ordered
    }

    /// Dining Hub: lunch + dinner, no breakfast, meal-plan only, Mesa Court,
    /// Mon–Fri; meal plans start Sept 21 2026. No invented live board.
    public static func oasisComingSoonLocation() -> DiningLocation {
        DiningLocation(
            id: HallDirectory.oasisComingSoonID,
            name: HallDirectory.displayName(for: HallDirectory.oasisComingSoonID),
            area: HallDirectory.area(for: HallDirectory.oasisComingSoonID),
            openNow: false,
            todayHours: nil,
            availablePeriods: [],
            periods: [],
            hoursApproximate: true,
            comingSoonSubtitle: "Coming Soon"
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

    /// Always-visible Eat meal chips. Breakfast / Lunch / Dinner stay on screen
    /// even when the live board has only posted one period (Atharv 7am peek).
    public static let mealSelectorPills = ["Breakfast", "Lunch", "Dinner"]

    /// Primary meal pills present on a board. Brunch maps into Breakfast;
    /// All Day is folded into each meal as "Available all day" (no own pill).
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
    /// Unpublished days (API 404) return an empty menu — never throw.
    public func menu(
        for hall: String,
        period: String,
        date: String? = nil,
        forceRefresh: Bool = false
    ) async throws -> DiningMenu {
        let dateISO = date ?? PacificTime.todayISO(now: now())
        let today = try await today(for: hall, dateISO: dateISO, forceRefresh: forceRefresh)
        let available = (today.periods ?? [:]).values.map(\.name)

        // No periods published for this day yet (404 mapped to empty, or blank payload).
        guard !available.isEmpty else {
            return DiningMenu(locationId: hall, date: dateISO, period: period, stations: [])
        }

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

        let built = DiningMenu(
            locationId: hall, date: dateISO, period: resolved, stations: mealStations
        )
        // Anteater API often leaves every is* flag false; the dining hub carries
        // much richer recipe_attributes. Merge by dish name (soft-fail).
        return await enrichDietTags(built)
    }

    /// Overlay dining-hub dietary tags / allergens onto Anteater menu items.
    private func enrichDietTags(_ menu: DiningMenu) async -> DiningMenu {
        guard let hubKey = HallDirectory.campusHubKey(for: menu.locationId) else { return menu }
        let hubStations: [MenuStation]
        do {
            hubStations = try await CampusService(http: http, cache: cache, now: now)
                .menu(for: hubKey, date: menu.date)
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
        guard !tagsByKey.isEmpty || !allergensByKey.isEmpty else { return menu }

        let stations = menu.stations.map { station in
            MenuStation(
                name: station.name,
                items: station.items.map { item in
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
                        nutrition: item.nutrition
                    )
                }
            )
        }
        return DiningMenu(
            locationId: menu.locationId,
            date: menu.date,
            period: menu.period,
            stations: stations
        )
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

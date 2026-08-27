import Foundation

// Domain models for ZotEats — a direct port of the IPC contract in
// renderer/shared/types.ts, shared by all app targets (iOS, macOS).

/// Feature switches shared by the app and its widget.
public enum FeatureFlags {
    /// Typical-occupancy percentages on dining hall cards and the widget.
    /// Hidden until Occuspace installs sensors in the dining halls and we can
    /// show real measurements via their public API — the estimation engine and
    /// its tests stay in place so flipping this back on restores the UI.
    public static let diningHallOccupancy = false
}

/// Metadata for dining commons. Hall ids come from the live API, so a new
/// commons appears in the app automatically; this directory only beautifies
/// the names/areas we know, with a sensible fallback for future halls.
public enum HallDirectory {
    static let known: [String: (name: String, area: String)] = [
        "anteatery": ("The Anteatery", "Mesa Court"),
        "brandywine": ("Brandywine", "Middle Earth"),
        // Third residential dining commons — Hub lists The Oasis as Coming Soon
        // (meal-plan only, Lunch/Dinner, no breakfast). Anteater API `/restaurants`
        // will list a live id when menus exist; until then Eat injects a Coming Soon card.
        "oasis": ("The Oasis", "Mesa Court"),
        "the-oasis": ("The Oasis", "Mesa Court"),
        "the-oasis-dining-hall": ("The Oasis", "Mesa Court"),
        "mesa-commons": ("Mesa Commons", "Mesa Court"),
        "mesa-court-commons": ("Mesa Court Commons", "Mesa Court"),
        "mesa-court-dining": ("Mesa Court Dining", "Mesa Court"),
        "middle-earth-towers": ("Middle Earth Towers Dining", "Middle Earth"),
        "middle-earth-commons": ("Middle Earth Commons", "Middle Earth"),
    ]

    /// Offline fallback — live halls only (don't invent an unopened third).
    public static let fallbackIDs = ["anteatery", "brandywine"]

    /// Stable id for the Coming Soon Oasis card until `/restaurants` lists it.
    public static let oasisComingSoonID = "oasis"

    /// Dining-hub `url_key`s that belong on Eat, not Campus retail.
    public static let campusHubExcludedKeys: Set<String> = [
        "the-anteatery", "brandywine",
        "the-oasis-dining-hall", "the-oasis", "oasis",
        "mesa-commons", "mesa-court-commons", "mesa-court-dining",
        "middle-earth-towers", "middle-earth-commons",
    ]

    /// Anteater API hall id → dining-hub url_key (for richer diet tags).
    public static func campusHubKey(for hallID: String) -> String? {
        switch hallID.lowercased() {
        case "anteatery": return "the-anteatery"
        case "brandywine": return "brandywine"
        case "oasis", "the-oasis", "the-oasis-dining-hall":
            return "the-oasis-dining-hall"
        default:
            // Future halls often share the same slug on both feeds.
            return campusHubExcludedKeys.contains(hallID) ? hallID : nil
        }
    }

    /// True when this id is Oasis (live or Coming Soon placeholder).
    public static func isOasis(_ id: String) -> Bool {
        switch id.lowercased() {
        case "oasis", "the-oasis", "the-oasis-dining-hall": return true
        default: return false
        }
    }

    public static func displayName(for id: String) -> String {
        known[id]?.name ?? prettify(id)
    }

    /// Short Eat segment label so three halls fit without a horizontal carousel.
    public static func compactName(for id: String) -> String {
        switch id.lowercased() {
        case "anteatery": return "Anteatery"
        case "brandywine": return "Brandywine"
        case "oasis", "the-oasis", "the-oasis-dining-hall": return "Oasis"
        default:
            let full = displayName(for: id)
            if full.hasPrefix("The ") { return String(full.dropFirst(4)) }
            return full
        }
    }

    public static func area(for id: String) -> String {
        known[id]?.area ?? "UCI Campus"
    }

    /// Reverse lookup for Live Activity cold-start sync when an older
    /// activity only stored the display name (pre-`hallID` attribute).
    public static func id(matchingDisplayName name: String) -> String? {
        let needle = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !needle.isEmpty else { return nil }
        return known.first {
            $0.value.name.caseInsensitiveCompare(needle) == .orderedSame
        }?.key
    }

    /// "middle-earth-commons" -> "Middle Earth Commons".
    static func prettify(_ id: String) -> String {
        id.split(whereSeparator: { $0 == "-" || $0 == "_" })
            .map { $0.prefix(1).uppercased() + $0.dropFirst() }
            .joined(separator: " ")
    }
}

/// One meal period's serving window, in minutes since midnight Pacific.
public struct MealPeriodWindow: Codable, Sendable, Equatable {
    public let name: String
    public let startMinutes: Int?
    public let endMinutes: Int?

    public init(name: String, startMinutes: Int?, endMinutes: Int?) {
        self.name = name
        self.startMinutes = startMinutes
        self.endMinutes = endMinutes
    }
}

/// A UCI dining commons with today's hours and which meal periods it serves.
public struct DiningLocation: Codable, Sendable, Identifiable, Equatable {
    public let id: String
    public let name: String
    public let area: String
    public let openNow: Bool
    /// Human-readable daily window, e.g. "7:00 AM – 9:00 PM".
    public let todayHours: String?
    /// Meal-period names served today, in order.
    public let availablePeriods: [String]
    /// Today's serving windows in chronological order (drives "opens in"/"closes in").
    public let periods: [MealPeriodWindow]
    /// True when hours come from a maintained schedule rather than a live source.
    public let hoursApproximate: Bool
    /// Tomorrow's earliest meal start (Irvine minutes). Set after today's last
    /// window so Eat / Dining Status can show "Breakfast tomorrow · 7:15 AM".
    public let opensTomorrowAtMinutes: Int?
    /// Meal name for `opensTomorrowAtMinutes` (e.g. "Breakfast").
    public let opensTomorrowPeriod: String?
    /// Next open after tomorrow when tomorrow's board is empty (dayOffset ≥ 2).
    public let opensNextAtMinutes: Int?
    public let opensNextDayOffset: Int?
    public let opensNextWeekday: String?
    public let opensNextPeriod: String?
    /// Irvine ISO for `opensNext*` (deep links / See-next CTA).
    public let opensNextDateISO: String?
    /// Non-nil for halls Hub lists before menus exist (e.g. The Oasis).
    /// Never invent a live board for these — Eat shows Coming Soon copy only.
    public let comingSoonSubtitle: String?

    public init(
        id: String,
        name: String,
        area: String,
        openNow: Bool,
        todayHours: String?,
        availablePeriods: [String],
        periods: [MealPeriodWindow] = [],
        hoursApproximate: Bool,
        opensTomorrowAtMinutes: Int? = nil,
        opensTomorrowPeriod: String? = nil,
        opensNextAtMinutes: Int? = nil,
        opensNextDayOffset: Int? = nil,
        opensNextWeekday: String? = nil,
        opensNextPeriod: String? = nil,
        opensNextDateISO: String? = nil,
        comingSoonSubtitle: String? = nil
    ) {
        self.id = id
        self.name = name
        self.area = area
        self.openNow = openNow
        self.todayHours = todayHours
        self.availablePeriods = availablePeriods
        self.periods = periods
        self.hoursApproximate = hoursApproximate
        self.opensTomorrowAtMinutes = opensTomorrowAtMinutes
        self.opensTomorrowPeriod = opensTomorrowPeriod
        self.opensNextAtMinutes = opensNextAtMinutes
        self.opensNextDayOffset = opensNextDayOffset
        self.opensNextWeekday = opensNextWeekday
        self.opensNextPeriod = opensNextPeriod
        self.opensNextDateISO = opensNextDateISO
        self.comingSoonSubtitle = comingSoonSubtitle
    }

    public var isComingSoon: Bool { comingSoonSubtitle != nil }
}

/// The hall's live state relative to today's meal windows — the "when" intelligence
/// behind status lines like "Lunch · closes in 1h 10m" or "Dinner starts in 45m".
public enum HallOpenState: Sendable, Equatable {
    /// Serving now; `closesAt` is minutes since midnight Pacific.
    case open(period: String, closesAt: Int)
    /// Between meals or before opening; `opensAt` is minutes since midnight Pacific.
    case openingLater(period: String, opensAt: Int)
    /// Published windows ended, but Dinner isn't posted yet and it's still
    /// before evening — Lunch/Dinner may still drop (don't jump to tomorrow).
    case awaitingMoreMeals
    /// All of today's windows have passed (board looks complete, or evening).
    case closedForToday
    /// Empty / unpublished board before Lunch-probe confidence ("Menu not posted yet").
    case unknown
}

public extension DiningLocation {
    func openState(nowMinutes: Int) -> HallOpenState {
        guard !periods.isEmpty else {
            // Empty today with a known next meal = this hall is dark, not
            // "menu unpublished". Sibling halls often have a full board
            // (Brandywine today, Anteatery tomorrow).
            if opensTomorrowAtMinutes != nil || opensNextAtMinutes != nil {
                return .closedForToday
            }
            // Unpublished / empty board: early morning stays unknown
            // ("Menu not posted yet"). After empty-board confidence (Lunch probe),
            // treat as closed-for-today so Status / Eat / widgets can surface
            // tomorrow / Monday next-open — including weekend daytime, not only
            // after 8 PM.
            if DiningBoardPublish.emptyBoardIsAfterHours(nowMinutes: nowMinutes) {
                return .closedForToday
            }
            return .unknown
        }

        if let current = periods.first(where: { period in
            guard let start = period.startMinutes, let end = period.endMinutes else { return false }
            return nowMinutes >= start && nowMinutes < end
        }), let end = current.endMinutes {
            return .open(period: current.name, closesAt: end)
        }

        let upcoming = periods
            .compactMap { period -> (name: String, start: Int)? in
                guard let start = period.startMinutes, start > nowMinutes else { return nil }
                return (period.name, start)
            }
            .min { $0.start < $1.start }
        if let upcoming {
            return .openingLater(period: upcoming.name, opensAt: upcoming.start)
        }
        if DiningBoardPublish.awaitingLaterMeals(periods: periods, nowMinutes: nowMinutes) {
            return .awaitingMoreMeals
        }
        return .closedForToday
    }

    /// Live serving flag from meal windows — prefer over fetch-time `openNow`
    /// when the hall list has been sitting in memory across a meal boundary.
    func isServing(nowMinutes: Int) -> Bool {
        if case .open = openState(nowMinutes: nowMinutes) { return true }
        return false
    }
}

/// Full nutrition label for a dish, straight from UCI's published data.
/// Everything optional — the feed omits fields for plenty of dishes.
public struct NutritionFacts: Codable, Sendable, Equatable, Hashable {
    public let proteinG: Double?
    public let totalCarbsG: Double?
    public let totalFatG: Double?
    public let saturatedFatG: Double?
    public let transFatG: Double?
    public let sodiumMg: Double?
    public let sugarsG: Double?
    public let dietaryFiberG: Double?
    public let ingredients: String?

    public init(
        proteinG: Double? = nil,
        totalCarbsG: Double? = nil,
        totalFatG: Double? = nil,
        saturatedFatG: Double? = nil,
        transFatG: Double? = nil,
        sodiumMg: Double? = nil,
        sugarsG: Double? = nil,
        dietaryFiberG: Double? = nil,
        ingredients: String? = nil
    ) {
        self.proteinG = proteinG
        self.totalCarbsG = totalCarbsG
        self.totalFatG = totalFatG
        self.saturatedFatG = saturatedFatG
        self.transFatG = transFatG
        self.sodiumMg = sodiumMg
        self.sugarsG = sugarsG
        self.dietaryFiberG = dietaryFiberG
        self.ingredients = ingredients
    }

    /// True when there's at least one macro number worth showing.
    public var hasMacros: Bool {
        proteinG != nil || totalCarbsG != nil || totalFatG != nil
    }

    /// True when the expandable full-label section has anything to list.
    public var hasDetails: Bool {
        hasMacros
            || saturatedFatG != nil
            || transFatG != nil
            || sodiumMg != nil
            || sugarsG != nil
            || dietaryFiberG != nil
            || !(ingredients?.isEmpty ?? true)
    }
}

/// One dish tapped onto today's plate (local Plate Builder).
public struct PlateEntry: Codable, Identifiable, Equatable, Sendable {
    public let id: UUID
    public let dishName: String
    public let calories: Int?
    public let proteinG: Double?

    public init(id: UUID = UUID(), dishName: String, calories: Int?, proteinG: Double?) {
        self.id = id
        self.dishName = dishName
        self.calories = calories
        self.proteinG = proteinG
    }
}

/// Pure plate totals — shared by the app store and kit unit tests.
public enum PlateTotals {
    public static func calories(from entries: [PlateEntry]) -> Int {
        entries.compactMap(\.calories).reduce(0, +)
    }

    public static func proteinGrams(from entries: [PlateEntry]) -> Int {
        Int(entries.compactMap(\.proteinG).reduce(0, +).rounded())
    }
}

/// A single dish on a dining hall menu.
public struct MenuItem: Codable, Sendable, Identifiable, Equatable, Hashable {
    public let id: String
    public let name: String
    public let description: String?
    public let calories: Int?
    public let servingSize: String?
    public let allergens: [String]
    public let dietaryTags: [String]
    /// Full label when the feed provides it; nil keeps old snapshots decodable.
    public let nutrition: NutritionFacts?

    public init(
        id: String,
        name: String,
        description: String?,
        calories: Int?,
        servingSize: String?,
        allergens: [String],
        dietaryTags: [String],
        nutrition: NutritionFacts? = nil
    ) {
        self.id = id
        self.name = name
        self.description = description
        self.calories = calories
        self.servingSize = servingSize
        self.allergens = allergens
        self.dietaryTags = dietaryTags
        self.nutrition = nutrition
    }
}

/// A station (e.g. "The Twisted Root") grouping menu items.
public struct MenuStation: Codable, Sendable, Identifiable, Equatable {
    public let name: String
    public let items: [MenuItem]

    public var id: String { name }

    public init(name: String, items: [MenuItem]) {
        self.name = name
        self.items = items
    }
}

public struct DiningMenu: Codable, Sendable, Equatable {
    public let locationId: String
    /// YYYY-MM-DD (UCI/Pacific).
    public let date: String
    /// Meal-period name, e.g. "Lunch".
    public let period: String
    public let stations: [MenuStation]

    public init(locationId: String, date: String, period: String, stations: [MenuStation]) {
        self.locationId = locationId
        self.date = date
        self.period = period
        self.stations = stations
    }
}

/// Timed campus hours window (Irvine minutes since midnight).
public struct CampusHoursWindow: Codable, Sendable, Equatable {
    public let startMinutes: Int
    public let endMinutes: Int

    public init(startMinutes: Int, endMinutes: Int) {
        self.startMinutes = startMinutes
        self.endMinutes = endMinutes
    }
}

/// A campus retail dining spot (Starbucks, Panda Express, Zot N Go, ...).
public struct CampusPlace: Codable, Sendable, Identifiable, Equatable {
    /// Stable url key from the dining hub, e.g. "starbucks-at-student-center".
    public let id: String
    public let name: String
    /// "Coffee & Cafés" | "Food Courts" | "Markets" | "Restaurants & Pubs".
    public let category: String
    public let openNow: Bool
    /// Human-readable window(s) for today, e.g. "7:30 AM – 4:00 PM", or nil when closed today.
    public let todayHours: String?
    /// True when the venue publishes a menu on the dining hub.
    public let hasMenu: Bool
    /// Minutes-since-midnight of today's next opening still ahead (Irvine).
    /// Set while closed-before-open **and** while open when a later window
    /// remains (split schedules). Nil when done for the day.
    public let opensAtMinutes: Int?
    /// When open: end of the current window (Irvine minutes). Nil when closed,
    /// open 24h, or hours unknown — drives Campus widget reload boundaries.
    public let closesAtMinutes: Int?
    /// When open: start of the current timed window — Opening Alerts catch-up.
    public let currentOpenStartMinutes: Int?
    /// Tomorrow's earliest opening (Irvine), for evening opening-alert schedules
    /// after today's windows have passed. Nil when hours are unknown.
    public let opensTomorrowAtMinutes: Int?
    /// Human-readable window(s) for tomorrow — Opening Alerts overnight body
    /// ("Open 7:30 AM – 4:00 PM") when today's span would be wrong or empty.
    public let tomorrowHours: String?
    /// Every remaining today open window still ahead (split schedules) — Opening
    /// Alerts pre-arms each so afternoon reopens don't wait on a BG refresh.
    public let upcomingWindows: [CampusHoursWindow]
    /// Tomorrow's full open-window chain for overnight Opening Alerts.
    public let tomorrowOpenWindows: [CampusHoursWindow]
    /// True when today's (or tomorrow's) schedule resolved from the feed —
    /// including explicit weekend "off". False when hours are missing/unparseable.
    public let hoursKnown: Bool
    /// Earliest open on the next open day beyond tomorrow (Fri→Mon).
    public let opensNextAtMinutes: Int?
    /// Calendar days from today for `opensNextAtMinutes` (typically 2…7).
    public let opensNextDayOffset: Int?
    /// Weekday name for that later open ("Monday").
    public let opensNextWeekday: String?
    /// Formatted hours for the later open day.
    public let nextOpenHours: String?
    /// Full window chain on the later open day — Opening Alerts pre-arm.
    public let nextOpenWindows: [CampusHoursWindow]

    public init(
        id: String,
        name: String,
        category: String,
        openNow: Bool,
        todayHours: String?,
        hasMenu: Bool = false,
        opensAtMinutes: Int? = nil,
        closesAtMinutes: Int? = nil,
        currentOpenStartMinutes: Int? = nil,
        opensTomorrowAtMinutes: Int? = nil,
        tomorrowHours: String? = nil,
        upcomingWindows: [CampusHoursWindow] = [],
        tomorrowOpenWindows: [CampusHoursWindow] = [],
        hoursKnown: Bool = true,
        opensNextAtMinutes: Int? = nil,
        opensNextDayOffset: Int? = nil,
        opensNextWeekday: String? = nil,
        nextOpenHours: String? = nil,
        nextOpenWindows: [CampusHoursWindow] = []
    ) {
        self.id = id
        self.name = name
        self.category = category
        self.openNow = openNow
        self.todayHours = todayHours
        self.hasMenu = hasMenu
        self.opensAtMinutes = opensAtMinutes
        self.closesAtMinutes = closesAtMinutes
        self.currentOpenStartMinutes = currentOpenStartMinutes
        self.opensTomorrowAtMinutes = opensTomorrowAtMinutes
        self.tomorrowHours = tomorrowHours
        self.upcomingWindows = upcomingWindows
        self.tomorrowOpenWindows = tomorrowOpenWindows
        self.hoursKnown = hoursKnown
        self.opensNextAtMinutes = opensNextAtMinutes
        self.opensNextDayOffset = opensNextDayOffset
        self.opensNextWeekday = opensNextWeekday
        self.nextOpenHours = nextOpenHours
        self.nextOpenWindows = nextOpenWindows
    }

    /// Brand prefix for grouping multi-location chains:
    /// "Starbucks @ Student Center" -> "Starbucks".
    public var brand: String {
        name.components(separatedBy: " @ ").first?.trimmingCharacters(in: .whitespaces) ?? name
    }

    /// Location suffix: "Starbucks @ Student Center" -> "Student Center"; nil for single-name venues.
    public var locationDetail: String? {
        let parts = name.components(separatedBy: " @ ")
        guard parts.count > 1 else { return nil }
        let detail = parts.dropFirst().joined(separator: " @ ").trimmingCharacters(in: .whitespaces)
        return detail.isEmpty ? nil : detail
    }

    /// Live open state from saved windows so a last-known snapshot still
    /// flips Open/Closed at the boundary without waiting on GraphQL.
    public func isOpen(nowMinutes: Int = UCITime.nowMinutes()) -> Bool {
        if let start = currentOpenStartMinutes, let end = closesAtMinutes,
           nowMinutes >= start && nowMinutes < end {
            return true
        }
        if upcomingWindows.contains(where: {
            nowMinutes >= $0.startMinutes && nowMinutes < $0.endMinutes
        }) {
            return true
        }
        if let end = closesAtMinutes, nowMinutes >= end {
            return false
        }
        if let start = currentOpenStartMinutes, nowMinutes < start {
            return false
        }
        if !upcomingWindows.isEmpty {
            return false
        }
        if closesAtMinutes != nil {
            return true
        }
        return openNow
    }
}

public enum BusynessLevel: String, Codable, Sendable {
    case notBusy = "not-busy"
    case busy
    case veryBusy = "very-busy"
    case unknown
}

/// Occupancy for a campus facility — live from Occuspace/Waitz sensors,
/// or a typical-pattern estimate (see `source`).
public struct BusynessPoint: Codable, Sendable, Identifiable, Equatable {
    public let id: Int
    public let name: String
    /// "Recreation" | "Library" | "Dining" | "Campus".
    public let category: String
    public let count: Int?
    public let capacity: Int?
    public let percent: Int?
    public let level: BusynessLevel
    public let isOpen: Bool
    public let hoursSummary: String?
    /// When this snapshot was fetched (live) or computed (typical).
    public let updatedAt: Date
    public let subLocations: [BusynessPoint]?
    /// Live sensor reading vs typical-pattern estimate.
    public let source: BusynessSource

    public init(
        id: Int,
        name: String,
        category: String,
        count: Int?,
        capacity: Int?,
        percent: Int?,
        level: BusynessLevel,
        isOpen: Bool,
        hoursSummary: String?,
        updatedAt: Date,
        subLocations: [BusynessPoint]?,
        source: BusynessSource = .live
    ) {
        self.id = id
        self.name = name
        self.category = category
        self.count = count
        self.capacity = capacity
        self.percent = percent
        self.level = level
        self.isOpen = isOpen
        self.hoursSummary = hoursSummary
        self.updatedAt = updatedAt
        self.subLocations = subLocations
        self.source = source
    }

    /// Waitz `isOpen` reconciled with Closed-until / hour ranges (same as ARC).
    public func isEffectivelyOpen(nowMinutes: Int) -> Bool {
        WaitzHoursSummary.isEffectivelyOpen(
            feedIsOpen: isOpen,
            hoursSummary: hoursSummary,
            nowMinutes: nowMinutes
        )
    }
}

public struct DayHours: Codable, Sendable, Identifiable, Equatable {
    public let day: String
    public let hours: String

    public var id: String { day }

    public init(day: String, hours: String) {
        self.day = day
        self.hours = hours
    }
}

/// Anteater Recreation Center status: busyness (live when tracked, typical
/// estimate otherwise), today's rush curve, and hours.
public struct GymStatus: Codable, Sendable, Equatable {
    public let name: String
    public let openNow: Bool
    public let todayHours: String?
    public let weekHours: [DayHours]
    /// Live sensor point when the feed tracks the ARC; otherwise the typical
    /// estimate (`source == .typical`). Nil only when there is no estimate at all.
    public let busyness: BusynessPoint?
    /// True when hours come from a maintained schedule rather than a live source.
    public let hoursApproximate: Bool
    /// Waitz `Closed until …` reopen (Irvine minutes) when the ARC is closed
    /// with a parseable summary — drives Gym reload + “Opens at …” chrome.
    public let waitzReopenMinutes: Int?
    /// Waitz live-range close (Irvine minutes) when hours come from a parseable
    /// Waitz range — arms Gym reload for holiday / early closes.
    public let waitzCloseMinutes: Int?
    /// Typical 24-hour rush curve for today (index = hour, 0 = closed).
    public let typicalCurve: [Int]?
    /// e.g. "Usually busiest 6–8 PM".
    public let busiestSummary: String?
    /// e.g. "usually quietest around 10 AM".
    public let quietestSummary: String?

    public init(
        name: String,
        openNow: Bool,
        todayHours: String?,
        weekHours: [DayHours],
        busyness: BusynessPoint?,
        hoursApproximate: Bool,
        waitzReopenMinutes: Int? = nil,
        waitzCloseMinutes: Int? = nil,
        typicalCurve: [Int]? = nil,
        busiestSummary: String? = nil,
        quietestSummary: String? = nil
    ) {
        self.name = name
        self.openNow = openNow
        self.todayHours = todayHours
        self.weekHours = weekHours
        self.busyness = busyness
        self.hoursApproximate = hoursApproximate
        self.waitzReopenMinutes = waitzReopenMinutes
        self.waitzCloseMinutes = waitzCloseMinutes
        self.typicalCurve = typicalCurve
        self.busiestSummary = busiestSummary
        self.quietestSummary = quietestSummary
    }
}

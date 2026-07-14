import Foundation

// Domain models for ZotEats — a direct port of the IPC contract in
// renderer/shared/types.ts, shared by all app targets (iOS, macOS).

/// Metadata for dining commons. Hall ids come from the live API, so a new
/// commons appears in the app automatically; this directory only beautifies
/// the names/areas we know, with a sensible fallback for future halls.
public enum HallDirectory {
    static let known: [String: (name: String, area: String)] = [
        "anteatery": ("The Anteatery", "Mesa Court"),
        "brandywine": ("Brandywine", "Middle Earth"),
    ]

    /// Fallback ordering when the live list is unavailable.
    public static let fallbackIDs = ["anteatery", "brandywine"]

    public static func displayName(for id: String) -> String {
        known[id]?.name ?? prettify(id)
    }

    public static func area(for id: String) -> String {
        known[id]?.area ?? "UCI Campus"
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

    public init(
        id: String,
        name: String,
        area: String,
        openNow: Bool,
        todayHours: String?,
        availablePeriods: [String],
        periods: [MealPeriodWindow] = [],
        hoursApproximate: Bool
    ) {
        self.id = id
        self.name = name
        self.area = area
        self.openNow = openNow
        self.todayHours = todayHours
        self.availablePeriods = availablePeriods
        self.periods = periods
        self.hoursApproximate = hoursApproximate
    }
}

/// The hall's live state relative to today's meal windows — the "when" intelligence
/// behind status lines like "Lunch · closes in 1h 10m" or "Dinner starts in 45m".
public enum HallOpenState: Sendable, Equatable {
    /// Serving now; `closesAt` is minutes since midnight Pacific.
    case open(period: String, closesAt: Int)
    /// Between meals or before opening; `opensAt` is minutes since midnight Pacific.
    case openingLater(period: String, opensAt: Int)
    /// All of today's windows have passed.
    case closedForToday
    /// No period data available.
    case unknown
}

public extension DiningLocation {
    func openState(nowMinutes: Int) -> HallOpenState {
        guard !periods.isEmpty else { return .unknown }

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
        return .closedForToday
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

    public init(
        id: String,
        name: String,
        description: String?,
        calories: Int?,
        servingSize: String?,
        allergens: [String],
        dietaryTags: [String]
    ) {
        self.id = id
        self.name = name
        self.description = description
        self.calories = calories
        self.servingSize = servingSize
        self.allergens = allergens
        self.dietaryTags = dietaryTags
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

    public init(
        id: String,
        name: String,
        category: String,
        openNow: Bool,
        todayHours: String?,
        hasMenu: Bool = false
    ) {
        self.id = id
        self.name = name
        self.category = category
        self.openNow = openNow
        self.todayHours = todayHours
        self.hasMenu = hasMenu
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
        self.typicalCurve = typicalCurve
        self.busiestSummary = busiestSummary
        self.quietestSummary = quietestSummary
    }
}

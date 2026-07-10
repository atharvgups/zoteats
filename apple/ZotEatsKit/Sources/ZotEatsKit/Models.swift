import Foundation

// Domain models for ZotEats — a direct port of the IPC contract in
// renderer/shared/types.ts, shared by all app targets (iOS, macOS).

public enum DiningLocationID: String, Codable, Sendable, CaseIterable, Identifiable {
    case anteatery
    case brandywine

    public var id: String { rawValue }

    public var displayName: String {
        switch self {
        case .anteatery: "The Anteatery"
        case .brandywine: "Brandywine"
        }
    }

    public var area: String {
        switch self {
        case .anteatery: "Mesa Court"
        case .brandywine: "Middle Earth"
        }
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
    public let id: DiningLocationID
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
        id: DiningLocationID,
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
    public let locationId: DiningLocationID
    /// YYYY-MM-DD (UCI/Pacific).
    public let date: String
    /// Meal-period name, e.g. "Lunch".
    public let period: String
    public let stations: [MenuStation]

    public init(locationId: DiningLocationID, date: String, period: String, stations: [MenuStation]) {
        self.locationId = locationId
        self.date = date
        self.period = period
        self.stations = stations
    }
}

public enum BusynessLevel: String, Codable, Sendable {
    case notBusy = "not-busy"
    case busy
    case veryBusy = "very-busy"
    case unknown
}

/// Live occupancy for a tracked campus facility (from Occuspace/Waitz).
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
    /// When this snapshot was fetched.
    public let updatedAt: Date
    public let subLocations: [BusynessPoint]?

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
        subLocations: [BusynessPoint]?
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

/// Anteater Recreation Center status: hours + live busyness when available.
public struct GymStatus: Codable, Sendable, Equatable {
    public let name: String
    public let openNow: Bool
    public let todayHours: String?
    public let weekHours: [DayHours]
    /// Nil when the ARC is not present in the live busyness feed.
    public let busyness: BusynessPoint?
    /// True when hours come from a maintained schedule rather than a live source.
    public let hoursApproximate: Bool

    public init(
        name: String,
        openNow: Bool,
        todayHours: String?,
        weekHours: [DayHours],
        busyness: BusynessPoint?,
        hoursApproximate: Bool
    ) {
        self.name = name
        self.openNow = openNow
        self.todayHours = todayHours
        self.weekHours = weekHours
        self.busyness = busyness
        self.hoursApproximate = hoursApproximate
    }
}

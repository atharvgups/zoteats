import Foundation

/// Today's building hours for Langson + Science from UCI LibCal (official
/// library schedule). Waitz often only says `"open"` with no clocks — this
/// fills the neat “8:00 AM – 8:00 PM” line for both libraries.
public struct LibraryBuildingHours: Codable, Equatable, Sendable, Identifiable {
    /// Stable key: `langson` or `science`.
    public let id: String
    public let shortName: String
    /// Normalized span, e.g. `"8:00 AM – 8:00 PM"`, or `"Closed"`.
    public let rendered: String
    public let isOpen: Bool
    public let openMinutes: Int?
    public let closeMinutes: Int?

    public init(
        id: String,
        shortName: String,
        rendered: String,
        isOpen: Bool,
        openMinutes: Int? = nil,
        closeMinutes: Int? = nil
    ) {
        self.id = id
        self.shortName = shortName
        self.rendered = rendered
        self.isOpen = isOpen
        self.openMinutes = openMinutes
        self.closeMinutes = closeMinutes
    }
}

public enum LibraryHoursMatch {
    /// Map a Waitz facility name onto a LibCal building id.
    public static func buildingID(forFacilityName name: String) -> String? {
        let lower = name.lowercased()
        if lower.contains("langson") { return "langson" }
        if lower.contains("science") || lower.contains("sci lib") { return "science" }
        return nil
    }

    public static func hours(
        forFacilityName name: String,
        from all: [LibraryBuildingHours]
    ) -> LibraryBuildingHours? {
        guard let id = buildingID(forFacilityName: name) else { return nil }
        return all.first { $0.id == id }
    }
}

/// Fetch + normalize LibCal “hours today” for the two Study libraries.
public struct LibraryHoursService: Sendable {
    public static let endpoint = URL(string: "https://uci.libcal.com/api_hours_today.php?format=json")!

    private static let locationMap: [(libcalName: String, id: String, shortName: String)] = [
        ("LL - Building", "langson", "Langson"),
        ("SL - Building", "science", "Science"),
    ]

    private let http: any HTTPFetching
    private let cache: TTLCache
    private static let ttl: TimeInterval = 30 * 60

    public init(http: any HTTPFetching = HTTPClient(), cache: TTLCache = TTLCache()) {
        self.http = http
        self.cache = cache
    }

    public func today() async throws -> [LibraryBuildingHours] {
        try await cache.remember("library:hours:today", ttl: Self.ttl) {
            let data = try await http.data(from: Self.endpoint)
            let decoded = try JSONDecoder().decode(LibCalToday.self, from: data)
            let byName = Dictionary(
                uniqueKeysWithValues: (decoded.locations ?? []).compactMap { loc -> (String, LibCalLocation)? in
                    guard let name = loc.name else { return nil }
                    return (name, loc)
                }
            )
            return Self.locationMap.compactMap { entry in
                guard let loc = byName[entry.libcalName] else { return nil }
                return Self.normalize(loc: loc, id: entry.id, shortName: entry.shortName)
            }
        }
    }

    static func normalize(
        loc: LibCalLocation,
        id: String,
        shortName: String
    ) -> LibraryBuildingHours {
        let status = loc.times?.status?.lowercased() ?? ""
        let currentlyOpen = loc.times?.currently_open ?? (status == "open")
        let window = loc.times?.hours?.first
        let openMinutes = window.flatMap { parseClock($0.from) }
        let closeMinutes = window.flatMap { parseClock($0.to) }

        if status == "closed" || (openMinutes == nil && closeMinutes == nil && !currentlyOpen) {
            return LibraryBuildingHours(
                id: id,
                shortName: shortName,
                rendered: "Closed",
                isOpen: false
            )
        }

        let rendered: String = {
            if let openMinutes, let closeMinutes {
                return "\(UCITime.format(minutes: openMinutes)) – \(UCITime.format(minutes: closeMinutes))"
            }
            if let rendered = loc.rendered?.trimmingCharacters(in: .whitespacesAndNewlines),
               !rendered.isEmpty,
               rendered.lowercased() != "closed" {
                return prettyRendered(rendered)
            }
            return currentlyOpen ? "Open" : "Closed"
        }()

        return LibraryBuildingHours(
            id: id,
            shortName: shortName,
            rendered: rendered,
            isOpen: currentlyOpen,
            openMinutes: openMinutes,
            closeMinutes: closeMinutes
        )
    }

    /// `"8am"` / `"8:30pm"` / `"12pm"` → Irvine minutes.
    public static func parseClock(_ raw: String?) -> Int? {
        guard var s = raw?.lowercased().trimmingCharacters(in: .whitespacesAndNewlines),
              !s.isEmpty
        else { return nil }
        s = s.replacingOccurrences(of: " ", with: "")
        let isPM = s.hasSuffix("pm")
        let isAM = s.hasSuffix("am")
        guard isPM || isAM else { return nil }
        s = String(s.dropLast(2))
        let parts = s.split(separator: ":")
        guard let hourPart = parts.first, let hour = Int(hourPart) else { return nil }
        let minute = parts.count > 1 ? Int(parts[1]) ?? 0 : 0
        var h = hour % 12
        if isPM { h += 12 }
        return h * 60 + minute
    }

    /// `"8am - 8pm"` → `"8:00 AM – 8:00 PM"` when parseable.
    public static func prettyRendered(_ raw: String) -> String {
        let cleaned = raw
            .replacingOccurrences(of: "–", with: "-")
            .replacingOccurrences(of: "—", with: "-")
        let parts = cleaned.split(separator: "-").map {
            $0.trimmingCharacters(in: .whitespacesAndNewlines)
        }
        guard parts.count == 2,
              let open = parseClock(parts[0]),
              let close = parseClock(parts[1])
        else { return raw }
        return "\(UCITime.format(minutes: open)) – \(UCITime.format(minutes: close))"
    }

    // MARK: - LibCal JSON

    struct LibCalToday: Decodable, Sendable {
        let locations: [LibCalLocation]?
    }

    struct LibCalLocation: Decodable, Sendable {
        let name: String?
        let rendered: String?
        let times: LibCalTimes?
    }

    struct LibCalTimes: Decodable, Sendable {
        let status: String?
        let currently_open: Bool?
        let hours: [LibCalWindow]?
    }

    struct LibCalWindow: Decodable, Sendable {
        let from: String?
        let to: String?
    }
}

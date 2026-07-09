import Foundation

// Live campus busyness from UCI's Occuspace/Waitz public feed.
// Port of main/services/occuspace.ts.
// GET https://waitz.io/live/irvine
// -> { data: [{ id, name, busyness, people, capacity, isOpen, isAvailable, hourSummary, subLocs[] }] }

public struct BusynessService: Sendable {
    private static let feedURL = URL(string: "https://waitz.io/live/irvine")!
    private static let ttl: TimeInterval = 60

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

    private struct RawFacility: Decodable, Sendable {
        let id: Int?
        let name: String?
        let busyness: Double?
        let people: Int?
        let capacity: Int?
        let isAvailable: Bool?
        let isOpen: Bool?
        let hourSummary: String?
        let subLocs: [RawFacility]?
    }

    private struct RawResponse: Decodable, Sendable {
        let data: [RawFacility]?
    }

    // MARK: - Normalization

    static func categorize(_ name: String) -> String {
        let lowered = name.lowercased()
        if lowered.range(of: #"(arc|recreation|gym|fitness|crawford|track|pool)"#, options: .regularExpression) != nil {
            return "Recreation"
        }
        if lowered.range(of: #"(library|libraries|langson|science|gateway|grunigen|multimedia|ayala)"#, options: .regularExpression) != nil {
            return "Library"
        }
        if lowered.range(of: #"(commons|anteatery|brandywine|dining|eatery|cafe)"#, options: .regularExpression) != nil {
            return "Dining"
        }
        return "Campus"
    }

    static func level(forPercent percent: Int?) -> BusynessLevel {
        guard let percent else { return .unknown }
        if percent <= 45 { return .notBusy }
        if percent <= 80 { return .busy }
        return .veryBusy
    }

    private static func normalize(_ raw: RawFacility, updatedAt: Date) -> BusynessPoint {
        let capacity = raw.capacity
        let count = raw.people

        var percent: Int? = raw.busyness.map { Int($0.rounded()) }
        if percent == nil, let count, let capacity, capacity > 0 {
            percent = Int((Double(count) / Double(capacity) * 100).rounded())
        }
        if let value = percent {
            percent = max(0, min(100, value))
        }

        let name = raw.name?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        let displayName = name.isEmpty ? "Unknown" : name
        let subs = (raw.subLocs ?? []).map { normalize($0, updatedAt: updatedAt) }

        return BusynessPoint(
            id: raw.id ?? -1,
            name: displayName,
            category: categorize(displayName),
            count: count,
            capacity: capacity,
            percent: percent,
            level: level(forPercent: percent),
            isOpen: raw.isOpen ?? raw.isAvailable ?? false,
            hoursSummary: {
                let trimmed = raw.hourSummary?.trimmingCharacters(in: .whitespacesAndNewlines)
                return (trimmed?.isEmpty ?? true) ? nil : trimmed
            }(),
            updatedAt: updatedAt,
            subLocations: subs.isEmpty ? nil : subs
        )
    }

    // MARK: - Public API

    /// All facilities the UCI Occuspace/Waitz feed currently tracks.
    public func all() async throws -> [BusynessPoint] {
        try await cache.remember("busyness:irvine", ttl: Self.ttl) {
            let raw = try await http.json(RawResponse.self, from: Self.feedURL)
            let updatedAt = now()
            return (raw.data ?? []).map { Self.normalize($0, updatedAt: updatedAt) }
        }
    }

    /// Locate the ARC within the tracked facilities, if the feed includes it.
    public static func findArc(in points: [BusynessPoint]) -> BusynessPoint? {
        points.first { point in
            point.name.range(of: #"\barc\b|recreation"#, options: [.regularExpression, .caseInsensitive]) != nil
                || point.category == "Recreation"
        }
    }
}

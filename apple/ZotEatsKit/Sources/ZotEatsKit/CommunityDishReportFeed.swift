import Foundation

/// Shared dish-wrong reports. The phone POSTs `repository_dispatch` only
/// (`dish-report` / `dish-feedback`). GitHub Actions merges the JSON and
/// forwards Atharv's webhook. The write token never calls Contents.
public enum CommunityDishReportFeed {
    public static let cacheKey = "zoteats.communityDishReports"
    public static let feedURL = URL(
        string: "https://raw.githubusercontent.com/atharvgups/zoteats/main/apple/community-dish-reports.json"
    )!
    public static let liveURL = feedURL
    public static let ingestURL = GitHubIngest.dispatchURL

    public struct Payload: Codable, Equatable, Sendable {
        public var reports: [DishReport]

        public init(reports: [DishReport] = []) {
            self.reports = reports
        }
    }

    public static func encode(_ reports: [DishReport]) -> Data {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = [.sortedKeys]
        let payload = Payload(reports: reports.sorted { $0.updatedAt > $1.updatedAt })
        return (try? encoder.encode(payload)) ?? Data("{\"reports\":[]}".utf8)
    }

    public static func decode(_ data: Data) -> [DishReport] {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        if let payload = try? decoder.decode(Payload.self, from: data) {
            return payload.reports
        }
        if let reports = try? decoder.decode([DishReport].self, from: data) {
            return reports
        }
        return []
    }

    public static func merge(cached: [DishReport], remote: [DishReport]) -> [DishReport] {
        var byID: [String: DishReport] = [:]
        for report in cached + remote {
            let existing = byID[report.id]
            if let existing, existing.updatedAt > report.updatedAt { continue }
            byID[report.id] = report
        }
        return Array(byID.values).sorted { $0.updatedAt > $1.updatedAt }
    }

    public static func cachedReports() -> [DishReport] {
        guard let data = SharedDefaults.suite.data(forKey: cacheKey)
            ?? UserDefaults.standard.data(forKey: cacheKey)
        else { return [] }
        return decode(data)
    }

    public static func persist(_ reports: [DishReport]) {
        let data = encode(reports)
        SharedDefaults.suite.set(data, forKey: cacheKey)
        UserDefaults.standard.set(data, forKey: cacheKey)
    }

    public static func fetch(
        http: any HTTPFetching,
        url: URL = liveURL
    ) async -> [DishReport] {
        let cached = cachedReports()
        let live = await load(http: http, url: url)
        let fallback = live == nil ? await load(http: http, url: feedURL) : nil
        let remote = live ?? fallback ?? []
        let merged = merge(cached: cached, remote: remote)
        persist(merged)
        return merged
    }

    /// Dispatches a listing flag. Returns the merged cache. `published` is true
    /// only after GitHub accepted the event; otherwise the row is queued.
    public static func submit(
        http: any HTTPFetching,
        date: String,
        hall: String,
        meal: String,
        dishID: String,
        dishName: String,
        reason: DishReportReason,
        authorID: String,
        now: Date = Date(),
        url: URL = liveURL,
        writeToken: String = CommunityReviewFeed.writeToken,
        defaults: UserDefaults = SharedDefaults.suite,
        enqueueOnFailure: Bool = true
    ) async -> (reports: [DishReport], published: Bool) {
        let cached = cachedReports()
        let loaded = await load(http: http, url: url)
        let remote = loaded ?? cached
        let published = await GitHubIngest.dispatch(
            http: http,
            eventType: "dish-report",
            payload: OutboundIngestQueue.DishReportPayload(
                date: date,
                hall: hall,
                meal: meal,
                dishID: dishID,
                dishName: dishName,
                reason: reason.rawValue,
                authorID: authorID,
                updatedAt: iso8601(now)
            ),
            writeToken: writeToken
        )
        if published {
            let next = DishReportLogic.upsert(
                existing: remote,
                date: date,
                hall: hall,
                meal: meal,
                dishID: dishID,
                dishName: dishName,
                reason: reason,
                authorID: authorID,
                now: now
            )
            let merged = merge(cached: cached, remote: next)
            persist(merged)
            DishFeedbackLogic.markNoted(
                date: date,
                hall: hall,
                meal: meal,
                dishID: dishID,
                dishName: dishName,
                defaults: defaults
            )
            return (merged, true)
        }
        if enqueueOnFailure {
            OutboundIngestQueue.enqueue(
                OutboundIngestQueue.dishReportItem(
                    date: date,
                    hall: hall,
                    meal: meal,
                    dishID: dishID,
                    dishName: dishName,
                    reason: reason,
                    authorID: authorID,
                    updatedAt: now
                ),
                defaults: defaults
            )
        }
        let merged = merge(cached: cached, remote: remote)
        persist(merged)
        return (merged, false)
    }

    /// Forwards an Other note. The webhook URL and key never leave Actions.
    public static func submitFeedback(
        http: any HTTPFetching,
        date: String,
        hall: String,
        meal: String,
        dishID: String,
        dishName: String,
        text: String,
        authorID: String,
        now: Date = Date(),
        writeToken: String = CommunityReviewFeed.writeToken,
        defaults: UserDefaults = SharedDefaults.suite,
        enqueueOnFailure: Bool = true
    ) async -> Bool {
        let clipped = DishFeedbackLogic.clipped(text)
        guard !clipped.isEmpty else { return false }
        let published = await GitHubIngest.dispatch(
            http: http,
            eventType: "dish-feedback",
            payload: OutboundIngestQueue.DishFeedbackPayload(
                date: date,
                hall: hall,
                meal: meal,
                dishID: dishID,
                dishName: dishName,
                reason: DishReportReason.other.rawValue,
                text: clipped,
                authorID: authorID,
                updatedAt: iso8601(now)
            ),
            writeToken: writeToken
        )
        if published {
            DishFeedbackLogic.markNoted(
                date: date,
                hall: hall,
                meal: meal,
                dishID: dishID,
                dishName: dishName,
                defaults: defaults
            )
            return true
        }
        if enqueueOnFailure {
            OutboundIngestQueue.enqueue(
                OutboundIngestQueue.dishFeedbackItem(
                    date: date,
                    hall: hall,
                    meal: meal,
                    dishID: dishID,
                    dishName: dishName,
                    text: clipped,
                    authorID: authorID,
                    updatedAt: now
                ),
                defaults: defaults
            )
        }
        return false
    }

    private static func load(http: any HTTPFetching, url: URL) async -> [DishReport]? {
        do {
            let data = try await http.data(from: url)
            return decode(data)
        } catch {
            return nil
        }
    }

    private static func iso8601(_ date: Date) -> String {
        let iso = ISO8601DateFormatter()
        iso.formatOptions = [.withInternetDateTime]
        return iso.string(from: date)
    }
}

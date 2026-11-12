import Foundation

/// Shared dish reviews — GitHub JSON is the durable public feed, and the same
/// payload is the live read/write document when `liveURL` is reachable.
/// Personal "You" ratings stay on-device and are published into this feed.
public enum CommunityReviewFeed {
    public static let cacheKey = "zoteats.communityMealReviews"
    public static let feedURL = URL(
        string: "https://raw.githubusercontent.com/atharvgups/zoteats/main/apple/community-reviews.json"
    )!
    /// Same document the app writes. Falls back to `feedURL` when this host misses.
    public static let liveURL = URL(
        string: "https://raw.githubusercontent.com/atharvgups/zoteats/main/apple/community-reviews.json"
    )!
    public static let ingestURL = GitHubIngest.dispatchURL

    public static var writeToken: String {
        if let env = ProcessInfo.processInfo.environment["ZOTEATS_REVIEWS_TOKEN"], !env.isEmpty {
            return env
        }
        if let bundled = Bundle.main.object(forInfoDictionaryKey: "ZotEatsReviewsToken") as? String,
           !bundled.isEmpty {
            return bundled
        }
        return ""
    }

    public struct Payload: Codable, Equatable, Sendable {
        public var reviews: [MealReview]

        public init(reviews: [MealReview] = []) {
            self.reviews = reviews
        }
    }

    public static func encode(_ reviews: [MealReview]) -> Data {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = [.sortedKeys]
        let payload = Payload(reviews: MealReviewLogic.sortedForDisplay(reviews))
        return (try? encoder.encode(payload)) ?? Data("{}".utf8)
    }

    public static func decode(_ data: Data) -> [MealReview] {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        if let payload = try? decoder.decode(Payload.self, from: data) {
            return MealReviewLogic.sortedForDisplay(payload.reviews)
        }
        if let reviews = try? decoder.decode([MealReview].self, from: data) {
            return MealReviewLogic.sortedForDisplay(reviews)
        }
        return []
    }

    /// Remote + cached community reviews, excluding the current reviewer.
    public static func merge(
        cached: [MealReview],
        remote: [MealReview],
        excludingAuthorID: String
    ) -> [MealReview] {
        var byID: [String: MealReview] = [:]
        for review in cached + remote {
            let author = review.resolvedAuthorID
            guard author != excludingAuthorID else { continue }
            byID[review.id] = review
        }
        return MealReviewLogic.sortedForDisplay(Array(byID.values))
    }

    public static func cachedReviews() -> [MealReview] {
        guard let data = SharedDefaults.suite.data(forKey: cacheKey)
            ?? UserDefaults.standard.data(forKey: cacheKey)
        else { return [] }
        return decode(data)
    }

    public static func persist(_ reviews: [MealReview]) {
        let data = encode(reviews)
        SharedDefaults.suite.set(data, forKey: cacheKey)
        UserDefaults.standard.set(data, forKey: cacheKey)
    }

    public static func fetch(
        http: any HTTPFetching,
        excludingAuthorID: String,
        url: URL = liveURL
    ) async -> [MealReview] {
        let cached = cachedReviews()
        let live = await load(http: http, url: url)
        let fallback = live == nil ? await load(http: http, url: feedURL) : nil
        let remote = live ?? fallback ?? []
        let merged = merge(cached: cached, remote: remote, excludingAuthorID: excludingAuthorID)
        persist(merged)
        return merged
    }

    /// Upsert or remove this author's review on the shared feed, then cache others.
    /// Returns the public cache (this author excluded). `published` is true only
    /// after GitHub accepted the event; otherwise the rating is queued.
    @discardableResult
    public static func submit(
        http: any HTTPFetching,
        dishName: String,
        stars: Int,
        note: String,
        authorID: String,
        authorLabel: String,
        excludingAuthorID: String,
        now: Date = Date(),
        url: URL = liveURL,
        writeToken: String = CommunityReviewFeed.writeToken,
        defaults: UserDefaults = SharedDefaults.suite,
        enqueueOnFailure: Bool = true
    ) async -> (reviews: [MealReview], published: Bool) {
        let cached = cachedReviews()
        let loaded = await load(http: http, url: url)
        let remote = loaded ?? cached
        let next: [MealReview]
        if stars <= 0 {
            next = MealReviewLogic.remove(
                existing: remote,
                dishName: dishName,
                authorID: authorID
            )
        } else {
            next = MealReviewLogic.upsert(
                existing: remote,
                dishName: dishName,
                stars: stars,
                note: note,
                now: now,
                authorID: authorID,
                authorLabel: authorLabel
            )
        }
        let published = await GitHubIngest.dispatch(
            http: http,
            eventType: "meal-review",
            payload: OutboundIngestQueue.MealReviewPayload(
                dishName: dishName,
                stars: stars,
                note: note,
                authorID: authorID,
                authorLabel: authorLabel,
                updatedAt: iso8601(now)
            ),
            writeToken: writeToken
        )
        if published {
            let merged = merge(cached: cached, remote: next, excludingAuthorID: excludingAuthorID)
            persist(merged)
            return (merged, true)
        }
        if enqueueOnFailure {
            OutboundIngestQueue.enqueue(
                OutboundIngestQueue.mealReviewItem(
                    dishName: dishName,
                    stars: stars,
                    note: note,
                    authorID: authorID,
                    authorLabel: authorLabel,
                    updatedAt: now
                ),
                defaults: defaults
            )
        }
        let merged = merge(cached: cached, remote: remote, excludingAuthorID: excludingAuthorID)
        persist(merged)
        return (merged, false)
    }

    private static func load(http: any HTTPFetching, url: URL) async -> [MealReview]? {
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

/// Caption for the community average on a dish sheet.
public enum CommunityReviewCopy {
    public static func averageLine(average: Double, count: Int) -> String {
        let rounded = (average * 10).rounded() / 10
        let stars = rounded == floor(rounded)
            ? String(Int(rounded))
            : String(format: "%.1f", rounded)
        if count == 1 {
            return "\(stars) · 1 review"
        }
        return "\(stars) · \(max(count, 0)) reviews"
    }

    public static let communityHeader = "Community reviews"
    public static let empty = "No community reviews yet."
    public static let yourRating = "Your rating"
    public static let reviewPlaceholder = "Write a short review"
}

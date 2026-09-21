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
    /// GitHub Contents API for the same community-reviews.json document.
    public static let githubContentsURL = URL(
        string: "https://api.github.com/repos/atharvgups/zoteats/contents/apple/community-reviews.json"
    )!
    public static let ingestURL = URL(
        string: "https://api.github.com/repos/atharvgups/zoteats/dispatches"
    )!

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
    public static func submit(
        http: any HTTPFetching,
        dishName: String,
        stars: Int,
        note: String,
        authorID: String,
        authorLabel: String,
        excludingAuthorID: String,
        now: Date = Date(),
        url: URL = liveURL
    ) async -> [MealReview] {
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
        do {
            _ = try await http.send(
                method: "PUT",
                url: url,
                headers: ["Content-Type": "application/json", "Accept": "application/json"],
                body: encode(next)
            )
        } catch {
            var ingested = await postIfPutRejected(http: http, url: url, body: encode(next))
            if !ingested {
                ingested = await submitGitHubContents(http: http, reviews: next)
            }
            if !ingested {
                ingested = await dispatchGitHubIngest(
                    http: http,
                    dishName: dishName,
                    stars: stars,
                    note: note,
                    authorID: authorID,
                    authorLabel: authorLabel,
                    updatedAt: now
                )
            }
            if !ingested {
                let merged = merge(cached: cached, remote: remote, excludingAuthorID: excludingAuthorID)
                persist(merged)
                return merged
            }
        }
        let merged = merge(cached: cached, remote: next, excludingAuthorID: excludingAuthorID)
        persist(merged)
        return merged
    }

    private static func load(http: any HTTPFetching, url: URL) async -> [MealReview]? {
        do {
            let data = try await http.data(from: url)
            return decode(data)
        } catch {
            return nil
        }
    }

    private static func postIfPutRejected(http: any HTTPFetching, url: URL, body: Data) async -> Bool {
        do {
            _ = try await http.send(
                method: "POST",
                url: url,
                headers: ["Content-Type": "application/json", "Accept": "application/json"],
                body: body
            )
            return true
        } catch {
            return false
        }
    }

    private static func submitGitHubContents(
        http: any HTTPFetching,
        reviews: [MealReview]
    ) async -> Bool {
        let token = writeToken.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !token.isEmpty else { return false }
        let auth = [
            "Accept": "application/vnd.github+json",
            "Authorization": "Bearer \(token)",
            "X-GitHub-Api-Version": "2022-11-28",
        ]
        var sha: String?
        if let data = try? await http.data(from: githubContentsURL, headers: auth),
           let meta = try? JSONDecoder().decode(GitHubContentsMeta.self, from: data) {
            sha = meta.sha
        }
        let body = GitHubContentsPut(
            message: "chore(reviews): publish community dish rating",
            content: encode(reviews).base64EncodedString(),
            sha: sha,
            branch: "main"
        )
        guard let payload = try? JSONEncoder().encode(body) else { return false }
        do {
            _ = try await http.send(
                method: "PUT",
                url: githubContentsURL,
                headers: auth.merging(["Content-Type": "application/json"]) { _, new in new },
                body: payload
            )
            return true
        } catch {
            return false
        }
    }

    private static func dispatchGitHubIngest(
        http: any HTTPFetching,
        dishName: String,
        stars: Int,
        note: String,
        authorID: String,
        authorLabel: String,
        updatedAt: Date
    ) async -> Bool {
        let token = writeToken.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !token.isEmpty else { return false }
        let iso = ISO8601DateFormatter()
        iso.formatOptions = [.withInternetDateTime]
        let envelope = IngestEnvelope(
            event_type: "meal-review",
            client_payload: IngestPayload(
                dishName: dishName,
                stars: stars,
                note: note,
                authorID: authorID,
                authorLabel: authorLabel,
                updatedAt: iso.string(from: updatedAt)
            )
        )
        guard let body = try? JSONEncoder().encode(envelope) else { return false }
        do {
            _ = try await http.send(
                method: "POST",
                url: ingestURL,
                headers: [
                    "Accept": "application/vnd.github+json",
                    "Content-Type": "application/json",
                    "Authorization": "Bearer \(token)",
                    "X-GitHub-Api-Version": "2022-11-28",
                ],
                body: body
            )
            return true
        } catch {
            return false
        }
    }

    private struct GitHubContentsMeta: Decodable, Sendable {
        var sha: String?
    }

    private struct GitHubContentsPut: Encodable, Sendable {
        var message: String
        var content: String
        var sha: String?
        var branch: String

        enum CodingKeys: String, CodingKey {
            case message, content, sha, branch
        }

        func encode(to encoder: Encoder) throws {
            var container = encoder.container(keyedBy: CodingKeys.self)
            try container.encode(message, forKey: .message)
            try container.encode(content, forKey: .content)
            try container.encode(branch, forKey: .branch)
            try container.encodeIfPresent(sha, forKey: .sha)
        }
    }

    private struct IngestEnvelope: Encodable, Sendable {
        var event_type: String
        var client_payload: IngestPayload
    }

    private struct IngestPayload: Encodable, Sendable {
        var dishName: String
        var stars: Int
        var note: String
        var authorID: String
        var authorLabel: String
        var updatedAt: String
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

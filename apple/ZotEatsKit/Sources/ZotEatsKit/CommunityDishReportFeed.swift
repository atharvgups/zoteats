import Foundation

/// Shared dish-wrong reports. Same GitHub backend as community ratings
/// (`ZOTEATS_REVIEWS_TOKEN`, Contents API, repository_dispatch), separate
/// document so a 1.0.361 rating publish cannot wipe flags.
public enum CommunityDishReportFeed {
    public static let cacheKey = "zoteats.communityDishReports"
    public static let feedURL = URL(
        string: "https://raw.githubusercontent.com/atharvgups/zoteats/main/apple/community-dish-reports.json"
    )!
    public static let liveURL = feedURL
    public static let githubContentsURL = URL(
        string: "https://api.github.com/repos/atharvgups/zoteats/contents/apple/community-dish-reports.json"
    )!
    public static let ingestURL = CommunityReviewFeed.ingestURL

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
        url: URL = liveURL
    ) async -> [DishReport] {
        let cached = cachedReports()
        let loaded = await load(http: http, url: url)
        let remote = loaded ?? cached
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
        let body = encode(next)
        var published = false
        do {
            _ = try await http.send(
                method: "PUT",
                url: url,
                headers: ["Content-Type": "application/json", "Accept": "application/json"],
                body: body
            )
            published = true
        } catch {
            published = await submitGitHubContents(http: http, reports: next)
            if !published {
                published = await dispatchGitHubIngest(
                    http: http,
                    date: date,
                    hall: hall,
                    meal: meal,
                    dishID: dishID,
                    dishName: dishName,
                    reason: reason,
                    authorID: authorID,
                    updatedAt: now
                )
            }
        }
        let merged = merge(cached: cached, remote: published ? next : remote)
        persist(merged)
        return merged
    }

    private static func load(http: any HTTPFetching, url: URL) async -> [DishReport]? {
        do {
            let data = try await http.data(from: url)
            return decode(data)
        } catch {
            return nil
        }
    }

    private static func submitGitHubContents(
        http: any HTTPFetching,
        reports: [DishReport]
    ) async -> Bool {
        let token = CommunityReviewFeed.writeToken.trimmingCharacters(in: .whitespacesAndNewlines)
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
            message: "chore(reports): publish community dish flag",
            content: encode(reports).base64EncodedString(),
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
        date: String,
        hall: String,
        meal: String,
        dishID: String,
        dishName: String,
        reason: DishReportReason,
        authorID: String,
        updatedAt: Date
    ) async -> Bool {
        let token = CommunityReviewFeed.writeToken.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !token.isEmpty else { return false }
        let iso = ISO8601DateFormatter()
        iso.formatOptions = [.withInternetDateTime]
        let envelope = IngestEnvelope(
            event_type: "dish-report",
            client_payload: IngestPayload(
                date: date,
                hall: hall,
                meal: meal,
                dishID: dishID,
                dishName: dishName,
                reason: reason.rawValue,
                authorID: authorID,
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
        var date: String
        var hall: String
        var meal: String
        var dishID: String
        var dishName: String
        var reason: String
        var authorID: String
        var updatedAt: String
    }
}

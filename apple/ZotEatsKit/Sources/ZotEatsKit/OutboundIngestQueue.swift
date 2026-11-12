import Foundation

/// One report, Other note, or rating that has not yet reached GitHub.
public struct OutboundIngestItem: Codable, Equatable, Sendable, Identifiable {
    public var id: String
    public var kind: Kind
    public var date: String
    public var hall: String
    public var meal: String
    public var dishID: String
    public var dishName: String
    public var reason: String
    public var text: String
    public var authorID: String
    public var authorLabel: String
    public var stars: Int
    public var updatedAt: Date
    public var attempts: Int

    public enum Kind: String, Codable, Sendable {
        case dishReport
        case dishFeedback
        case mealReview
    }

    public init(
        id: String = UUID().uuidString,
        kind: Kind,
        date: String = "",
        hall: String = "",
        meal: String = "",
        dishID: String = "",
        dishName: String = "",
        reason: String = "",
        text: String = "",
        authorID: String = "",
        authorLabel: String = "",
        stars: Int = 0,
        updatedAt: Date = Date(),
        attempts: Int = 0
    ) {
        self.id = id
        self.kind = kind
        self.date = date
        self.hall = hall
        self.meal = meal
        self.dishID = dishID
        self.dishName = dishName
        self.reason = reason
        self.text = text
        self.authorID = authorID
        self.authorLabel = authorLabel
        self.stars = stars
        self.updatedAt = updatedAt
        self.attempts = attempts
    }

    public var dedupeKey: String {
        switch kind {
        case .dishReport:
            return "dishReport|\(DishReportLogic.reportID(date: date, hall: hall, meal: meal, dishID: dishID, dishName: dishName, authorID: authorID))"
        case .dishFeedback:
            return "dishFeedback|\(DishReportLogic.listingKey(date: date, hall: hall, meal: meal, dishID: dishID, dishName: dishName))|\(authorID)"
        case .mealReview:
            return "mealReview|\(MealReview.key(for: dishName))|\(authorID)"
        }
    }
}

public struct OutboundIngestFlushResult: Equatable, Sendable {
    public var sent: Int
    public var remaining: Int

    public init(sent: Int, remaining: Int) {
        self.sent = sent
        self.remaining = remaining
    }
}

/// Durable outbox so a failed dispatch is retried on the next launch or
/// network instead of showing Thanks, noted for a report that never left.
public enum OutboundIngestQueue {
    public static let storageKey = "zoteats.outboundIngestQueue"

    public static func load(defaults: UserDefaults = SharedDefaults.suite) -> [OutboundIngestItem] {
        guard let data = defaults.data(forKey: storageKey)
            ?? UserDefaults.standard.data(forKey: storageKey)
        else { return [] }
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return (try? decoder.decode([OutboundIngestItem].self, from: data)) ?? []
    }

    public static func save(_ items: [OutboundIngestItem], defaults: UserDefaults = SharedDefaults.suite) {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = [.sortedKeys]
        let data = (try? encoder.encode(items)) ?? Data("[]".utf8)
        defaults.set(data, forKey: storageKey)
        UserDefaults.standard.set(data, forKey: storageKey)
    }

    public static func enqueue(
        _ item: OutboundIngestItem,
        defaults: UserDefaults = SharedDefaults.suite
    ) {
        var items = load(defaults: defaults).filter { $0.dedupeKey != item.dedupeKey }
        items.append(item)
        save(items, defaults: defaults)
    }

    @discardableResult
    public static func flush(
        http: any HTTPFetching,
        writeToken: String = CommunityReviewFeed.writeToken,
        defaults: UserDefaults = SharedDefaults.suite,
        now: Date = Date()
    ) async -> OutboundIngestFlushResult {
        let pending = load(defaults: defaults)
        guard !pending.isEmpty else {
            return OutboundIngestFlushResult(sent: 0, remaining: 0)
        }
        var remaining: [OutboundIngestItem] = []
        var sent = 0
        for item in pending {
            if await dispatch(item, http: http, writeToken: writeToken) {
                applySuccess(item, now: now, defaults: defaults)
                sent += 1
            } else {
                var next = item
                next.attempts += 1
                remaining.append(next)
            }
        }
        save(remaining, defaults: defaults)
        return OutboundIngestFlushResult(sent: sent, remaining: remaining.count)
    }

    public static func dishReportItem(
        date: String,
        hall: String,
        meal: String,
        dishID: String,
        dishName: String,
        reason: DishReportReason,
        authorID: String,
        updatedAt: Date = Date()
    ) -> OutboundIngestItem {
        OutboundIngestItem(
            kind: .dishReport,
            date: date,
            hall: hall,
            meal: meal,
            dishID: dishID,
            dishName: dishName,
            reason: reason.rawValue,
            authorID: authorID,
            updatedAt: updatedAt
        )
    }

    public static func dishFeedbackItem(
        date: String,
        hall: String,
        meal: String,
        dishID: String,
        dishName: String,
        text: String,
        authorID: String,
        updatedAt: Date = Date()
    ) -> OutboundIngestItem {
        OutboundIngestItem(
            kind: .dishFeedback,
            date: date,
            hall: hall,
            meal: meal,
            dishID: dishID,
            dishName: dishName,
            reason: DishReportReason.other.rawValue,
            text: text,
            authorID: authorID,
            updatedAt: updatedAt
        )
    }

    public static func mealReviewItem(
        dishName: String,
        stars: Int,
        note: String,
        authorID: String,
        authorLabel: String,
        updatedAt: Date = Date()
    ) -> OutboundIngestItem {
        OutboundIngestItem(
            kind: .mealReview,
            dishName: dishName,
            text: note,
            authorID: authorID,
            authorLabel: authorLabel,
            stars: stars,
            updatedAt: updatedAt
        )
    }

    private static func dispatch(
        _ item: OutboundIngestItem,
        http: any HTTPFetching,
        writeToken: String
    ) async -> Bool {
        let iso = ISO8601DateFormatter()
        iso.formatOptions = [.withInternetDateTime]
        let updatedAt = iso.string(from: item.updatedAt)
        switch item.kind {
        case .dishReport:
            return await GitHubIngest.dispatch(
                http: http,
                eventType: "dish-report",
                payload: DishReportPayload(
                    date: item.date,
                    hall: item.hall,
                    meal: item.meal,
                    dishID: item.dishID,
                    dishName: item.dishName,
                    reason: item.reason,
                    authorID: item.authorID,
                    updatedAt: updatedAt
                ),
                writeToken: writeToken
            )
        case .dishFeedback:
            return await GitHubIngest.dispatch(
                http: http,
                eventType: "dish-feedback",
                payload: DishFeedbackPayload(
                    date: item.date,
                    hall: item.hall,
                    meal: item.meal,
                    dishID: item.dishID,
                    dishName: item.dishName,
                    reason: item.reason.isEmpty ? DishReportReason.other.rawValue : item.reason,
                    text: item.text,
                    authorID: item.authorID,
                    updatedAt: updatedAt
                ),
                writeToken: writeToken
            )
        case .mealReview:
            return await GitHubIngest.dispatch(
                http: http,
                eventType: "meal-review",
                payload: MealReviewPayload(
                    dishName: item.dishName,
                    stars: item.stars,
                    note: item.text,
                    authorID: item.authorID,
                    authorLabel: item.authorLabel,
                    updatedAt: updatedAt
                ),
                writeToken: writeToken
            )
        }
    }

    private static func applySuccess(
        _ item: OutboundIngestItem,
        now: Date,
        defaults: UserDefaults
    ) {
        switch item.kind {
        case .dishReport:
            guard let reason = DishReportReason(rawValue: item.reason) else { return }
            let next = DishReportLogic.upsert(
                existing: CommunityDishReportFeed.cachedReports(),
                date: item.date,
                hall: item.hall,
                meal: item.meal,
                dishID: item.dishID,
                dishName: item.dishName,
                reason: reason,
                authorID: item.authorID,
                now: item.updatedAt
            )
            CommunityDishReportFeed.persist(next)
            DishFeedbackLogic.markNoted(
                date: item.date,
                hall: item.hall,
                meal: item.meal,
                dishID: item.dishID,
                dishName: item.dishName,
                defaults: defaults
            )
        case .dishFeedback:
            DishFeedbackLogic.markNoted(
                date: item.date,
                hall: item.hall,
                meal: item.meal,
                dishID: item.dishID,
                dishName: item.dishName,
                defaults: defaults
            )
        case .mealReview:
            break
        }
        _ = now
    }

    struct DishReportPayload: Encodable, Sendable {
        var date: String
        var hall: String
        var meal: String
        var dishID: String
        var dishName: String
        var reason: String
        var authorID: String
        var updatedAt: String
    }

    struct DishFeedbackPayload: Encodable, Sendable {
        var date: String
        var hall: String
        var meal: String
        var dishID: String
        var dishName: String
        var reason: String
        var text: String
        var authorID: String
        var updatedAt: String
    }

    struct MealReviewPayload: Encodable, Sendable {
        var dishName: String
        var stars: Int
        var note: String
        var authorID: String
        var authorLabel: String
        var updatedAt: String
    }
}

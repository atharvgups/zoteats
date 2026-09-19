import Foundation

/// Community (other people) dish reviews — list + average, separate from the
/// on-device "You" rating. Fetched from the public feed and cached locally
/// under a stable, unversioned key.
public enum CommunityReviewFeed {
    public static let cacheKey = "zoteats.communityMealReviews"
    public static let feedURL = URL(
        string: "https://raw.githubusercontent.com/atharvgups/zoteats/main/apple/community-reviews.json"
    )!

    public struct Payload: Codable, Equatable, Sendable {
        public var reviews: [MealReview]

        public init(reviews: [MealReview] = []) {
            self.reviews = reviews
        }
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
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        let payload = Payload(reviews: MealReviewLogic.sortedForDisplay(reviews))
        let data = (try? encoder.encode(payload)) ?? Data()
        SharedDefaults.suite.set(data, forKey: cacheKey)
        UserDefaults.standard.set(data, forKey: cacheKey)
    }

    public static func fetch(
        http: any HTTPFetching,
        excludingAuthorID: String,
        url: URL = feedURL
    ) async -> [MealReview] {
        let cached = cachedReviews()
        do {
            let data = try await http.data(from: url)
            let remote = decode(data)
            let merged = merge(cached: cached, remote: remote, excludingAuthorID: excludingAuthorID)
            persist(merged)
            return merged
        } catch {
            return merge(cached: cached, remote: [], excludingAuthorID: excludingAuthorID)
        }
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
}

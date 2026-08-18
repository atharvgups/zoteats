import Foundation

/// A personal rating for a dining-hall dish. Keyed by dish name (IDs rotate daily).
public struct MealReview: Codable, Equatable, Sendable, Identifiable {
    public var id: String { Self.key(for: dishName) }
    public var dishName: String
    public var stars: Int
    public var note: String
    public var updatedAt: Date

    public init(dishName: String, stars: Int, note: String = "", updatedAt: Date = Date()) {
        self.dishName = dishName.trimmingCharacters(in: .whitespacesAndNewlines)
        self.stars = MealReviewLogic.clampStars(stars)
        self.note = MealReviewLogic.sanitizeNote(note)
        self.updatedAt = updatedAt
    }

    public static func key(for dishName: String) -> String {
        dishName.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
    }
}

public enum MealReviewLogic {
    public static let maxNoteLength = 280

    public static func clampStars(_ stars: Int) -> Int {
        min(5, max(1, stars))
    }

    public static func sanitizeNote(_ note: String) -> String {
        String(note.trimmingCharacters(in: .whitespacesAndNewlines).prefix(maxNoteLength))
    }

    public static func lookup(_ reviews: [MealReview], dishName: String) -> MealReview? {
        let key = MealReview.key(for: dishName)
        guard !key.isEmpty else { return nil }
        return reviews.first { MealReview.key(for: $0.dishName) == key }
    }

    public static func upsert(
        existing: [MealReview],
        dishName: String,
        stars: Int,
        note: String,
        now: Date = Date()
    ) -> [MealReview] {
        let trimmed = dishName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return existing }
        let review = MealReview(dishName: trimmed, stars: stars, note: note, updatedAt: now)
        var next = existing.filter { MealReview.key(for: $0.dishName) != review.id }
        next.append(review)
        return next.sorted { $0.updatedAt > $1.updatedAt }
    }

    public static func remove(existing: [MealReview], dishName: String) -> [MealReview] {
        let key = MealReview.key(for: dishName)
        return existing.filter { MealReview.key(for: $0.dishName) != key }
    }

    /// Newest first, then higher stars.
    public static func sortedForDisplay(_ reviews: [MealReview]) -> [MealReview] {
        reviews.sorted { lhs, rhs in
            if lhs.updatedAt != rhs.updatedAt { return lhs.updatedAt > rhs.updatedAt }
            if lhs.stars != rhs.stars { return lhs.stars > rhs.stars }
            return lhs.dishName.localizedCaseInsensitiveCompare(rhs.dishName) == .orderedAscending
        }
    }
}

public enum MealReviewAccessibility {
    public static func starsLabel(_ stars: Int) -> String {
        let value = MealReviewLogic.clampStars(stars)
        return value == 1 ? "1 star" : "\(value) stars"
    }
}

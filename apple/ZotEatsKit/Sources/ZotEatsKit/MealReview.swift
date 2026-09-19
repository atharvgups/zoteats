import Foundation

/// A dish rating. Personal reviews are keyed by dish + stable reviewer id
/// (IDs on the dining feed rotate daily; names are stable). Community
/// reviews from other people keep their own author id so they never
/// overwrite "You".
public struct MealReview: Codable, Equatable, Sendable, Identifiable {
    public var id: String { "\(Self.key(for: dishName))|\(resolvedAuthorID)" }
    public var dishName: String
    public var stars: Int
    public var note: String
    public var updatedAt: Date
    public var authorID: String?
    public var authorLabel: String?

    public static let legacyLocalAuthorID = "local"
    public static let youLabel = "You"

    public init(
        dishName: String,
        stars: Int,
        note: String = "",
        updatedAt: Date = Date(),
        authorID: String? = nil,
        authorLabel: String? = nil
    ) {
        self.dishName = dishName.trimmingCharacters(in: .whitespacesAndNewlines)
        self.stars = MealReviewLogic.clampStars(stars)
        self.note = MealReviewLogic.sanitizeNote(note)
        self.updatedAt = updatedAt
        self.authorID = authorID
        self.authorLabel = authorLabel
    }

    public var resolvedAuthorID: String {
        let trimmed = (authorID ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? Self.legacyLocalAuthorID : trimmed
    }

    public var resolvedAuthorLabel: String {
        let trimmed = (authorLabel ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? Self.youLabel : trimmed
    }

    public var isLocalLegacy: Bool {
        resolvedAuthorID == Self.legacyLocalAuthorID
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

    /// Tap the current star again to clear (returns 0). Otherwise 1...5.
    public static func toggleStars(current: Int, tapped: Int) -> Int {
        if current > 0, current == tapped { return 0 }
        return clampStars(tapped)
    }

    public static func sanitizeNote(_ note: String) -> String {
        String(note.trimmingCharacters(in: .whitespacesAndNewlines).prefix(maxNoteLength))
    }

    public static func lookup(
        _ reviews: [MealReview],
        dishName: String,
        authorID: String? = nil
    ) -> MealReview? {
        let key = MealReview.key(for: dishName)
        guard !key.isEmpty else { return nil }
        let matches = reviews.filter { MealReview.key(for: $0.dishName) == key }
        if let authorID {
            let wanted = authorID.trimmingCharacters(in: .whitespacesAndNewlines)
            if !wanted.isEmpty {
                return matches.first { $0.resolvedAuthorID == wanted }
                    ?? matches.first { $0.isLocalLegacy && wanted != MealReview.legacyLocalAuthorID }
            }
        }
        return matches.first
    }

    public static func reviews(for dishName: String, in reviews: [MealReview]) -> [MealReview] {
        let key = MealReview.key(for: dishName)
        guard !key.isEmpty else { return [] }
        return sortedForDisplay(reviews.filter { MealReview.key(for: $0.dishName) == key })
    }

    public static func averageStars(_ reviews: [MealReview]) -> Double? {
        guard !reviews.isEmpty else { return nil }
        let total = reviews.reduce(0) { $0 + $1.stars }
        return Double(total) / Double(reviews.count)
    }

    public static func roundedAverage(_ reviews: [MealReview]) -> Int {
        guard let average = averageStars(reviews) else { return 0 }
        return clampStars(Int(average.rounded()))
    }

    public static func upsert(
        existing: [MealReview],
        dishName: String,
        stars: Int,
        note: String,
        now: Date = Date(),
        authorID: String? = nil,
        authorLabel: String? = nil
    ) -> [MealReview] {
        let trimmed = dishName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return existing }
        if stars <= 0 {
            return remove(existing: existing, dishName: trimmed, authorID: authorID)
        }
        let review = MealReview(
            dishName: trimmed,
            stars: stars,
            note: note,
            updatedAt: now,
            authorID: authorID,
            authorLabel: authorLabel
        )
        var next = existing.filter { $0.id != review.id }
        // Legacy blobs stored one review per dish with no author — replace that
        // row when the current reviewer claims the dish so we don't show two "You"s.
        if review.resolvedAuthorID != MealReview.legacyLocalAuthorID {
            next = next.filter { candidate in
                !(MealReview.key(for: candidate.dishName) == MealReview.key(for: trimmed)
                    && candidate.isLocalLegacy)
            }
        }
        next.append(review)
        return next.sorted { $0.updatedAt > $1.updatedAt }
    }

    public static func remove(
        existing: [MealReview],
        dishName: String,
        authorID: String? = nil
    ) -> [MealReview] {
        let key = MealReview.key(for: dishName)
        return existing.filter { review in
            guard MealReview.key(for: review.dishName) == key else { return true }
            if let authorID, !authorID.isEmpty {
                if review.resolvedAuthorID == authorID { return false }
                if review.isLocalLegacy { return false }
                return true
            }
            return false
        }
    }

    /// Dining-hall glance: 4–5 stars is a hit worth pinning at the top.
    public static func isHit(_ stars: Int) -> Bool {
        stars >= 4
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

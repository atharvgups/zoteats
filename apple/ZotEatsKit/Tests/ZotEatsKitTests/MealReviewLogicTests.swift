import Foundation
import Testing
@testable import ZotEatsKit

@Suite("MealReviewLogic")
struct MealReviewLogicTests {
    @Test func clampsStarsToOneThroughFive() {
        #expect(MealReviewLogic.clampStars(0) == 1)
        #expect(MealReviewLogic.clampStars(3) == 3)
        #expect(MealReviewLogic.clampStars(9) == 5)
    }

    @Test func upsertReplacesSameDishCaseInsensitively() {
        let first = MealReviewLogic.upsert(
            existing: [],
            dishName: "AE Grill Chicken",
            stars: 4,
            note: "Crispy",
            now: Date(timeIntervalSince1970: 1)
        )
        let next = MealReviewLogic.upsert(
            existing: first,
            dishName: "ae grill chicken",
            stars: 5,
            note: "Even better",
            now: Date(timeIntervalSince1970: 2)
        )
        #expect(next.count == 1)
        #expect(next[0].stars == 5)
        #expect(next[0].note == "Even better")
        #expect(next[0].dishName == "ae grill chicken")
    }

    @Test func blankDishNameIsIgnored() {
        let next = MealReviewLogic.upsert(existing: [], dishName: "   ", stars: 5, note: "nope")
        #expect(next.isEmpty)
    }

    @Test func lookupFindsTrimmedName() {
        let reviews = MealReviewLogic.upsert(existing: [], dishName: "Soup", stars: 3, note: "")
        #expect(MealReviewLogic.lookup(reviews, dishName: " soup ")?.stars == 3)
        #expect(MealReviewLogic.lookup(reviews, dishName: "Salad") == nil)
    }

    @Test func removeDropsTheDish() {
        var reviews = MealReviewLogic.upsert(existing: [], dishName: "Soup", stars: 3, note: "")
        reviews = MealReviewLogic.upsert(existing: reviews, dishName: "Salad", stars: 5, note: "")
        reviews = MealReviewLogic.remove(existing: reviews, dishName: "soup")
        #expect(reviews.map(\.dishName) == ["Salad"])
    }

    @Test func noteIsTrimmedAndCapped() {
        let long = String(repeating: "a", count: 400)
        #expect(MealReviewLogic.sanitizeNote("  hi  ") == "hi")
        #expect(MealReviewLogic.sanitizeNote(long).count == MealReviewLogic.maxNoteLength)
    }

    @Test func fourAndFiveAreHits() {
        #expect(MealReviewLogic.isHit(4))
        #expect(MealReviewLogic.isHit(5))
        #expect(!MealReviewLogic.isHit(3))
        #expect(!MealReviewLogic.isHit(1))
        #expect(!MealReviewLogic.isHit(0))
    }

    @Test func starsVoiceOver() {
        #expect(MealReviewAccessibility.starsLabel(1) == "1 star")
        #expect(MealReviewAccessibility.starsLabel(4) == "4 stars")
        #expect(MealReviewAccessibility.starsLabel(99) == "5 stars")
    }
}

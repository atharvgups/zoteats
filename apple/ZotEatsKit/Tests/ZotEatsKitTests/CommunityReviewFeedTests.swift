import Foundation
import Testing
@testable import ZotEatsKit

@Suite("CommunityReviewFeed")
struct CommunityReviewFeedTests {
    @Test func decodePayloadKeepsOtherPeople() {
        let json = """
        {"reviews":[
          {"dishName":"Banana Berry Smoothie","stars":5,"note":"Bright","updatedAt":"2026-09-01T00:00:00Z","authorID":"a1","authorLabel":"Anteater"},
          {"dishName":"Banana Berry Smoothie","stars":3,"note":"Sweet","updatedAt":"2026-09-02T00:00:00Z","authorID":"me","authorLabel":"You"}
        ]}
        """.data(using: .utf8)!
        let decoded = CommunityReviewFeed.decode(json)
        #expect(decoded.count == 2)
        let merged = CommunityReviewFeed.merge(cached: [], remote: decoded, excludingAuthorID: "me")
        #expect(merged.count == 1)
        #expect(merged[0].resolvedAuthorLabel == "Anteater")
        #expect(merged[0].stars == 5)
    }

    @Test func averageLineAndBoard() {
        let reviews = [
            MealReview(dishName: "Soup", stars: 5, note: "", authorID: "a", authorLabel: "A"),
            MealReview(dishName: "Soup", stars: 3, note: "", authorID: "b", authorLabel: "B"),
        ]
        #expect(MealReviewLogic.averageStars(reviews) == 4)
        #expect(MealReviewLogic.roundedAverage(reviews) == 4)
        #expect(CommunityReviewCopy.averageLine(average: 4.2, count: 8) == "4.2 · 8 reviews")
        #expect(CommunityReviewCopy.averageLine(average: 5, count: 1) == "5 · 1 review")
        #expect(!CommunityReviewCopy.empty.isEmpty)
    }

    @Test func twoAuthorsShareADish() {
        var reviews: [MealReview] = []
        reviews = MealReviewLogic.upsert(
            existing: reviews,
            dishName: "Soup",
            stars: 5,
            note: "Mine",
            authorID: "me",
            authorLabel: "You"
        )
        reviews = MealReviewLogic.upsert(
            existing: reviews,
            dishName: "Soup",
            stars: 2,
            note: "Theirs",
            authorID: "other",
            authorLabel: "Anteater"
        )
        #expect(MealReviewLogic.reviews(for: "Soup", in: reviews).count == 2)
        #expect(MealReviewLogic.lookup(reviews, dishName: "Soup", authorID: "me")?.note == "Mine")
        #expect(MealReviewLogic.lookup(reviews, dishName: "Soup", authorID: "other")?.stars == 2)
    }
}

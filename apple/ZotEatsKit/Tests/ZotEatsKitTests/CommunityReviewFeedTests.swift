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

    @Test func submitPublishesAndHidesOwnReview() async {
        let http = ReviewingHTTP()
        let defaults = isolatedDefaults()
        let url = URL(string: "https://example.test/reviews")!
        await http.seed(CommunityReviewFeed.encode([
            MealReview(dishName: "Soup", stars: 4, note: "Nice", authorID: "other", authorLabel: "Anteater"),
        ]))
        let result = await CommunityReviewFeed.submit(
            http: http,
            dishName: "Soup",
            stars: 5,
            note: "Best",
            authorID: "me",
            authorLabel: MealReview.communityAuthorLabel,
            excludingAuthorID: "me",
            url: url,
            writeToken: "test-token",
            defaults: defaults,
            enqueueOnFailure: false
        )
        #expect(result.published)
        #expect(result.reviews.count == 1)
        #expect(result.reviews[0].resolvedAuthorID == "other")
        struct Envelope: Decodable {
            var event_type: String
            var client_payload: Payload
            struct Payload: Decodable {
                var dishName: String
                var stars: Int
                var note: String
                var authorID: String
            }
        }
        let envelope = try? JSONDecoder().decode(Envelope.self, from: await http.payload())
        #expect(envelope?.event_type == "meal-review")
        #expect(envelope?.client_payload.stars == 5)
        #expect(envelope?.client_payload.note == "Best")
        #expect(envelope?.client_payload.authorID == "me")
        #expect(OutboundIngestQueue.load(defaults: defaults).isEmpty)
    }

    @Test func submitZeroStarsRemovesOwnReview() async {
        let http = ReviewingHTTP()
        let defaults = isolatedDefaults()
        let url = URL(string: "https://example.test/reviews")!
        await http.seed(CommunityReviewFeed.encode([
            MealReview(dishName: "Soup", stars: 5, note: "Mine", authorID: "me", authorLabel: "Anteater"),
            MealReview(dishName: "Soup", stars: 3, note: "Theirs", authorID: "other", authorLabel: "Anteater"),
        ]))
        let result = await CommunityReviewFeed.submit(
            http: http,
            dishName: "Soup",
            stars: 0,
            note: "",
            authorID: "me",
            authorLabel: MealReview.communityAuthorLabel,
            excludingAuthorID: "me",
            url: url,
            writeToken: "test-token",
            defaults: defaults,
            enqueueOnFailure: false
        )
        #expect(result.published)
        #expect(result.reviews.count == 1)
        #expect(result.reviews[0].resolvedAuthorID == "other")
        struct Envelope: Decodable {
            var event_type: String
            var client_payload: Payload
            struct Payload: Decodable { var stars: Int }
        }
        let envelope = try? JSONDecoder().decode(Envelope.self, from: await http.payload())
        #expect(envelope?.event_type == "meal-review")
        #expect(envelope?.client_payload.stars == 0)
    }

    @Test func submitQueuesWhenTokenMissing() async {
        let http = ReviewingHTTP()
        let defaults = isolatedDefaults()
        let result = await CommunityReviewFeed.submit(
            http: http,
            dishName: "Soup",
            stars: 4,
            note: "Nice",
            authorID: "me",
            authorLabel: MealReview.communityAuthorLabel,
            excludingAuthorID: "me",
            writeToken: "",
            defaults: defaults
        )
        #expect(!result.published)
        #expect(OutboundIngestQueue.load(defaults: defaults).count == 1)
        #expect(OutboundIngestQueue.load(defaults: defaults).first?.kind == .mealReview)
    }
}

actor ReviewingHTTP: HTTPFetching {
    private var stored = Data("{}".utf8)
    private var lastPosted = Data()
    private var writesFail = false

    func seed(_ data: Data) {
        stored = data
    }

    func failWrites(_ value: Bool) {
        writesFail = value
    }

    func payload() -> Data { lastPosted.isEmpty ? stored : lastPosted }

    func data(from url: URL) async throws -> Data { stored }

    func send(method: String, url: URL, headers: [String: String], body: Data?) async throws -> Data {
        if method.uppercased() == "GET" { return stored }
        if writesFail {
            throw HTTPError.badStatus(code: 503, url: url)
        }
        if let body { lastPosted = body }
        return Data()
    }
}

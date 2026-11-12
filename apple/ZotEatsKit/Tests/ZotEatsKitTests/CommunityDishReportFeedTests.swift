import Foundation
import Testing
@testable import ZotEatsKit

@Suite("CommunityDishReportFeed")
struct CommunityDishReportFeedTests {
    @Test func decodePayloadAndMergeByNewerWrite() {
        let json = """
        {"reports":[
          {"date":"2026-10-28","hall":"brandywine","meal":"Lunch","dishID":"sku-1","dishName":"Linguine","reason":"notAtHall","authorID":"a","updatedAt":"2026-10-28T19:00:00Z"},
          {"date":"2026-10-28","hall":"brandywine","meal":"Lunch","dishID":"sku-1","dishName":"Linguine","reason":"notServed","authorID":"b","updatedAt":"2026-10-28T19:01:00Z"}
        ]}
        """.data(using: .utf8)!
        let decoded = CommunityDishReportFeed.decode(json)
        #expect(decoded.count == 2)
        #expect(
            DishReportLogic.isReportedMissing(
                in: decoded,
                date: "2026-10-28",
                hall: "brandywine",
                meal: "Lunch",
                dishID: "sku-1"
            )
        )
        let older = DishReport(
            date: "2026-10-28",
            hall: "brandywine",
            meal: "Lunch",
            dishID: "sku-1",
            dishName: "Linguine",
            reason: .wrongStation,
            authorID: "a",
            updatedAt: Date(timeIntervalSince1970: 1)
        )
        let merged = CommunityDishReportFeed.merge(cached: [older], remote: decoded)
        #expect(merged.count == 2)
        #expect(merged.first { $0.authorID == "a" }?.reason == .notAtHall)
    }

    @Test func submitDispatchesWithoutDroppingOthers() async {
        CommunityDishReportFeed.persist([])
        let http = ReviewingHTTP()
        let defaults = isolatedDefaults()
        let url = URL(string: "https://example.test/reports")!
        await http.seed(CommunityDishReportFeed.encode([
            DishReport(
                date: "2026-10-28",
                hall: "anteatery",
                meal: "Lunch",
                dishID: "rice",
                dishName: "Jasmine Rice",
                reason: .notServed,
                authorID: "other"
            ),
        ]))
        let result = await CommunityDishReportFeed.submit(
            http: http,
            date: "2026-10-28",
            hall: "anteatery",
            meal: "Lunch",
            dishID: "rice",
            dishName: "Jasmine Rice",
            reason: .notAtHall,
            authorID: "me",
            url: url,
            writeToken: "test-token",
            defaults: defaults,
            enqueueOnFailure: false
        )
        #expect(result.published)
        #expect(result.reports.count == 2)
        #expect(result.reports.contains { $0.authorID == "me" && $0.reason == .notAtHall })
        #expect(result.reports.contains { $0.authorID == "other" })
        struct Envelope: Decodable {
            var event_type: String
            var client_payload: Payload
            struct Payload: Decodable {
                var dishName: String
                var reason: String
                var authorID: String
            }
        }
        let envelope = try? JSONDecoder().decode(Envelope.self, from: await http.payload())
        #expect(envelope?.event_type == "dish-report")
        #expect(envelope?.client_payload.reason == "notAtHall")
        #expect(envelope?.client_payload.authorID == "me")
        #expect(OutboundIngestQueue.load(defaults: defaults).isEmpty)
        #expect(
            DishFeedbackLogic.wasNoted(
                date: "2026-10-28",
                hall: "anteatery",
                meal: "Lunch",
                dishID: "rice",
                dishName: "Jasmine Rice",
                defaults: defaults
            )
        )
    }

    @Test func submitQueuesWhenDispatchFails() async {
        let http = ReviewingHTTP()
        await http.failWrites(true)
        let defaults = isolatedDefaults()
        let author = "queue-fail-\(UUID().uuidString)"
        let result = await CommunityDishReportFeed.submit(
            http: http,
            date: "2026-11-12",
            hall: "anteatery",
            meal: "Lunch",
            dishID: "rice-fail",
            dishName: "Jasmine Rice",
            reason: .notServed,
            authorID: author,
            writeToken: "test-token",
            defaults: defaults
        )
        #expect(!result.published)
        #expect(!result.reports.contains { $0.authorID == author })
        let queued = OutboundIngestQueue.load(defaults: defaults)
        #expect(queued.count == 1)
        #expect(queued.first?.kind == .dishReport)
        #expect(queued.first?.reason == "notServed")
        #expect(
            !DishFeedbackLogic.wasNoted(
                date: "2026-11-12",
                hall: "anteatery",
                meal: "Lunch",
                dishID: "rice-fail",
                dishName: "Jasmine Rice",
                defaults: defaults
            )
        )
    }

    @Test func submitFeedbackDispatchesOtherNote() async {
        let http = ReviewingHTTP()
        let defaults = isolatedDefaults()
        let sent = await CommunityDishReportFeed.submitFeedback(
            http: http,
            date: "2026-10-29",
            hall: "anteatery",
            meal: "Lunch",
            dishID: "rice",
            dishName: "Jasmine Rice",
            text: "  Sauce is cold  ",
            authorID: "me",
            writeToken: "test-token",
            defaults: defaults
        )
        #expect(sent)
        struct Envelope: Decodable {
            var event_type: String
            var client_payload: Payload
            struct Payload: Decodable {
                var date: String
                var hall: String
                var meal: String
                var dishName: String
                var text: String
                var reason: String
            }
        }
        let envelope = try? JSONDecoder().decode(Envelope.self, from: await http.payload())
        #expect(envelope?.event_type == "dish-feedback")
        #expect(envelope?.client_payload.text == "Sauce is cold")
        #expect(envelope?.client_payload.reason == "other")
        #expect(envelope?.client_payload.dishName == "Jasmine Rice")
        #expect(envelope?.client_payload.hall == "anteatery")
        #expect(envelope?.client_payload.meal == "Lunch")
        #expect(envelope?.client_payload.date == "2026-10-29")
        let skipped = await CommunityDishReportFeed.submitFeedback(
            http: http,
            date: "2026-10-29",
            hall: "anteatery",
            meal: "Lunch",
            dishID: "rice",
            dishName: "Jasmine Rice",
            text: "Nope",
            authorID: "me",
            writeToken: "",
            defaults: defaults,
            enqueueOnFailure: false
        )
        #expect(!skipped)
    }

    @Test func emptyTokenDoesNotShowThanksAndQueues() async {
        let http = ReviewingHTTP()
        let defaults = isolatedDefaults()
        let sent = await CommunityDishReportFeed.submitFeedback(
            http: http,
            date: "2026-11-12",
            hall: "anteatery",
            meal: "Lunch",
            dishID: "rice-empty",
            dishName: "Jasmine Rice",
            text: "Board says red curry",
            authorID: "empty-\(UUID().uuidString)",
            writeToken: "",
            defaults: defaults
        )
        #expect(!sent)
        #expect(OutboundIngestQueue.load(defaults: defaults).count == 1)
        #expect(
            !DishFeedbackLogic.wasNoted(
                date: "2026-11-12",
                hall: "anteatery",
                meal: "Lunch",
                dishID: "rice-empty",
                dishName: "Jasmine Rice",
                defaults: defaults
            )
        )
    }
}

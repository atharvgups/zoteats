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

    @Test func submitPublishesWithoutDroppingOthers() async {
        CommunityDishReportFeed.persist([])
        let http = ReviewingHTTP()
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
        let next = await CommunityDishReportFeed.submit(
            http: http,
            date: "2026-10-28",
            hall: "anteatery",
            meal: "Lunch",
            dishID: "rice",
            dishName: "Jasmine Rice",
            reason: .notAtHall,
            authorID: "me",
            url: url
        )
        #expect(next.count == 2)
        let stored = CommunityDishReportFeed.decode(await http.payload())
        #expect(stored.count == 2)
        #expect(stored.contains { $0.authorID == "me" && $0.reason == .notAtHall })
        #expect(stored.contains { $0.authorID == "other" })
        #expect(
            DishReportLogic.isReportedMissing(
                in: stored,
                date: "2026-10-28",
                hall: "anteatery",
                meal: "Lunch",
                dishID: "rice"
            )
        )
    }
}

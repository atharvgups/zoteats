import Foundation
import Testing
@testable import ZotEatsKit

@Suite("OutboundIngestQueue", .serialized)
struct OutboundIngestQueueTests {
    @Test func failedSendRetriesOnFlushThenMarksNoted() async {
        let defaults = isolatedDefaults()
        OutboundIngestQueue.enqueue(
            OutboundIngestQueue.dishReportItem(
                date: "2026-11-12",
                hall: "anteatery",
                meal: "Lunch",
                dishID: "rice",
                dishName: "Red Curry Tofu Rice Bowl",
                reason: .notServed,
                authorID: "me"
            ),
            defaults: defaults
        )
        OutboundIngestQueue.enqueue(
            OutboundIngestQueue.dishFeedbackItem(
                date: "2026-11-12",
                hall: "anteatery",
                meal: "Lunch",
                dishID: "rice",
                dishName: "Red Curry Tofu Rice Bowl",
                text: "Board says sesame",
                authorID: "me"
            ),
            defaults: defaults
        )
        #expect(OutboundIngestQueue.load(defaults: defaults).count == 2)

        let failing = ReviewingHTTP()
        await failing.failWrites(true)
        let stillQueued = await OutboundIngestQueue.flush(
            http: failing,
            writeToken: "test-token",
            defaults: defaults
        )
        #expect(stillQueued.sent == 0)
        #expect(stillQueued.remaining == 2)
        #expect(OutboundIngestQueue.load(defaults: defaults).allSatisfy { $0.attempts == 1 })
        #expect(
            !DishFeedbackLogic.wasNoted(
                date: "2026-11-12",
                hall: "anteatery",
                meal: "Lunch",
                dishID: "rice",
                dishName: "Red Curry Tofu Rice Bowl",
                defaults: defaults
            )
        )

        let ok = ReviewingHTTP()
        let flushed = await OutboundIngestQueue.flush(
            http: ok,
            writeToken: "test-token",
            defaults: defaults
        )
        #expect(flushed.sent == 2)
        #expect(flushed.remaining == 0)
        #expect(OutboundIngestQueue.load(defaults: defaults).isEmpty)
        #expect(
            DishFeedbackLogic.wasNoted(
                date: "2026-11-12",
                hall: "anteatery",
                meal: "Lunch",
                dishID: "rice",
                dishName: "Red Curry Tofu Rice Bowl",
                defaults: defaults
            )
        )
    }

    @Test func enqueueReplacesSameListing() {
        let defaults = isolatedDefaults()
        OutboundIngestQueue.enqueue(
            OutboundIngestQueue.dishReportItem(
                date: "2026-11-12",
                hall: "anteatery",
                meal: "Lunch",
                dishID: "rice",
                dishName: "Rice",
                reason: .notAtHall,
                authorID: "me"
            ),
            defaults: defaults
        )
        OutboundIngestQueue.enqueue(
            OutboundIngestQueue.dishReportItem(
                date: "2026-11-12",
                hall: "anteatery",
                meal: "Lunch",
                dishID: "rice",
                dishName: "Rice",
                reason: .wrongStation,
                authorID: "me"
            ),
            defaults: defaults
        )
        let queued = OutboundIngestQueue.load(defaults: defaults)
        #expect(queued.count == 1)
        #expect(queued.first?.reason == "wrongStation")
    }

    @Test func emptyTokenFlushKeepsQueue() async {
        let defaults = isolatedDefaults()
        OutboundIngestQueue.enqueue(
            OutboundIngestQueue.mealReviewItem(
                dishName: "Soup",
                stars: 5,
                note: "Good",
                authorID: "me",
                authorLabel: "Anteater"
            ),
            defaults: defaults
        )
        let result = await OutboundIngestQueue.flush(
            http: ReviewingHTTP(),
            writeToken: "",
            defaults: defaults
        )
        #expect(result.sent == 0)
        #expect(result.remaining == 1)
    }
}

func isolatedDefaults() -> UserDefaults {
    let name = "zoteats.tests.\(UUID().uuidString)"
    let defaults = UserDefaults(suiteName: name)!
    defaults.removePersistentDomain(forName: name)
    return defaults
}

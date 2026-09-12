import Testing
@testable import ZotEatsKit

@Suite("CampusDeepLinkApply")
struct CampusDeepLinkApplyTests {
    private let starbucks = CampusPlace(
        id: "starbucks-at-student-center",
        name: "Starbucks @ Student Center",
        category: "Coffee & Cafés",
        openNow: true,
        todayHours: "7:30 AM – 4:00 PM"
    )

    @Test("Waits while places are still loading")
    func waitForPlaces() {
        #expect(
            CampusDeepLinkApply.resolve(
                placeID: "starbucks-at-student-center",
                places: nil,
                feedReady: false
            ) == .waitForPlaces
        )
    }

    @Test("Opens when the place is in the feed")
    func openKnown() {
        #expect(
            CampusDeepLinkApply.resolve(
                placeID: "starbucks-at-student-center",
                places: [starbucks],
                feedReady: true
            ) == .open(placeID: "starbucks-at-student-center")
        )
    }

    @Test("Discards unknown id after load so pending doesn't stick")
    func discardUnknown() {
        #expect(
            CampusDeepLinkApply.resolve(
                placeID: "ghost-cafe",
                places: [starbucks],
                feedReady: true
            ) == .discard
        )
        #expect(
            CampusDeepLinkApply.resolve(
                placeID: "ghost-cafe",
                places: [],
                feedReady: true
            ) == .discard
        )
    }

    @Test("Failed feed discards instead of waiting forever")
    func failedFeedDiscards() {
        #expect(
            CampusDeepLinkApply.resolve(
                placeID: "starbucks-at-student-center",
                places: nil,
                feedReady: true
            ) == .discard
        )
    }

    @Test("Bare campus link discards")
    func bareCampus() {
        #expect(
            CampusDeepLinkApply.resolve(placeID: nil, places: [starbucks], feedReady: true)
                == .discard
        )
        #expect(
            CampusDeepLinkApply.resolve(placeID: "", places: [starbucks], feedReady: true)
                == .discard
        )
        #expect(
            CampusDeepLinkApply.resolve(placeID: nil, places: nil, feedReady: false)
                == .discard
        )
    }
}

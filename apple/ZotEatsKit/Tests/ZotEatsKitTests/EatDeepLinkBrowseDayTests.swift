import Foundation
import Testing
@testable import ZotEatsKit

@Suite("EatDeepLinkBrowseDay")
struct EatDeepLinkBrowseDayTests {
    @Test func omittedDateWithLiveIntentForcesToday() {
        #expect(
            EatDeepLinkBrowseDay.resolve(
                linkDate: nil,
                todayISO: "2026-07-09",
                forcesTodayWhenDateOmitted: true
            ) == .today
        )
    }

    @Test func bareEatKeepsDayStrip() {
        #expect(
            EatDeepLinkBrowseDay.resolve(
                linkDate: nil,
                todayISO: "2026-07-09",
                forcesTodayWhenDateOmitted: false
            ) == .keep
        )
    }

    @Test func explicitTodayClearsFutureBrowse() {
        #expect(
            EatDeepLinkBrowseDay.resolve(
                linkDate: "2026-07-09",
                todayISO: "2026-07-09",
                forcesTodayWhenDateOmitted: false
            ) == .today
        )
    }

    @Test func explicitFutureKeepsISO() {
        #expect(
            EatDeepLinkBrowseDay.resolve(
                linkDate: "2026-07-10",
                todayISO: "2026-07-09",
                forcesTodayWhenDateOmitted: true
            ) == .future(iso: "2026-07-10")
        )
    }
}

import Foundation
import Testing
@testable import ZotEatsKit

@Suite("DiningDayMath")
struct DiningDayMathTests {
    @Test func sameDayDoesNotRollover() {
        #expect(
            DiningDayMath.shouldRollover(
                loadedDateISO: "2026-07-16",
                todayISO: "2026-07-16"
            ) == false
        )
    }

    @Test func yesterdayTriggersRollover() {
        #expect(
            DiningDayMath.shouldRollover(
                loadedDateISO: "2026-07-15",
                todayISO: "2026-07-16"
            ) == true
        )
    }

    @Test func missingLoadedMeansNoRollover() {
        #expect(DiningDayMath.shouldRollover(loadedDateISO: nil, todayISO: "2026-07-16") == false)
        #expect(DiningDayMath.shouldRollover(loadedDateISO: "", todayISO: "2026-07-16") == false)
    }

    @Test func liveTodayKeysAreDetected() {
        #expect(DiningDayMath.isLiveTodayMenuKey("anteatery|Lunch|today"))
        #expect(!DiningDayMath.isLiveTodayMenuKey("anteatery|Lunch|2026-07-17"))
        #expect(
            DiningDayMath.liveTodayMenuKeys(in: [
                "anteatery|Lunch|today",
                "anteatery|Lunch|2026-07-17",
                "brandywine|Dinner|today",
            ]) == [
                "anteatery|Lunch|today",
                "brandywine|Dinner|today",
            ]
        )
    }
}

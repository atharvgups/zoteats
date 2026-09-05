import Foundation
import Testing
@testable import ZotEatsKit

@Suite("EatDateSelection")
struct EatDateSelectionTests {
    @Test func collapsesExplicitTodayToLiveNil() {
        #expect(
            EatDateSelection.snapLiveToday(
                selectedDateISO: "2026-07-10",
                todayISO: "2026-07-10"
            ) == nil
        )
    }

    @Test func keepsFutureBrowseISO() {
        #expect(
            EatDateSelection.snapLiveToday(
                selectedDateISO: "2026-07-11",
                todayISO: "2026-07-10"
            ) == "2026-07-11"
        )
    }

    @Test func nilAndEmptyStayLive() {
        #expect(EatDateSelection.snapLiveToday(selectedDateISO: nil, todayISO: "2026-07-10") == nil)
        #expect(EatDateSelection.snapLiveToday(selectedDateISO: "", todayISO: "2026-07-10") == nil)
    }
}

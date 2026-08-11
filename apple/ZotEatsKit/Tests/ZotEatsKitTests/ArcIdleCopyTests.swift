import Foundation
import Testing
@testable import ZotEatsKit

@Suite("ArcIdleCopy")
struct ArcIdleCopyTests {
    @Test func beforeOpenSaysOpensAt() {
        // Thursday open 6 AM.
        let open = ArcIdleCopy.todayOpenMinutes(weekday: "Thursday")
        #expect(open == 6 * 60)
        #expect(
            ArcIdleCopy.noBusynessMessage(
                openNow: false,
                nowMinutes: 5 * 60,
                opensAtMinutesToday: open,
                closesAtMinutesToday: 24 * 60
            ) == "Closed — opens at 6:00 AM"
        )
        #expect(
            ArcIdleCopy.closedHoursLine(
                todayHours: "6:00 AM – 12:00 AM",
                nowMinutes: 5 * 60,
                opensAtMinutesToday: open
            ) == "Opens at 6:00 AM"
        )
    }

    @Test func afterCloseSaysSeeYouTomorrow() {
        let open = ArcIdleCopy.todayOpenMinutes(weekday: "Saturday")
        let close = ArcIdleCopy.todayCloseMinutes(weekday: "Saturday")
        #expect(open == 8 * 60)
        #expect(close == 21 * 60)
        #expect(
            ArcIdleCopy.noBusynessMessage(
                openNow: false,
                nowMinutes: 22 * 60,
                opensAtMinutesToday: open,
                closesAtMinutesToday: close
            ) == "Closed — see you tomorrow"
        )
    }

    @Test func weekendBeforeOpenUsesEightAM() {
        let open = ArcIdleCopy.todayOpenMinutes(weekday: "Saturday")
        #expect(
            ArcIdleCopy.noBusynessMessage(
                openNow: false,
                nowMinutes: 7 * 60,
                opensAtMinutesToday: open,
                closesAtMinutesToday: 21 * 60
            ) == "Closed — opens at 8:00 AM"
        )
    }

    @Test func openWithoutPercentKeepsEstimateCopy() {
        #expect(
            ArcIdleCopy.noBusynessMessage(
                openNow: true,
                nowMinutes: 12 * 60,
                opensAtMinutesToday: 6 * 60,
                closesAtMinutesToday: 24 * 60
            ) == "No busyness estimate right now"
        )
    }

    @Test func hoursLineOpenUntilClose() {
        #expect(
            ArcIdleCopy.hoursLine(
                openNow: true,
                todayHours: "6:00 AM – 12:00 AM",
                nowMinutes: 12 * 60,
                opensAtMinutesToday: 6 * 60
            ) == "Open until 12:00 AM"
        )
    }
}

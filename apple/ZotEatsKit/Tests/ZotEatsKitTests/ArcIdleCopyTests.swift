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
                closesAtMinutesToday: 24 * 60,
                opensAtMinutesTomorrow: 6 * 60
            ) == "Closed — opens at 6:00 AM"
        )
        #expect(
            ArcIdleCopy.closedHoursLine(
                todayHours: "6:00 AM – 12:00 AM",
                nowMinutes: 5 * 60,
                opensAtMinutesToday: open,
                closesAtMinutesToday: 24 * 60,
                opensAtMinutesTomorrow: 6 * 60
            ) == "Opens at 6:00 AM"
        )
    }

    @Test func afterCloseNamesTomorrowsOpen() {
        let open = ArcIdleCopy.todayOpenMinutes(weekday: "Saturday")
        let close = ArcIdleCopy.todayCloseMinutes(weekday: "Saturday")
        let tomorrow = ArcIdleCopy.tomorrowOpenMinutes(weekday: "Saturday")
        #expect(open == 8 * 60)
        #expect(close == 20 * 60)
        #expect(tomorrow == 8 * 60) // Sunday
        #expect(
            ArcIdleCopy.noBusynessMessage(
                openNow: false,
                nowMinutes: 22 * 60,
                opensAtMinutesToday: open,
                closesAtMinutesToday: close,
                opensAtMinutesTomorrow: tomorrow
            ) == "Closed — opens tomorrow at 8:00 AM"
        )
        #expect(
            ArcIdleCopy.closedHoursLine(
                todayHours: "8:00 AM – 8:00 PM",
                nowMinutes: 22 * 60,
                opensAtMinutesToday: open,
                closesAtMinutesToday: close,
                opensAtMinutesTomorrow: tomorrow
            ) == "Opens tomorrow at 8:00 AM"
        )
    }

    @Test func fridayMapsTomorrowToSaturdayEight() {
        #expect(ArcIdleCopy.tomorrowOpenMinutes(weekday: "Friday") == 8 * 60)
    }

    @Test func closedInsideTodaysWindowDoesNotJumpToTomorrow() {
        // Waitz can disagree with the maintained close — don't invent "tomorrow"
        // while today's schedule still lists the hall as open.
        #expect(
            ArcIdleCopy.noBusynessMessage(
                openNow: false,
                nowMinutes: 23 * 60 + 30,
                opensAtMinutesToday: 6 * 60,
                closesAtMinutesToday: 24 * 60,
                opensAtMinutesTomorrow: 8 * 60
            ) == "Closed — see you tomorrow"
        )
        #expect(
            ArcIdleCopy.closedHoursLine(
                todayHours: "6:00 AM – 12:00 AM",
                nowMinutes: 23 * 60 + 30,
                opensAtMinutesToday: 6 * 60,
                closesAtMinutesToday: 24 * 60,
                opensAtMinutesTomorrow: 8 * 60
            ) == "Closed · 6:00 AM – 12:00 AM"
        )
    }

    @Test func weekendBeforeOpenUsesEightAM() {
        let open = ArcIdleCopy.todayOpenMinutes(weekday: "Saturday")
        #expect(
            ArcIdleCopy.noBusynessMessage(
                openNow: false,
                nowMinutes: 7 * 60,
                opensAtMinutesToday: open,
                closesAtMinutesToday: 20 * 60,
                opensAtMinutesTomorrow: 8 * 60
            ) == "Closed — opens at 8:00 AM"
        )
    }

    @Test func openWithoutPercentKeepsEstimateCopy() {
        #expect(
            ArcIdleCopy.noBusynessMessage(
                openNow: true,
                nowMinutes: 12 * 60,
                opensAtMinutesToday: 6 * 60,
                closesAtMinutesToday: 24 * 60,
                opensAtMinutesTomorrow: 6 * 60
            ) == "No busyness estimate right now"
        )
    }

    @Test func hoursLineOpenUntilClose() {
        #expect(
            ArcIdleCopy.hoursLine(
                openNow: true,
                todayHours: "6:00 AM – 12:00 AM",
                nowMinutes: 12 * 60,
                opensAtMinutesToday: 6 * 60,
                closesAtMinutesToday: 24 * 60,
                opensAtMinutesTomorrow: 6 * 60
            ) == "Open until 12:00 AM"
        )
    }

    @Test func unknownScheduleKeepsVagueTomorrow() {
        #expect(
            ArcIdleCopy.noBusynessMessage(
                openNow: false,
                nowMinutes: 22 * 60,
                opensAtMinutesToday: nil,
                closesAtMinutesToday: nil,
                opensAtMinutesTomorrow: nil
            ) == "Closed — see you tomorrow"
        )
    }

    @Test func waitzClosedUntilBeatsPastScheduleOpen() {
        // Schedule said 6 AM; Waitz says noon and ARC is still closed at 10 AM.
        let waitz = ArcIdleCopy.opensAtMinutesToday(
            weekday: "Monday",
            openNow: false,
            waitzReopenMinutes: 12 * 60
        )
        #expect(waitz == 12 * 60)
        #expect(
            ArcIdleCopy.closedHoursLine(
                todayHours: "6:00 AM – 10:00 PM",
                nowMinutes: 10 * 60,
                opensAtMinutesToday: waitz,
                closesAtMinutesToday: 22 * 60,
                opensAtMinutesTomorrow: 6 * 60
            ) == "Opens at 12:00 PM"
        )
        #expect(
            ArcIdleCopy.noBusynessMessage(
                openNow: false,
                nowMinutes: 10 * 60,
                opensAtMinutesToday: waitz,
                closesAtMinutesToday: 22 * 60,
                opensAtMinutesTomorrow: 6 * 60
            ) == "Closed — opens at 12:00 PM"
        )
    }

    @Test func scheduleOpenUsedWhenWaitzAbsentOrOpen() {
        #expect(
            ArcIdleCopy.opensAtMinutesToday(
                weekday: "Monday",
                openNow: false,
                waitzReopenMinutes: nil
            ) == 6 * 60
        )
        #expect(
            ArcIdleCopy.opensAtMinutesToday(
                weekday: "Monday",
                openNow: true,
                waitzReopenMinutes: 12 * 60
            ) == 6 * 60
        )
    }
}

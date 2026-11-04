import Foundation
import Testing
@testable import ZotEatsKit

@Suite("OasisSchedule")
struct OasisScheduleTests {
    @Test func firstServiceIsMondayOctober5FromHubHours() {
        #expect(OasisSchedule.firstServiceISO == "2026-10-05")
        #expect(OasisSchedule.opensLine == "Opens Mon Oct 5")
        #expect(!OasisSchedule.hasOpened(on: "2026-09-21"))
        #expect(!OasisSchedule.hasOpened(on: "2026-10-02"))
        #expect(OasisSchedule.hasOpened(on: "2026-10-05"))
        #expect(OasisSchedule.hasOpened(on: "2026-10-06"))
    }

    @Test func copyIsHonestWhenHubHasNoDishes() {
        let dinner = 16 * 60 + 56
        #expect(
            OasisComingSoonCopy.selectedLine(
                on: "2026-10-22",
                weekday: "Thursday",
                nowMinutes: dinner
            ) == "Open, menu not posted."
        )
        #expect(
            OasisComingSoonCopy.cardStatus(
                on: "2026-10-22",
                weekday: "Thursday",
                nowMinutes: dinner
            ) == "Menu not posted"
        )
        #expect(
            OasisComingSoonCopy.selectedLine(
                on: "2026-10-22",
                weekday: "Thursday",
                nowMinutes: 9 * 60
            ).contains("UCI has not posted a menu")
        )
        #expect(
            OasisComingSoonCopy.selectedLine(on: "2026-10-24", weekday: "Saturday")
                .contains("Closed today")
        )
        #expect(!OasisComingSoonCopy.openUnposted.contains("Coming Soon"))
        #expect(!OasisComingSoonCopy.selectedLine(
            on: "2026-10-22",
            weekday: "Thursday",
            nowMinutes: 9 * 60
        ).contains("2:30"))
    }

    @Test func weekdayHoursMatchHubLunchAndDinner() {
        let thursday = OasisSchedule.mealWindows(on: "2026-11-04", weekday: "Thursday")
        #expect(thursday.map(\.name) == ["Lunch", "Dinner"])
        #expect(thursday[0].startMinutes == 11 * 60)
        #expect(thursday[0].endMinutes == 14 * 60)
        #expect(thursday[1].startMinutes == 16 * 60 + 30)
        #expect(thursday[1].endMinutes == 20 * 60)
        #expect(
            OasisSchedule.todayHours(on: "2026-11-04", weekday: "Thursday")
                == "11:00 AM – 2:00 PM, 4:30 PM – 8:00 PM"
        )

        let friday = OasisSchedule.mealWindows(on: "2026-11-06", weekday: "Friday")
        #expect(friday.map(\.name) == ["Lunch"])
        #expect(friday[0].endMinutes == 14 * 60)
        #expect(OasisSchedule.todayHours(on: "2026-11-06", weekday: "Friday") == "11:00 AM – 2:00 PM")
        #expect(!OasisSchedule.servesDinner(on: "2026-11-06", weekday: "Friday"))

        #expect(OasisSchedule.mealWindows(on: "2026-11-07", weekday: "Saturday").isEmpty)
        #expect(OasisSchedule.mealWindows(on: "2026-11-08", weekday: "Sunday").isEmpty)
        #expect(OasisSchedule.mealWindows(on: "2026-11-11", weekday: "Wednesday").isEmpty)
        #expect(OasisSchedule.isClosedDate("2026-11-11"))
        #expect(OasisSchedule.mealWindows(on: "2026-10-03", weekday: "Saturday").isEmpty)
        #expect(OasisSchedule.mealWindows(on: "2026-09-21", weekday: "Monday").isEmpty)

        #expect(OasisSchedule.isOpen(on: "2026-11-04", weekday: "Thursday", nowMinutes: 12 * 60))
        #expect(!OasisSchedule.isOpen(on: "2026-11-04", weekday: "Thursday", nowMinutes: 15 * 60))
        #expect(OasisSchedule.isOpen(on: "2026-11-04", weekday: "Thursday", nowMinutes: 16 * 60 + 56))
        #expect(!OasisSchedule.isOpen(on: "2026-11-04", weekday: "Thursday", nowMinutes: 10 * 60))
        #expect(!OasisSchedule.isOpen(on: "2026-11-11", weekday: "Wednesday", nowMinutes: 12 * 60))
    }

    @Test func nextServiceSkipsClosedDays() {
        let fromSunday = OasisSchedule.nextService(after: "2026-10-04")
        #expect(fromSunday?.iso == "2026-10-05")
        #expect(fromSunday?.weekday == "Monday")
        #expect(fromSunday?.dayOffset == 1)
        #expect(fromSunday?.minutes == 11 * 60)

        let fromFriday = OasisSchedule.nextService(after: "2026-10-09")
        #expect(fromFriday?.iso == "2026-10-12")
        #expect(fromFriday?.weekday == "Monday")
        #expect(fromFriday?.dayOffset == 3)

        let beforeOpen = OasisSchedule.nextService(after: "2026-09-21")
        #expect(beforeOpen?.iso == "2026-10-05")
        #expect(beforeOpen?.weekday == "Monday")

        let veteransEve = OasisSchedule.nextService(after: "2026-11-10")
        #expect(veteransEve?.iso == "2026-11-12")
        #expect(veteransEve?.weekday == "Thursday")
    }

    @Test func placeholderUsesHubHoursWithoutInventingDishes() {
        let thursdayDinner = ISO8601DateFormatter().date(from: "2026-10-22T23:56:00Z")!
        let oasis = DiningService.oasisComingSoonLocation(dateISO: "2026-10-22", now: thursdayDinner)
        #expect(oasis.isComingSoon)
        #expect(oasis.comingSoonSubtitle == "Menu not posted")
        #expect(oasis.availablePeriods.isEmpty)
        #expect(oasis.openNow)
        #expect(oasis.todayHours == "11:00 AM – 2:00 PM, 4:30 PM – 8:00 PM")
        #expect(oasis.periods.map(\.name) == ["Lunch", "Dinner"])
        let tile = EatHallCardChrome.status(
            comingSoon: true,
            state: oasis.openState(nowMinutes: PacificTime.nowMinutes(now: thursdayDinner)),
            todayISO: "2026-10-22"
        )
        #expect(tile.primary == "Menu not posted")
        #expect(tile.tone == .open)
        #expect(tile.accessibilityLine == "Open, menu not posted")
    }

    @Test func fridayDinnerAndVeteransDayStayOffEvenIfHubCopiedSkus() {
        #expect(
            OasisSchedule.servingPeriods(
                from: ["Lunch", "Dinner", "Brunch", "All Day"],
                on: "2026-11-06",
                weekday: "Friday"
            ) == ["Lunch"]
        )
        #expect(
            OasisSchedule.servingPeriods(
                from: ["Lunch", "Dinner"],
                on: "2026-11-11",
                weekday: "Wednesday"
            ).isEmpty
        )
        #expect(
            OasisSchedule.servingPeriods(
                from: ["Lunch", "Dinner"],
                on: "2026-11-07",
                weekday: "Saturday"
            ).isEmpty
        )
    }
}

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
    }

    @Test func weekdayHoursMatchHubStandardIncludingSnack() {
        let windows = OasisSchedule.mealWindows(on: "2026-10-22", weekday: "Thursday")
        #expect(windows.map(\.name) == ["Lunch", "Afternoon Snack", "Dinner"])
        #expect(windows[0].startMinutes == 11 * 60)
        #expect(windows[0].endMinutes == 14 * 60 + 30)
        #expect(windows[1].startMinutes == 14 * 60 + 30)
        #expect(windows[1].endMinutes == 16 * 60 + 30)
        #expect(windows[2].startMinutes == 16 * 60 + 30)
        #expect(windows[2].endMinutes == 20 * 60)
        #expect(OasisSchedule.mealWindows(on: "2026-10-03", weekday: "Saturday").isEmpty)
        #expect(OasisSchedule.mealWindows(on: "2026-09-21", weekday: "Monday").isEmpty)
        #expect(OasisSchedule.todayHours(on: "2026-10-22", weekday: "Thursday") == "11:00 AM – 8:00 PM")
        #expect(OasisSchedule.isOpen(on: "2026-10-22", weekday: "Thursday", nowMinutes: 16 * 60 + 56))
        #expect(OasisSchedule.isOpen(on: "2026-10-22", weekday: "Thursday", nowMinutes: 15 * 60))
        #expect(!OasisSchedule.isOpen(on: "2026-10-22", weekday: "Thursday", nowMinutes: 10 * 60))
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
    }

    @Test func placeholderUsesHubHoursWithoutInventingDishes() {
        let thursdayDinner = ISO8601DateFormatter().date(from: "2026-10-22T23:56:00Z")!
        let oasis = DiningService.oasisComingSoonLocation(dateISO: "2026-10-22", now: thursdayDinner)
        #expect(oasis.isComingSoon)
        #expect(oasis.comingSoonSubtitle == "Menu not posted")
        #expect(oasis.availablePeriods.isEmpty)
        #expect(oasis.openNow)
        #expect(oasis.todayHours == "11:00 AM – 8:00 PM")
        #expect(oasis.periods.map(\.name) == ["Lunch", "Afternoon Snack", "Dinner"])
        let tile = EatHallCardChrome.status(
            comingSoon: true,
            state: oasis.openState(nowMinutes: PacificTime.nowMinutes(now: thursdayDinner)),
            todayISO: "2026-10-22"
        )
        #expect(tile.primary == "Menu not posted")
        #expect(tile.tone == .open)
        #expect(tile.accessibilityLine == "Open, menu not posted")
    }
}

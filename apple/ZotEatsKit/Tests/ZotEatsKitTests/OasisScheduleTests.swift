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

    @Test func copyIsClosedUntilAnteaterAPIPostsAMenu() {
        #expect(OasisComingSoonCopy.cardStatus(on: "2026-09-21") == "Closed")
        #expect(OasisComingSoonCopy.selectedLine(on: "2026-09-21") == "This hall is closed until UCI posts a menu.")
        #expect(OasisComingSoonCopy.cardStatus(on: OasisSchedule.firstServiceISO) == "Closed")
        #expect(!OasisComingSoonCopy.selectedLine(on: OasisSchedule.firstServiceISO).contains("Oct"))
        #expect(!OasisComingSoonCopy.cardStatus.contains("Coming Soon"))
    }

    @Test func weekdayHoursMatchHubStandard() {
        let windows = OasisSchedule.mealWindows(on: "2026-10-05", weekday: "Monday")
        #expect(windows.map(\.name) == ["Lunch", "Dinner"])
        #expect(windows[0].startMinutes == 11 * 60)
        #expect(windows[0].endMinutes == 14 * 60 + 30)
        #expect(windows[1].startMinutes == 16 * 60 + 30)
        #expect(windows[1].endMinutes == 20 * 60)
        #expect(OasisSchedule.mealWindows(on: "2026-10-03", weekday: "Saturday").isEmpty)
        #expect(OasisSchedule.mealWindows(on: "2026-09-21", weekday: "Monday").isEmpty)
        #expect(OasisSchedule.todayHours(on: "2026-10-05", weekday: "Monday") == "11:00 AM – 8:00 PM")
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

    @Test func placeholderStaysClosedWithoutInferredHours() {
        let mondayNoon = ISO8601DateFormatter().date(from: "2026-10-05T19:30:00Z")!
        let oasis = DiningService.oasisComingSoonLocation(dateISO: "2026-10-05", now: mondayNoon)
        #expect(oasis.isComingSoon)
        #expect(oasis.comingSoonSubtitle == "Closed")
        #expect(oasis.availablePeriods.isEmpty)
        #expect(oasis.openNow == false)
        #expect(oasis.todayHours == nil)
        #expect(oasis.periods.isEmpty)
        let tile = EatHallCardChrome.status(
            comingSoon: true,
            state: oasis.openState(nowMinutes: PacificTime.nowMinutes(now: mondayNoon)),
            todayISO: "2026-10-05"
        )
        #expect(tile.primary == "Closed")
        #expect(tile.tone == .muted)
    }
}

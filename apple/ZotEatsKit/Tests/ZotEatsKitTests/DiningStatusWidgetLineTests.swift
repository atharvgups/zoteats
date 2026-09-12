import Testing
@testable import ZotEatsKit

@Suite("DiningStatusWidgetLine")
struct DiningStatusWidgetLineTests {
    @Test func openMealIsPeriodAndClock() {
        #expect(
            DiningStatusWidgetLine.resolve(
                state: .open(period: "Dinner", closesAt: 20 * 60),
                todayHours: "7:15 AM – 8:00 PM",
                opensTomorrowAtMinutes: 7 * 60 + 15,
                opensTomorrowPeriod: "Breakfast"
            ) == "Dinner · 8:00 PM"
        )
    }

    @Test func compactOpenDropsUntilFiller() {
        #expect(
            DiningStatusWidgetLine.resolve(
                state: .open(period: "Dinner", closesAt: 20 * 60),
                todayHours: nil,
                opensTomorrowAtMinutes: nil,
                opensTomorrowPeriod: nil,
                compact: true
            ) == "Dinner · 8PM"
        )
    }

    @Test func laterMealIsPeriodAndClock() {
        #expect(
            DiningStatusWidgetLine.resolve(
                state: .openingLater(period: "Lunch", opensAt: 11 * 60),
                todayHours: nil,
                opensTomorrowAtMinutes: nil,
                opensTomorrowPeriod: nil
            ) == "Lunch · 11:00 AM"
        )
    }

    @Test func tomorrowKeepsMealAndClock() {
        #expect(
            DiningStatusWidgetLine.resolve(
                state: .closedForToday,
                todayHours: nil,
                opensTomorrowAtMinutes: 7 * 60 + 15,
                opensTomorrowPeriod: "Breakfast"
            ) == "Breakfast tomorrow · 7:15 AM"
        )
    }

    @Test func splitMealAndClockAtTheDot() {
        let lunch = DiningStatusWidgetLine.splitMealAndClock("Lunch Thursday · 11:30 AM")
        #expect(lunch.meal == "Lunch Thursday")
        #expect(lunch.clock == "11:30 AM")
        let closed = DiningStatusWidgetLine.splitMealAndClock("Closed for today")
        #expect(closed.meal == "Closed for today")
        #expect(closed.clock == nil)
        let soon = DiningStatusWidgetLine.splitMealAndClock("Coming Soon")
        #expect(soon.clock == nil)
    }

    @Test func tightenCompactsClockForSmallTile() {
        #expect(DiningStatusWidgetLine.tighten("Dinner · 8:00 PM") == "Dinner · 8PM")
        #expect(DiningStatusWidgetLine.tighten("Breakfast tomorrow · 7:15 AM") == "Breakfast tomorrow · 7:15AM")
    }

    @Test func compactClockHelpers() {
        #expect(UCITime.formatCompact(minutes: 20 * 60) == "8PM")
        #expect(UCITime.formatCompact(minutes: 7 * 60 + 15) == "7:15AM")
    }
}

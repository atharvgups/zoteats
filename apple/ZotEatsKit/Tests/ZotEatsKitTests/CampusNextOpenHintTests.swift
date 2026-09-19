import Foundation
import Testing
@testable import ZotEatsKit

@Suite("CampusNextOpenHint")
struct CampusNextOpenHintTests {
    private func place(
        id: String,
        name: String,
        openNow: Bool = false,
        opensAt: Int? = nil,
        opensTomorrow: Int? = nil,
        opensNext: Int? = nil,
        nextWeekday: String? = nil,
        nextOffset: Int? = nil
    ) -> CampusPlace {
        CampusPlace(
            id: id,
            name: name,
            category: "Coffee & Cafés",
            openNow: openNow,
            todayHours: openNow ? "Open" : nil,
            opensAtMinutes: opensAt,
            opensTomorrowAtMinutes: opensTomorrow,
            opensNextAtMinutes: opensNext,
            opensNextDayOffset: nextOffset,
            opensNextWeekday: nextWeekday
        )
    }

    @Test func todayReopenWins() {
        let hint = CampusNextOpenHint.best(from: [
            place(id: "a", name: "Starbucks @ Student Center", opensAt: 7 * 60 + 30),
            place(id: "b", name: "Panda Express", opensAt: 10 * 60),
        ])
        #expect(hint?.placeID == "a")
        #expect(hint?.isTomorrow == false)
        #expect(hint?.line == "Starbucks opens at 7:30 AM")
    }

    @Test func tomorrowWhenNothingLeftToday() {
        let hint = CampusNextOpenHint.best(from: [
            place(id: "a", name: "Starbucks @ Student Center", opensTomorrow: 7 * 60 + 30),
            place(id: "b", name: "Zot N Go", opensTomorrow: 8 * 60),
        ])
        #expect(hint?.placeID == "a")
        #expect(hint?.isTomorrow == true)
        #expect(hint?.line == "Starbucks opens tomorrow at 7:30 AM")
    }

    @Test func earliestMinuteWinsWithNameTieBreak() {
        let hint = CampusNextOpenHint.best(from: [
            place(id: "z", name: "Zot Cafe", opensAt: 8 * 60),
            place(id: "a", name: "Anthill Pub", opensAt: 8 * 60),
        ])
        #expect(hint?.placeID == "a")
        #expect(hint?.shortName == "Anthill Pub")
    }

    @Test func ignoresAlreadyOpenPlaces() {
        let hint = CampusNextOpenHint.best(from: [
            place(id: "open", name: "Open Spot", openNow: true, opensAt: 6 * 60),
            place(id: "closed", name: "Closed Spot", opensAt: 9 * 60),
        ])
        #expect(hint?.placeID == "closed")
    }

    @Test func noHoursMeansNil() {
        #expect(
            CampusNextOpenHint.best(from: [
                place(id: "x", name: "Mystery"),
            ]) == nil
        )
    }

    @Test func prefersTodayOverTomorrowEvenIfTomorrowIsEarlierClock() {
        // Tomorrow 6 AM is "earlier" on the clock than today 10 AM, but today wins.
        let hint = CampusNextOpenHint.best(from: [
            place(id: "today", name: "Today Spot", opensAt: 10 * 60),
            place(id: "tmw", name: "Tomorrow Spot", opensTomorrow: 6 * 60),
        ])
        #expect(hint?.placeID == "today")
        #expect(hint?.isTomorrow == false)
    }

    @Test func laterWeekdayWhenWeekendOff() {
        let hint = CampusNextOpenHint.best(from: [
            place(
                id: "a",
                name: "Starbucks @ Student Center",
                opensNext: 7 * 60 + 30,
                nextWeekday: "Monday",
                nextOffset: 3
            ),
            place(
                id: "b",
                name: "Zot N Go",
                opensNext: 8 * 60,
                nextWeekday: "Monday",
                nextOffset: 3
            ),
        ])
        #expect(hint?.placeID == "a")
        #expect(hint?.weekday == "Monday")
        #expect(hint?.line == "Starbucks opens Monday at 7:30 AM")
    }
}

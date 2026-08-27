import Foundation
import Testing
@testable import ZotEatsKit

@Suite("GymWeekHours")
struct GymWeekHoursTests {
    @Test func displayRangeNormalizesWaitz() {
        #expect(GymWeekHours.displayRange("6am - 12pm") == "6:00 AM – 12:00 PM")
        #expect(GymWeekHours.displayRange("6:00am-11:00pm") == "6:00 AM – 11:00 PM")
        #expect(GymWeekHours.displayRange("open") == nil)
    }

    @Test func liveRangeOverridesTodayKeepsOtherDays() {
        let week = GymWeekHours.resolve(
            weekday: "Monday",
            todayHours: "6:00 AM – 12:00 PM",
            openNow: true,
            usingLiveRange: true,
            waitzReopenMinutes: nil,
            nowMinutes: 10 * 60
        )
        #expect(week.count == 7)
        #expect(week.first { $0.day == "Monday" }?.hours == "6:00 AM – 12:00 PM")
        #expect(week.first { $0.day == "Tuesday" }?.hours == "6:00 AM – 10:00 PM")
        #expect(GymService.todayWeekHoursDifferFromSchedule(week, weekday: "Monday"))
    }

    @Test func closedUntilAheadSaysOpensAt() {
        let week = GymWeekHours.resolve(
            weekday: "Monday",
            todayHours: "6:00 AM – 10:00 PM",
            openNow: false,
            usingLiveRange: false,
            waitzReopenMinutes: 12 * 60,
            nowMinutes: 10 * 60
        )
        #expect(week.first { $0.day == "Monday" }?.hours == "Opens at 12:00 PM")
        #expect(GymService.todayWeekHoursDifferFromSchedule(week, weekday: "Monday"))
    }

    @Test func closedUntilPastSaysOpensTomorrow() {
        let week = GymWeekHours.resolve(
            weekday: "Monday",
            todayHours: "6:00 AM – 10:00 PM",
            openNow: false,
            usingLiveRange: false,
            waitzReopenMinutes: 6 * 60,
            nowMinutes: 13 * 60
        )
        #expect(week.first { $0.day == "Monday" }?.hours == "Opens tomorrow at 6:00 AM")
    }

    @Test func scheduleOnlyWhenNoWaitz() {
        let week = GymWeekHours.resolve(
            weekday: "Thursday",
            todayHours: "6:00 AM – 10:00 PM",
            openNow: true,
            usingLiveRange: false,
            waitzReopenMinutes: nil,
            nowMinutes: 12 * 60
        )
        #expect(week.first { $0.day == "Thursday" }?.hours == "6:00 AM – 10:00 PM")
        #expect(!GymService.todayWeekHoursDifferFromSchedule(week, weekday: "Thursday"))
    }
}

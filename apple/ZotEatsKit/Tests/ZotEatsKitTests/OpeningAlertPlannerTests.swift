import Foundation
import Testing
@testable import ZotEatsKit

@Suite("OpeningAlertPlanner")
struct OpeningAlertPlannerTests {
    /// 2026-07-16 07:00 PDT (14:00 UTC).
    private let sevenAM = Date(timeIntervalSince1970: 1_784_210_400)

    private var candidates: [OpeningAlertPlanner.Candidate] {
        [
            .init(id: "campus:starbucks", name: "Starbucks @ Student Center", opensAtMinutes: 8 * 60),
            .init(id: "campus:halal-shack", name: "Halal Shack", opensAtMinutes: 11 * 60),
            .init(id: "campus:open-now", name: "Already Open Market", opensAtMinutes: nil),
            .init(id: "dining:anteatery", name: "The Anteatery", opensAtMinutes: 7 * 60 + 15),
        ]
    }

    @Test func plansOnlyWatchedPlacesSortedByFireTime() {
        let plans = OpeningAlertPlanner.plan(
            candidates: candidates,
            watchedIDs: ["campus:starbucks", "campus:halal-shack", "dining:anteatery"],
            now: sevenAM
        )
        #expect(plans.map(\.placeName) == ["The Anteatery", "Starbucks @ Student Center", "Halal Shack"])
    }

    @Test func openOrUnwatchedPlacesProduceNothing() {
        let plans = OpeningAlertPlanner.plan(
            candidates: candidates,
            watchedIDs: ["campus:open-now", "campus:not-a-candidate"],
            now: sevenAM
        )
        #expect(plans.isEmpty)
    }

    @Test func identifiersAreStablePerPlacePerDay() {
        let plans = OpeningAlertPlanner.plan(
            candidates: candidates, watchedIDs: ["campus:starbucks"], now: sevenAM
        )
        #expect(plans.first?.identifier == "open:campus:starbucks:2026-07-16")
    }

    @Test func fireDateLandsOnTheOpeningMinuteInIrvine() {
        let plans = OpeningAlertPlanner.plan(
            candidates: candidates, watchedIDs: ["campus:starbucks"], now: sevenAM
        )
        let fireDate = try! #require(plans.first?.fireDate)
        #expect(PacificTime.nowMinutes(now: fireDate) == 8 * 60)
        #expect(PacificTime.todayISO(now: fireDate) == "2026-07-16")
    }

    @Test func openingsEarlierTodayAreSkipped() {
        // 1:00 PM: Starbucks (8 AM) and the Anteatery breakfast are long open.
        let onePM = sevenAM.addingTimeInterval(6 * 3600)
        let plans = OpeningAlertPlanner.plan(
            candidates: candidates,
            watchedIDs: Set(candidates.map(\.id)),
            now: onePM
        )
        #expect(plans.isEmpty)
    }

    @Test func schedulesTomorrowWhenClosedForToday() {
        // 10 PM Pacific — nothing left today; tomorrow breakfast should still schedule.
        let tenPM = sevenAM.addingTimeInterval(15 * 3600)
        let plans = OpeningAlertPlanner.plan(
            candidates: [
                .init(
                    id: "dining:anteatery",
                    name: "The Anteatery",
                    opensAtMinutes: 7 * 60 + 15,
                    dayOffset: 1
                ),
            ],
            watchedIDs: ["dining:anteatery"],
            now: tenPM
        )
        let plan = try! #require(plans.first)
        #expect(plan.identifier == "open:dining:anteatery:2026-07-17")
        #expect(PacificTime.todayISO(now: plan.fireDate) == "2026-07-17")
        #expect(PacificTime.nowMinutes(now: plan.fireDate) == 7 * 60 + 15)
    }

    @Test func schedulesDinnerWhileLunchIsOpen() {
        // Noon: caller passes dinner via followingOpening — alert must still fire today.
        let noon = sevenAM.addingTimeInterval(5 * 3600)
        let plans = OpeningAlertPlanner.plan(
            candidates: [
                .init(
                    id: "dining:anteatery",
                    name: "The Anteatery",
                    opensAtMinutes: 16 * 60 + 30,
                    dayOffset: 0
                ),
            ],
            watchedIDs: ["dining:anteatery"],
            now: noon
        )
        let plan = try! #require(plans.first)
        #expect(plan.identifier == "open:dining:anteatery:2026-07-16")
        #expect(PacificTime.nowMinutes(now: plan.fireDate) == 16 * 60 + 30)
    }

    @Test func schedulesTomorrowWhileCampusIsStillOpen() {
        // 2 PM: café open now; caller still passes tomorrow's open with dayOffset 1.
        let twoPM = sevenAM.addingTimeInterval(7 * 3600)
        let plans = OpeningAlertPlanner.plan(
            candidates: [
                .init(
                    id: "campus:starbucks",
                    name: "Starbucks @ Student Center",
                    opensAtMinutes: 7 * 60 + 30,
                    dayOffset: 1
                ),
            ],
            watchedIDs: ["campus:starbucks"],
            now: twoPM
        )
        let plan = try! #require(plans.first)
        #expect(plan.identifier == "open:campus:starbucks:2026-07-17")
        #expect(PacificTime.nowMinutes(now: plan.fireDate) == 7 * 60 + 30)
    }

    @Test func prefersTodayOverTomorrowWhenBothExist() {
        let plans = OpeningAlertPlanner.plan(
            candidates: [
                .init(id: "campus:starbucks", name: "Starbucks", opensAtMinutes: 8 * 60, dayOffset: 0),
                .init(id: "campus:starbucks", name: "Starbucks", opensAtMinutes: 8 * 60, dayOffset: 1),
            ],
            watchedIDs: ["campus:starbucks"],
            now: sevenAM
        )
        // Both would match the same place id — planner emits one alert per candidate.
        // Callers should only pass one; if both slip through, today fires first.
        #expect(plans.first?.identifier == "open:campus:starbucks:2026-07-16")
        #expect(plans.count == 2)
        #expect(plans[0].fireDate < plans[1].fireDate)
    }

    @Test func earliestOpeningPicksBreakfast() {
        let periods = [
            MealPeriodWindow(name: "Lunch", startMinutes: 11 * 60, endMinutes: 14 * 60),
            MealPeriodWindow(name: "Breakfast", startMinutes: 7 * 60 + 15, endMinutes: 11 * 60),
        ]
        #expect(OpeningAlertPlanner.earliestOpening(periods: periods) == 7 * 60 + 15)
        #expect(OpeningAlertPlanner.earliestOpening(periods: []) == nil)
    }
}

@Suite("OpeningAlertPlanner — dining next opening")
struct DiningNextOpeningTests {
    private let periods = [
        MealPeriodWindow(name: "Breakfast", startMinutes: 7 * 60 + 15, endMinutes: 11 * 60),
        MealPeriodWindow(name: "Lunch", startMinutes: 11 * 60, endMinutes: 14 * 60 + 30),
        MealPeriodWindow(name: "Dinner", startMinutes: 16 * 60 + 30, endMinutes: 21 * 60),
    ]

    @Test func beforeBreakfastPointsAtBreakfast() {
        #expect(OpeningAlertPlanner.nextOpening(periods: periods, nowMinutes: 6 * 60) == 7 * 60 + 15)
    }

    @Test func duringServiceIsNil() {
        #expect(OpeningAlertPlanner.nextOpening(periods: periods, nowMinutes: 12 * 60) == nil)
    }

    @Test func followingOpeningDuringLunchPointsAtDinner() {
        #expect(OpeningAlertPlanner.followingOpening(periods: periods, nowMinutes: 12 * 60) == 16 * 60 + 30)
    }

    @Test func followingOpeningMatchesNextOpeningWhenClosed() {
        #expect(OpeningAlertPlanner.followingOpening(periods: periods, nowMinutes: 6 * 60) == 7 * 60 + 15)
        #expect(OpeningAlertPlanner.followingOpening(periods: periods, nowMinutes: 15 * 60) == 16 * 60 + 30)
        #expect(OpeningAlertPlanner.followingOpening(periods: periods, nowMinutes: 22 * 60) == nil)
    }

    @Test func betweenLunchAndDinnerPointsAtDinner() {
        #expect(OpeningAlertPlanner.nextOpening(periods: periods, nowMinutes: 15 * 60) == 16 * 60 + 30)
    }

    @Test func afterCloseIsNil() {
        #expect(OpeningAlertPlanner.nextOpening(periods: periods, nowMinutes: 22 * 60) == nil)
    }

    @Test func noTimedPeriodsIsNil() {
        let untimed = [MealPeriodWindow(name: "All Day", startMinutes: nil, endMinutes: nil)]
        #expect(OpeningAlertPlanner.nextOpening(periods: untimed, nowMinutes: 9 * 60) == nil)
        #expect(OpeningAlertPlanner.followingOpening(periods: untimed, nowMinutes: 9 * 60) == nil)
    }
}

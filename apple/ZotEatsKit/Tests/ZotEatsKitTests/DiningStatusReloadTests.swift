import Foundation
import Testing
@testable import ZotEatsKit

@Suite("DiningStatusReload")
struct DiningStatusReloadTests {
    private func hall(
        id: String,
        name: String,
        periods: [MealPeriodWindow],
        opensTomorrowAtMinutes: Int? = 435
    ) -> DiningLocation {
        DiningLocation(
            id: id,
            name: name,
            area: "UTC",
            openNow: true,
            todayHours: nil,
            availablePeriods: periods.map(\.name),
            periods: periods,
            hoursApproximate: false,
            opensTomorrowAtMinutes: opensTomorrowAtMinutes
        )
    }

    @Test func closedTipIncludesMorningProbes() {
        // Monday 2026-07-13, 7:50 AM Pacific — 8:00 probe is 10m away.
        let now = ISO8601DateFormatter().date(from: "2026-07-13T14:50:00Z")!
        let nowMinutes = UCITime.nowMinutes(now: now)
        let boundaries = DiningStatusReload.boundaries(
            locations: [],
            nowMinutes: nowMinutes,
            now: now,
            librariesClosed: true
        )
        let eight = UCITime.date(
            forMinutes: 8 * 60,
            nowMinutes: nowMinutes,
            now: now
        )
        #expect(boundaries.contains(eight))
        #expect(boundaries.contains(UCITime.nextIrvineMidnight(now: now)))

        let reload = DiningStatusReload.nextReload(
            locations: [],
            nowMinutes: nowMinutes,
            now: now,
            librariesClosed: true
        )
        #expect(reload == eight.addingTimeInterval(2))
    }

    @Test func openTipSkipsMorningProbesKeepsMidnight() {
        let now = ISO8601DateFormatter().date(from: "2026-07-13T17:00:00Z")! // Mon 10 AM PDT
        let nowMinutes = UCITime.nowMinutes(now: now)
        let boundaries = DiningStatusReload.boundaries(
            locations: [],
            nowMinutes: nowMinutes,
            now: now,
            librariesClosed: false
        )
        let midnight = UCITime.nextIrvineMidnight(now: now)
        // Meal + Quietest both contribute midnight; no morning open probes.
        #expect(Set(boundaries) == [midnight])
        for hour in QuietestLibraryReload.morningOpenMinutes {
            let probe = UCITime.date(forMinutes: hour, nowMinutes: nowMinutes, now: now)
            #expect(probe == midnight || !boundaries.contains(probe))
        }
    }

    @Test func soonHallCloseBeatsMorningProbe() {
        let now = ISO8601DateFormatter().date(from: "2026-07-13T14:50:00Z")! // Mon 7:50 AM PDT
        let nowMinutes = UCITime.nowMinutes(now: now)
        let locations = [
            hall(
                id: "anteatery",
                name: "The Anteatery",
                periods: [
                    MealPeriodWindow(name: "Breakfast", startMinutes: 435, endMinutes: 480),
                ],
                opensTomorrowAtMinutes: nil
            ),
        ]
        // Breakfast ends at 8:00 — 10m away, same as the Quietest 8:00 probe.
        let reload = DiningStatusReload.nextReload(
            locations: locations,
            nowMinutes: nowMinutes,
            now: now,
            librariesClosed: true
        )
        let breakfastClose = UCITime.date(
            forMinutes: 480,
            nowMinutes: nowMinutes,
            now: now
        )
        #expect(reload == breakfastClose.addingTimeInterval(2))
    }

    @Test func dinnerOpenArmedWhileLunchStillServing() {
        // Mon noon — chrome countdown is Lunch close; Dinner start must still wake.
        let now = ISO8601DateFormatter().date(from: "2026-07-13T19:00:00Z")!
        let nowMinutes = UCITime.nowMinutes(now: now)
        let locations = [
            hall(
                id: "anteatery",
                name: "The Anteatery",
                periods: [
                    MealPeriodWindow(name: "Lunch", startMinutes: 660, endMinutes: 870),
                    MealPeriodWindow(name: "Dinner", startMinutes: 990, endMinutes: 1200),
                ]
            ),
        ]
        let boundaries = DiningStatusReload.boundaries(
            locations: locations,
            nowMinutes: nowMinutes,
            now: now,
            librariesClosed: false
        )
        let dinnerOpen = UCITime.date(forMinutes: 990, nowMinutes: nowMinutes, now: now)
        let lunchClose = UCITime.date(forMinutes: 870, nowMinutes: nowMinutes, now: now)
        #expect(boundaries.contains(dinnerOpen))
        #expect(boundaries.contains(lunchClose))
    }

    @Test func siblingHallCloseArmed() {
        let now = ISO8601DateFormatter().date(from: "2026-07-13T19:00:00Z")! // Mon noon PDT
        let nowMinutes = UCITime.nowMinutes(now: now)
        let locations = [
            hall(
                id: "anteatery",
                name: "The Anteatery",
                periods: [
                    MealPeriodWindow(name: "Lunch", startMinutes: 660, endMinutes: 870),
                ]
            ),
            hall(
                id: "mesa",
                name: "Mesa Court",
                periods: [
                    MealPeriodWindow(name: "Lunch", startMinutes: 660, endMinutes: 900),
                ]
            ),
        ]
        let boundaries = DiningStatusReload.boundaries(
            locations: locations,
            nowMinutes: nowMinutes,
            now: now,
            librariesClosed: false
        )
        #expect(boundaries.contains(
            UCITime.date(forMinutes: 870, nowMinutes: nowMinutes, now: now)
        ))
        #expect(boundaries.contains(
            UCITime.date(forMinutes: 900, nowMinutes: nowMinutes, now: now)
        ))
        let reload = DiningStatusReload.nextReload(
            locations: locations,
            nowMinutes: nowMinutes,
            now: now,
            librariesClosed: false,
            maxInterval: 4 * 60 * 60
        )
        let anteateryClose = UCITime.date(forMinutes: 870, nowMinutes: nowMinutes, now: now)
        #expect(reload == anteateryClose.addingTimeInterval(2))
    }

    @Test func tomorrowOpenArmedDuringLastMeal() {
        let now = ISO8601DateFormatter().date(from: "2026-07-14T02:00:00Z")! // Mon 7 PM PDT
        let nowMinutes = UCITime.nowMinutes(now: now)
        let locations = [
            hall(
                id: "anteatery",
                name: "The Anteatery",
                periods: [
                    MealPeriodWindow(name: "Dinner", startMinutes: 990, endMinutes: 1200),
                ],
                opensTomorrowAtMinutes: 7 * 60 + 15
            ),
        ]
        let boundaries = DiningStatusReload.boundaries(
            locations: locations,
            nowMinutes: nowMinutes,
            now: now,
            librariesClosed: false
        )
        let tomorrow = UCITime.date(
            forMinutes: 7 * 60 + 15,
            nowMinutes: nowMinutes,
            now: now
        )
        #expect(boundaries.contains(tomorrow))
        #expect(boundaries.contains(UCITime.nextIrvineMidnight(now: now)))
    }

    @Test func openQuietestTipUsesTenMinuteCadence() {
        // Mid-morning with no soon meal edge — live Quietest % must match Quietest widget.
        let now = ISO8601DateFormatter().date(from: "2026-07-13T17:00:00Z")! // Mon 10 AM PDT
        let nowMinutes = UCITime.nowMinutes(now: now)
        let reload = DiningStatusReload.nextReload(
            locations: [],
            nowMinutes: nowMinutes,
            now: now,
            librariesClosed: false,
            quietestTipOpen: true
        )
        #expect(reload == now.addingTimeInterval(DiningStatusReload.quietestOpenMaxInterval))
    }

    @Test func closedOrMissingTipKeepsTwentyMinuteCadence() {
        let now = ISO8601DateFormatter().date(from: "2026-07-13T17:00:00Z")! // Mon 10 AM PDT
        let nowMinutes = UCITime.nowMinutes(now: now)
        let closed = DiningStatusReload.nextReload(
            locations: [],
            nowMinutes: nowMinutes,
            now: now,
            librariesClosed: true,
            quietestTipOpen: false
        )
        // Morning probes already passed at 10 AM — 20m closed cadence.
        #expect(closed == now.addingTimeInterval(DiningStatusReload.defaultMaxInterval))

        let missing = DiningStatusReload.nextReload(
            locations: [],
            nowMinutes: nowMinutes,
            now: now,
            librariesClosed: false,
            quietestTipOpen: false
        )
        #expect(missing == now.addingTimeInterval(DiningStatusReload.defaultMaxInterval))
    }

    @Test func mealEdgeBeatsOpenQuietestCadence() {
        // Mon noon — Lunch close at 2:30 PM is hours away; with open tip, 10m cap wins.
        // Sit 5 minutes before Lunch close so meal edge beats 10m.
        let now = ISO8601DateFormatter().date(from: "2026-07-13T21:25:00Z")! // Mon 2:25 PM PDT
        let nowMinutes = UCITime.nowMinutes(now: now)
        let locations = [
            hall(
                id: "anteatery",
                name: "The Anteatery",
                periods: [
                    MealPeriodWindow(name: "Lunch", startMinutes: 660, endMinutes: 870),
                ],
                opensTomorrowAtMinutes: nil
            ),
        ]
        let reload = DiningStatusReload.nextReload(
            locations: locations,
            nowMinutes: nowMinutes,
            now: now,
            librariesClosed: false,
            quietestTipOpen: true
        )
        let lunchClose = UCITime.date(forMinutes: 870, nowMinutes: nowMinutes, now: now)
        #expect(reload == lunchClose.addingTimeInterval(2))
        #expect(reload < now.addingTimeInterval(DiningStatusReload.quietestOpenMaxInterval))
    }
}

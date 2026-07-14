import Foundation
import Testing
@testable import ZotEatsKit

/// Thursday 2026-07-09, 12:30 PM Pacific.
private let weekdayNoon = ISO8601DateFormatter().date(from: "2026-07-09T19:30:00Z")!
/// Thursday 2026-07-09, 6:30 PM Pacific (peak dinner/gym time).
private let weekdayEvening = ISO8601DateFormatter().date(from: "2026-07-10T01:30:00Z")!
/// Saturday 2026-07-11, 12:30 PM Pacific.
private let weekendNoon = ISO8601DateFormatter().date(from: "2026-07-11T19:30:00Z")!

private let mealDay = [
    MealPeriodWindow(name: "Breakfast", startMinutes: 435, endMinutes: 630),   // 7:15–10:30
    MealPeriodWindow(name: "Lunch", startMinutes: 660, endMinutes: 870),       // 11:00–14:30
    MealPeriodWindow(name: "Dinner", startMinutes: 990, endMinutes: 1200),     // 16:30–20:00
]

@Suite("TypicalBusyness — dining")
struct TypicalDiningTests {
    @Test func curvePeaksInsideMealWindowsAndIsZeroWhenClosed() {
        let curve = TypicalBusyness.diningCurve(periods: mealDay, isWeekend: false)
        #expect(curve.count == 24)
        // Closed hours are zero.
        #expect(curve[3] == 0)
        #expect(curve[22] == 0)
        // Between breakfast and lunch (10:30–11:00 gap hour has lunch by midpoint rule)…
        // Lunch and dinner rushes register strongly.
        #expect(curve[12] >= 70)
        #expect(curve[17] >= 70)
        // Dinner outdraws breakfast.
        #expect(curve[17] > curve[8])
        // The global peak lands inside a meal window.
        let peakHour = curve.firstIndex(of: curve.max()!)!
        let peakMinute = peakHour * 60 + 30
        #expect(mealDay.contains { peakMinute >= $0.startMinutes! && peakMinute < $0.endMinutes! })
    }

    @Test func weekendsRunLighter() {
        let weekday = TypicalBusyness.diningCurve(periods: mealDay, isWeekend: false)
        let weekend = TypicalBusyness.diningCurve(periods: mealDay, isWeekend: true)
        #expect(weekend[12] < weekday[12])
    }

    @Test func estimateReflectsTheCurrentHour() {
        let estimate = TypicalBusyness.dining(periods: mealDay, now: weekdayNoon)
        #expect(estimate.percentNow >= 70) // 12:30 PM = mid-lunch rush
        #expect(estimate.levelNow != .unknown)
        #expect(estimate.busiestSummary?.contains("Usually busiest") == true)
        #expect(estimate.quietestSummary?.contains("quietest") == true)
    }

    @Test func noPeriodsMeansNoEstimate() {
        let estimate = TypicalBusyness.dining(periods: [], now: weekdayNoon)
        #expect(estimate.percentNow == 0)
        #expect(estimate.levelNow == .unknown)
        #expect(estimate.busiestSummary == nil)
    }
}

@Suite("TypicalBusyness — ARC")
struct TypicalArcTests {
    @Test func weekdayEveningIsThePeak() {
        let curve = TypicalBusyness.arcCurve(weekday: "Thursday")
        #expect(curve[18] > curve[10])
        #expect(curve[18] >= 85)
        // Closed overnight (opens 6 AM weekdays).
        #expect(curve[4] == 0)
        #expect(curve[5] == 0)
        #expect(curve[6] > 0)
    }

    @Test func weekendsAreGentlerWithMiddayBump() {
        let saturday = TypicalBusyness.arcCurve(weekday: "Saturday")
        let thursday = TypicalBusyness.arcCurve(weekday: "Thursday")
        #expect(saturday.max()! < thursday.max()!)
        // Saturday closes at 9 PM; opens 8 AM.
        #expect(saturday[7] == 0)
        #expect(saturday[21] == 0)
        #expect(saturday[12] > 0)
    }

    @Test func estimateAtPeakTimeIsBusy() {
        let estimate = TypicalBusyness.arc(now: weekdayEvening)
        #expect(estimate.percentNow >= 80)
        #expect(estimate.levelNow == .veryBusy || estimate.levelNow == .busy)
        #expect(estimate.busiestSummary != nil)
    }

    @Test func nowLabels() {
        #expect(TypicalBusyness.nowLabel(forPercent: 0) == nil)
        #expect(TypicalBusyness.nowLabel(forPercent: 20) == "Usually quiet now")
        #expect(TypicalBusyness.nowLabel(forPercent: 55) == "Usually moderate now")
        #expect(TypicalBusyness.nowLabel(forPercent: 85) == "Usually packed now")
    }
}

@Suite("GymService busyness resolution")
struct GymBusynessResolutionTests {
    /// Feed stub whose response includes the ARC as a live-tracked facility.
    private struct ArcTrackedHTTP: HTTPFetching {
        func data(from url: URL) async throws -> Data {
            Data("""
            {"data":[{"name":"Anteater Recreation Center","id":99,"busyness":62,"people":310,
            "capacity":500,"isAvailable":true,"isOpen":true,"hourSummary":"6am - 12am"}]}
            """.utf8)
        }
    }

    @Test func liveArcDataOverridesTypical() async {
        let service = GymService(
            busyness: BusynessService(http: ArcTrackedHTTP(), now: { weekdayEvening }),
            now: { weekdayEvening }
        )
        let status = await service.status()
        #expect(status.busyness?.source == .live)
        #expect(status.busyness?.percent == 62)
        #expect(status.busyness?.count == 310)
        #expect(status.hoursApproximate == false)
        // The typical curve still rides along for the day chart.
        #expect(status.typicalCurve?.isEmpty == false)
    }

    @Test func typicalEstimateFillsInWhenFeedLacksArc() async {
        let service = GymService(
            busyness: BusynessService(http: FixtureHTTP(), now: { weekdayEvening }),
            now: { weekdayEvening }
        )
        let status = await service.status()
        #expect(status.busyness?.source == .typical)
        #expect((status.busyness?.percent ?? 0) >= 80) // Thursday 6:30 PM
        #expect(status.busiestSummary != nil)
        #expect(status.quietestSummary != nil)
    }

    @Test func typicalEstimateAlsoCoversFeedFailure() async {
        let service = GymService(
            busyness: BusynessService(http: FailingHTTP(), now: { weekdayNoon }),
            now: { weekdayNoon }
        )
        let status = await service.status()
        #expect(status.busyness?.source == .typical)
        #expect(status.hoursApproximate)
    }
}

import Testing
@testable import ZotEatsKit

@Suite("ArcWidgetGlance")
struct ArcWidgetGlanceTests {
    private func status(busyness: BusynessPoint?, openNow: Bool = true) -> GymStatus {
        GymStatus(
            name: "ARC",
            openNow: openNow,
            todayHours: "6 AM–12 AM",
            weekHours: [],
            busyness: busyness,
            hoursApproximate: true
        )
    }

    private func point(percent: Int?, source: BusynessSource) -> BusynessPoint {
        BusynessPoint(
            id: 1,
            name: "ARC",
            category: "Recreation",
            count: nil,
            capacity: nil,
            percent: percent,
            level: .busy,
            isOpen: true,
            hoursSummary: nil,
            updatedAt: .now,
            subLocations: nil,
            source: source
        )
    }

    @Test func liveSensorsSurfaceAsLive() {
        let crowding = ArcWidgetGlance.crowding(
            from: status(busyness: point(percent: 42, source: .live))
        )
        #expect(crowding?.percent == 42)
        #expect(crowding?.isTypical == false)
        #expect(crowding?.sourceLabel == "live")
    }

    @Test func typicalEstimateSurfacesWhenFeedLacksArc() {
        let crowding = ArcWidgetGlance.crowding(
            from: status(busyness: point(percent: 55, source: .typical))
        )
        #expect(crowding?.percent == 55)
        #expect(crowding?.isTypical == true)
        #expect(crowding?.sourceLabel == "typical")
    }

    @Test func missingBusynessMeansNoCrowding() {
        #expect(ArcWidgetGlance.crowding(from: status(busyness: nil)) == nil)
    }

    @Test func nilPercentMeansNoCrowding() {
        #expect(ArcWidgetGlance.crowding(
            from: status(busyness: point(percent: nil, source: .live))
        ) == nil)
    }

    @Test func closedHidesStaleLivePercent() {
        #expect(
            ArcWidgetGlance.crowding(
                from: status(
                    busyness: point(percent: 42, source: .live),
                    openNow: false
                )
            ) == nil
        )
    }

    @Test func closedHidesTypicalPercentToo() {
        #expect(
            ArcWidgetGlance.crowding(
                from: status(
                    busyness: point(percent: 55, source: .typical),
                    openNow: false
                )
            ) == nil
        )
    }
}

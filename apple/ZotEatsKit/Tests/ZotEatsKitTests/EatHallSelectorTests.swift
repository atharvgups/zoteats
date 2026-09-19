import Foundation
import Testing
@testable import ZotEatsKit

@Suite("EatHallSelector")
struct EatHallSelectorTests {
    private func hall(
        id: String,
        comingSoon: Bool = false
    ) -> DiningLocation {
        DiningLocation(
            id: id,
            name: HallDirectory.displayName(for: id),
            area: HallDirectory.area(for: id),
            openNow: false,
            todayHours: nil,
            availablePeriods: comingSoon ? [] : ["Lunch"],
            periods: [],
            hoursApproximate: true,
            comingSoonSubtitle: comingSoon ? OasisComingSoonCopy.cardStatus : nil
        )
    }

    @Test func threeUpKeepsAnteateryBrandywineOasis() {
        let visible = EatHallSelector.visible([
            hall(id: "brandywine"),
            hall(id: "oasis", comingSoon: true),
            hall(id: "anteatery"),
            hall(id: "mesa-commons"),
        ])
        #expect(visible.map(\.id) == ["anteatery", "brandywine", "oasis"])
        #expect(visible.count == EatHallSelector.slotCount)
        #expect(!visible.contains { $0.id == "mesa-commons" })
    }

    @Test func missingOasisStillGetsAComingSoonTile() {
        let visible = EatHallSelector.visible([
            hall(id: "anteatery"),
            hall(id: "brandywine"),
        ])
        #expect(visible.map(\.id) == ["anteatery", "brandywine", "oasis"])
        #expect(visible.last?.isComingSoon == true)
    }

    @Test func emptyFeedShowsNothingUntilLocationsLoad() {
        #expect(EatHallSelector.visible([]).isEmpty)
    }

    @Test func cardWidthAlwaysSplitsThreeWays() {
        let width = EatHallSelector.cardWidth(containerWidth: 318, spacing: 6)
        #expect(width == 102)
        #expect(width * 3 + EatHallSelector.spacing * 2 == 318)
        #expect(EatHallSelector.fillsOneScreenWithoutScrolling)
    }

    @Test func mealSelectorNeverGrowsPastBreakfastLunchDinner() {
        #expect(DiningService.mealSelectorPills == ["Breakfast", "Lunch", "Dinner"])
        #expect(!DiningService.mealSelectorPills.contains("Brunch"))
        #expect(!DiningService.mealSelectorPills.contains("All Day"))
        #expect(MealPeriodPill.selectorPills(from: ["Breakfast", "Brunch", "Lunch", "Dinner", "All Day"])
            == ["Breakfast", "Lunch", "Dinner"])
    }
}

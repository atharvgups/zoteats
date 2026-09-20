import Foundation
import Testing
@testable import ZotEatsKit

@Suite("EatMealHeadline")
struct EatMealHeadlineTests {
    @Test func breakfastFollowsSelectedMeal() {
        #expect(EatMealHeadline.subtitle(period: "Breakfast", nowMinutes: 9 * 60) == "What’s for Breakfast")
        #expect(EatMealHeadline.subtitle(period: "Brunch", nowMinutes: 10 * 60) == "What’s for Breakfast")
        #expect(EatMealHeadline.subtitle(period: "Breakfast", nowMinutes: 2 * 60) == "What’s for Breakfast")
    }

    @Test func lunchAndDinnerFollowSelectedMeal() {
        #expect(EatMealHeadline.subtitle(period: "Lunch", nowMinutes: 8 * 60) == "What’s for Lunch")
        #expect(EatMealHeadline.subtitle(period: "Dinner", nowMinutes: 12 * 60) == "What’s for Dinner")
        #expect(EatMealHeadline.subtitle(period: "Limited Dinner", nowMinutes: 19 * 60) == "What’s for Dinner")
        #expect(EatMealHeadline.subtitle(period: "Dinner", nowMinutes: 22 * 60) == "What’s for Dinner")
    }

    @Test func clockFallbackWhenNoMealSelected() {
        #expect(EatMealHeadline.subtitle(period: nil, nowMinutes: 9 * 60) == "What’s for Breakfast")
        #expect(EatMealHeadline.subtitle(period: nil, nowMinutes: 13 * 60) == "What’s for Lunch")
        #expect(EatMealHeadline.subtitle(period: nil, nowMinutes: 15 * 60 + 30) == "What’s for Dinner")
        #expect(EatMealHeadline.subtitle(period: nil, nowMinutes: 19 * 60) == "What’s for Dinner")
    }
}

@Suite("EatMealPillMark")
struct EatMealPillMarkTests {
    @Test func mealPillsStaySmallerThanHallNames() {
        #expect(EatMealPillMark.pointSize == 15)
        #expect(EatMealPillMark.pointSize < EatHallTileMark.namePointSize)
        #expect(EatMealPillMark.minHeight == 36)
        #expect(EatMealPillMark.minHeight < EatHallTileMark.tileHeight)
        #expect(EatMealPillMark.verticalPadding == 7)
        #expect(EatMealPillMark.rowSpacing == 6)
    }
}

@Suite("CampusFilterChipMark")
struct CampusFilterChipMarkTests {
    @Test func tapTargetMeetsFortyFourPoints() {
        #expect(CampusFilterChipMark.minHeight == 44)
        #expect(CampusFilterChipMark.horizontalPadding >= 16)
        #expect(CampusFilterChipMark.verticalPadding >= 10)
    }
}

@Suite("EatDateStripMark")
struct EatDateStripMarkTests {
    @Test func daysSitApartWithAStrongSelectedStroke() {
        #expect(EatDateStripMark.spacing >= 8)
        #expect(EatDateStripMark.minHeight >= 36)
        #expect(EatDateStripMark.selectedStroke > 1)
    }
}

@Suite("ExpandChevron")
struct ExpandChevronTests {
    @Test func pointsRightWhenCollapsedAndDownWhenExpanded() {
        #expect(ExpandChevron.systemName(isExpanded: false) == "chevron.right")
        #expect(ExpandChevron.systemName(isExpanded: true) == "chevron.down")
    }
}

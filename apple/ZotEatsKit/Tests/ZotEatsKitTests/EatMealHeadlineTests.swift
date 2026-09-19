import Foundation
import Testing
@testable import ZotEatsKit

@Suite("EatMealHeadline")
struct EatMealHeadlineTests {
    @Test func breakfastFollowsSelectedMeal() {
        #expect(EatMealHeadline.subtitle(period: "Breakfast", hour: 9) == "What’s for breakfast?")
        #expect(EatMealHeadline.subtitle(period: "Brunch", hour: 10) == "What’s for breakfast?")
    }

    @Test func lunchAndDinnerFollowSelectedMeal() {
        #expect(EatMealHeadline.subtitle(period: "Lunch", hour: 8) == "What’s for lunch?")
        #expect(EatMealHeadline.subtitle(period: "Dinner", hour: 12) == "What’s for dinner?")
        #expect(EatMealHeadline.subtitle(period: "Limited Dinner", hour: 19) == "What’s for dinner?")
    }

    @Test func lateNightKeepsAQuietEasterEgg() {
        #expect(EatMealHeadline.subtitle(period: "Breakfast", hour: 2) == "Still hungry, Anteater?")
        #expect(EatMealHeadline.subtitle(period: "Dinner", hour: 22) == "Dinner plans, Anteater?")
    }

    @Test func generatedCopyStaysOneShortLine() {
        let fallback = EatMealHeadline.subtitle(period: "Lunch", hour: 12)
        #expect(
            EatMealHeadline.sanitizeGenerated(
                "“Hash browns before lecture.”\n",
                fallback: fallback
            ) == "Hash browns before lecture."
        )
        #expect(
            EatMealHeadline.sanitizeGenerated(
                String(repeating: "a", count: 80),
                fallback: fallback
            ) == fallback
        )
    }
}

@Suite("EatMealPillMark")
struct EatMealPillMarkTests {
    @Test func tapTargetMeetsFortyFourPoints() {
        #expect(EatMealPillMark.minHeight == 44)
        #expect(EatMealPillMark.pointSize >= 17)
        #expect(EatMealPillMark.verticalPadding >= 12)
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

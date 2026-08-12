import Foundation
import Testing
@testable import ZotEatsKit

@Suite("DiningMenuIdleAction")
struct DiningMenuIdleActionTests {
    @Test func locationsStillLoadingKeepsSkeleton() {
        #expect(
            DiningMenuIdleAction.resolve(
                locationsLoaded: false,
                availablePeriods: nil,
                selectedPeriod: nil
            ) == .loading
        )
    }

    @Test func emptyPeriodsMeansNoMenu() {
        #expect(
            DiningMenuIdleAction.resolve(
                locationsLoaded: true,
                availablePeriods: [],
                selectedPeriod: nil
            ) == .emptyNoMenu
        )
    }

    @Test func allDayOnlyMeansNoMenu() {
        #expect(
            DiningMenuIdleAction.resolve(
                locationsLoaded: true,
                availablePeriods: ["All Day"],
                selectedPeriod: nil
            ) == .emptyNoMenu
        )
    }

    @Test func primaryPillsWithSelectionKeepLoading() {
        #expect(
            DiningMenuIdleAction.resolve(
                locationsLoaded: true,
                availablePeriods: ["Breakfast", "Lunch", "Dinner"],
                selectedPeriod: "Lunch"
            ) == .loading
        )
    }

    @Test func primaryPillsWithoutSelectionMeansNoMenu() {
        #expect(
            DiningMenuIdleAction.resolve(
                locationsLoaded: true,
                availablePeriods: ["Breakfast", "Lunch"],
                selectedPeriod: nil
            ) == .emptyNoMenu
        )
    }

    @Test func browseDayPeriodsPendingKeepsSkeleton() {
        #expect(
            DiningMenuIdleAction.resolve(
                locationsLoaded: true,
                availablePeriods: nil,
                selectedPeriod: nil,
                browseDayPeriodsPending: true
            ) == .loading
        )
    }
}

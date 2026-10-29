import Foundation
import Testing
@testable import ZotEatsKit

@Suite("DishReportLogic")
struct DishReportTests {
    @Test func keysByDateHallMealAndDishID() {
        let first = DishReportLogic.upsert(
            existing: [],
            date: "2026-10-28",
            hall: "anteatery",
            meal: "Lunch",
            dishID: "1923_linguine",
            dishName: "Thai Curry Plant-Based Chicken Linguine",
            reason: .notAtHall,
            authorID: "a"
        )
        let otherHall = DishReportLogic.upsert(
            existing: first,
            date: "2026-10-28",
            hall: "brandywine",
            meal: "Lunch",
            dishID: "1923_linguine",
            dishName: "Thai Curry Plant-Based Chicken Linguine",
            reason: .notAtHall,
            authorID: "a"
        )
        #expect(otherHall.count == 2)
        #expect(
            !DishReportLogic.isReportedMissing(
                in: otherHall,
                date: "2026-10-28",
                hall: "anteatery",
                meal: "Lunch",
                dishID: "1923_linguine"
            )
        )
    }

    @Test func twoAuthorsTriggerReportedMissing() {
        var reports: [DishReport] = []
        reports = DishReportLogic.upsert(
            existing: reports,
            date: "2026-10-28",
            hall: "The-Anteatery",
            meal: "lunch",
            dishID: "sku-1",
            dishName: "Jasmine Rice",
            reason: .notServed,
            authorID: "one"
        )
        #expect(
            !DishReportLogic.isReportedMissing(
                in: reports,
                date: "2026-10-28",
                hall: "anteatery",
                meal: "Lunch",
                dishID: "sku-1"
            )
        )
        reports = DishReportLogic.upsert(
            existing: reports,
            date: "2026-10-28",
            hall: "anteatery",
            meal: "Lunch",
            dishID: "sku-1",
            dishName: "Jasmine Rice",
            reason: .wrongStation,
            authorID: "two"
        )
        #expect(
            DishReportLogic.isReportedMissing(
                in: reports,
                date: "2026-10-28",
                hall: "anteatery",
                meal: "Lunch",
                dishID: "sku-1",
                dishName: "Jasmine Rice"
            )
        )
        #expect(DishReportLogic.uniqueAuthorCount(
            in: reports,
            date: "2026-10-28",
            hall: "anteatery",
            meal: "Lunch",
            dishID: "sku-1"
        ) == 2)
    }

    @Test func sameAuthorUpsertsReasonWithoutRaisingCount() {
        var reports = DishReportLogic.upsert(
            existing: [],
            date: "2026-10-28",
            hall: "brandywine",
            meal: "Lunch",
            dishID: "1821_122168_M21043_1_18410",
            dishName: "Thai Curry Plant-Based Chicken Linguine",
            reason: .notAtHall,
            authorID: "me"
        )
        reports = DishReportLogic.upsert(
            existing: reports,
            date: "2026-10-28",
            hall: "brandywine",
            meal: "Lunch",
            dishID: "1821_122168_M21043_1_18410",
            dishName: "Thai Curry Plant-Based Chicken Linguine",
            reason: .wrongStation,
            authorID: "me"
        )
        #expect(reports.count == 1)
        #expect(reports[0].reason == .wrongStation)
        #expect(
            !DishReportLogic.isReportedMissing(
                in: reports,
                date: "2026-10-28",
                hall: "brandywine",
                meal: "Lunch",
                dishID: "1821_122168_M21043_1_18410"
            )
        )
    }

    @Test func emptyFieldsAreIgnored() {
        let next = DishReportLogic.upsert(
            existing: [],
            date: " ",
            hall: "anteatery",
            meal: "Lunch",
            dishID: "x",
            dishName: "Soup",
            reason: .notServed,
            authorID: "me"
        )
        #expect(next.isEmpty)
    }

    @Test func leavingMenuUnchangedNeverMovesDishes() {
        let linguine = MenuItem(
            id: "1821_122168_M21043_1_18410",
            name: "Thai Curry Plant-Based Chicken Linguine",
            description: nil,
            calories: 400,
            servingSize: nil,
            allergens: [],
            dietaryTags: ["Vegan"],
            stationID: "1893"
        )
        let rice = MenuItem(
            id: "1923_101628_M9650_1_11343",
            name: "Jasmine Rice",
            description: nil,
            calories: 150,
            servingSize: nil,
            allergens: [],
            dietaryTags: ["Vegan"],
            stationID: "1929"
        )
        let brandywine = DiningMenu(
            locationId: "brandywine",
            date: "2026-10-28",
            period: "Lunch",
            stations: [MenuStation(name: "The Twisted Root", items: [linguine], stationID: "1893")]
        )
        let anteatery = DiningMenu(
            locationId: "anteatery",
            date: "2026-10-28",
            period: "Lunch",
            stations: [MenuStation(name: "The Twisted Root", items: [rice], stationID: "1929")]
        )
        #expect(DishReportLogic.leavingMenuUnchanged(brandywine) == brandywine)
        #expect(DishReportLogic.leavingMenuUnchanged(anteatery) == anteatery)
        #expect(brandywine.stations[0].items.map(\.name) == ["Thai Curry Plant-Based Chicken Linguine"])
        #expect(anteatery.stations[0].items.map(\.name) == ["Jasmine Rice"])
    }

    @Test func copyHasNoEmDashes() {
        let copy = [
            DishReportCopy.rowTitle,
            DishReportCopy.sheetTitle,
            DishReportCopy.notAtHall,
            DishReportCopy.notServed,
            DishReportCopy.wrongStation,
            DishReportCopy.thanks,
            DishReportCopy.missingNote,
            DishReportCopy.cancel,
        ].joined()
        #expect(!copy.contains("\u{2014}"))
        #expect(!copy.contains("\u{2013}"))
        #expect(DishReportCopy.thanks == "Thanks, noted")
        #expect(DishReportCopy.rowTitle == "Report an issue")
        #expect(DishReportReason.allCases.map(\.title) == [
            DishReportCopy.notAtHall,
            DishReportCopy.notServed,
            DishReportCopy.wrongStation,
        ])
        #expect(DishReportReason.allCases.map(\.systemImage) == [
            "building.2",
            "fork.knife",
            "arrow.left.arrow.right",
        ])
        #expect(DishReportLogic.missingThreshold == 2)
    }

    @Test func oasisAndHubHallAliasesShareAKey() {
        #expect(DishReportLogic.canonicalHall("the-oasis-dining-hall") == "oasis")
        #expect(DishReportLogic.canonicalHall("the-anteatery") == "anteatery")
        #expect(DishReportLogic.canonicalMeal("Evening Snack") == "Late Night")
    }
}

import Testing
@testable import ZotEatsKit

@Suite("TodaysMenuAccessibilityLabel")
struct TodaysMenuAccessibilityLabelTests {
    @Test("Populated menu lists dishes")
    func populated() {
        #expect(
            TodaysMenuAccessibilityLabel.label(
                hallName: "The Anteatery",
                period: "Lunch",
                dishes: ["Pasta", "Salad", "Soup"],
                filtersEmptiedMenu: false,
                dishLimit: 2,
                surface: .home
            ) == "The Anteatery Lunch: Pasta, Salad"
        )
    }

    @Test("Filters empty matches glance and home copy")
    func filtersEmpty() {
        #expect(
            TodaysMenuAccessibilityLabel.label(
                hallName: "Brandywine",
                period: "Dinner",
                dishes: [],
                filtersEmptiedMenu: true,
                dishLimit: 4,
                surface: .glance
            ) == "Brandywine Dinner. Nothing matches Eat Filters"
        )
        #expect(
            TodaysMenuAccessibilityLabel.label(
                hallName: "Brandywine",
                period: "Dinner",
                dishes: [],
                filtersEmptiedMenu: true,
                dishLimit: 4,
                surface: .home
            ) == "Brandywine Dinner. Nothing matches your Eat Filters"
        )
    }

    @Test("After-hours empty matches glance and home copy")
    func afterHours() {
        #expect(
            TodaysMenuAccessibilityLabel.label(
                hallName: "The Anteatery",
                period: "",
                dishes: [],
                filtersEmptiedMenu: false,
                dishLimit: 4,
                surface: .glance
            ) == "The Anteatery. See you at breakfast"
        )
        #expect(
            TodaysMenuAccessibilityLabel.label(
                hallName: "The Anteatery",
                period: "",
                dishes: [],
                filtersEmptiedMenu: false,
                dishLimit: 4,
                surface: .home
            ) == "The Anteatery. Dinner's done — breakfast posts overnight"
        )
    }

    @Test("Not-posted empty matches glance and home copy")
    func notPosted() {
        #expect(
            TodaysMenuAccessibilityLabel.label(
                hallName: "Brandywine",
                period: "Lunch",
                dishes: [],
                filtersEmptiedMenu: false,
                dishLimit: 4,
                surface: .glance
            ) == "Brandywine Lunch. Menu not posted yet"
        )
        #expect(
            TodaysMenuAccessibilityLabel.label(
                hallName: "Brandywine",
                period: "Lunch",
                dishes: [],
                filtersEmptiedMenu: false,
                dishLimit: 4,
                surface: .home
            ) == "Brandywine Lunch. No menu posted right now — check back at the next meal"
        )
    }

    @Test("Empty never ends with a bare colon")
    func noBareColon() {
        let label = TodaysMenuAccessibilityLabel.label(
            hallName: "Hall",
            period: "Dinner",
            dishes: [],
            filtersEmptiedMenu: false,
            dishLimit: 3,
            surface: .glance
        )
        #expect(!label.hasSuffix(": "))
        #expect(!label.contains(": ,"))
    }
}

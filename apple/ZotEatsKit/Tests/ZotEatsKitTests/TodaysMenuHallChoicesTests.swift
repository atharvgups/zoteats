import Foundation
import Testing
@testable import ZotEatsKit

@Suite("TodaysMenuHallChoices")
struct TodaysMenuHallChoicesTests {
    private func hall(id: String, name: String) -> DiningLocation {
        DiningLocation(
            id: id,
            name: name,
            area: HallDirectory.area(for: id),
            openNow: false,
            todayHours: nil,
            availablePeriods: [],
            periods: [],
            hoursApproximate: true
        )
    }

    @Test func twoLiveHallsIncludeAutoThenBoth() {
        let options = TodaysMenuHallChoices.options(from: [
            hall(id: "anteatery", name: "The Anteatery"),
            hall(id: "brandywine", name: "Brandywine"),
        ])
        #expect(options.map(\.id) == ["auto", "anteatery", "brandywine"])
        #expect(options.map(\.title) == [
            TodaysMenuHallChoices.autoTitle,
            "The Anteatery",
            "Brandywine",
        ])
    }

    @Test func thirdCommonsAppearsWhenAPIListsIt() {
        let options = TodaysMenuHallChoices.options(from: [
            hall(id: "anteatery", name: "The Anteatery"),
            hall(id: "brandywine", name: "Brandywine"),
            hall(id: "mesa-commons", name: "Mesa Commons"),
        ])
        #expect(options.map(\.id) == ["auto", "anteatery", "brandywine", "mesa-commons"])
        #expect(options.last?.title == "Mesa Commons")
    }

    @Test func emptyLocationsFallBackToKnownHalls() {
        let options = TodaysMenuHallChoices.options(from: [])
        #expect(options.map(\.id) == ["auto"] + HallDirectory.fallbackIDs)
        #expect(options[1].title == HallDirectory.displayName(for: "anteatery"))
        #expect(options[2].title == HallDirectory.displayName(for: "brandywine"))
    }

    @Test func blankNamePrettifiesViaDirectory() {
        let options = TodaysMenuHallChoices.options(from: [
            hall(id: "mesa-commons", name: "  "),
        ])
        #expect(options.last?.title == "Mesa Commons")
    }
}

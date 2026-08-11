import Foundation
import Testing
@testable import ZotEatsKit

@Suite("CampusListEmptyAction")
struct CampusListEmptyActionTests {
    @Test func categoryWinsEvenWithOpenOnly() {
        #expect(CampusListEmptyAction.resolve(hasCategoryFilter: true, openOnly: true) == .clearCategory)
        #expect(CampusListEmptyAction.resolve(hasCategoryFilter: true, openOnly: false) == .clearCategory)
    }

    @Test func openOnlyWithoutCategoryShowsClosedCTA() {
        #expect(CampusListEmptyAction.resolve(hasCategoryFilter: false, openOnly: true) == .showClosed)
    }

    @Test func noFiltersMeansNoCTA() {
        #expect(CampusListEmptyAction.resolve(hasCategoryFilter: false, openOnly: false) == .none)
    }
}

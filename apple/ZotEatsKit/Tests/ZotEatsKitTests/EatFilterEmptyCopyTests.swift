import Testing
@testable import ZotEatsKit

@Suite("EatFilterEmptyCopy")
struct EatFilterEmptyCopyTests {
    @Test("Search alone does not blame dietary filters")
    func searchOnly() {
        let copy = EatFilterEmptyCopy.resolve(hasSearch: true, hasMenuFilters: false)
        #expect(copy?.title == "Nothing matches that search")
        #expect(copy?.message.contains("dish") == true)
        #expect(copy?.message.lowercased().contains("filter") != true)
        #expect(copy?.actionTitle == "Clear search")
        #expect(copy?.action == .clearSearch)
    }

    @Test("Filters alone keep clear-filters CTA")
    func filtersOnly() {
        let copy = EatFilterEmptyCopy.resolve(hasSearch: false, hasMenuFilters: true)
        #expect(copy?.title == "Nothing matches those filters")
        #expect(copy?.message.contains("Eat Filters") == true)
        #expect(copy?.actionTitle == "Clear filters")
        #expect(copy?.action == .clearFilters)
    }

    @Test("Search plus filters offers clear both")
    func both() {
        let copy = EatFilterEmptyCopy.resolve(hasSearch: true, hasMenuFilters: true)
        #expect(copy?.title == "Nothing matches")
        #expect(copy?.message.contains("search") == true)
        #expect(copy?.message.contains("filters") == true)
        #expect(copy?.actionTitle == "Clear both")
        #expect(copy?.action == .clearBoth)
    }

    @Test("Neither yields nil — UI should not use this path")
    func neither() {
        #expect(EatFilterEmptyCopy.resolve(hasSearch: false, hasMenuFilters: false) == nil)
    }
}

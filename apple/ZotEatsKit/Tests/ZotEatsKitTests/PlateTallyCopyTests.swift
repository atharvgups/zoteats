import Testing
@testable import ZotEatsKit

@Suite("PlateTallyCopy")
struct PlateTallyCopyTests {
    @Test func chipEmptyIsMyPlate() {
        #expect(PlateTallyCopy.chipTitle(count: 0) == "My Plate")
    }

    @Test func chipShowsCount() {
        #expect(PlateTallyCopy.chipTitle(count: 3) == "My Plate · 3")
    }

    @Test func barSingular() {
        #expect(PlateTallyCopy.barTitle(count: 1) == "1 on your plate")
    }

    @Test func barPlural() {
        #expect(PlateTallyCopy.barTitle(count: 4) == "4 on your plate")
    }

    @Test func browseAheadSingular() {
        #expect(PlateTallyCopy.browseAheadTitle(count: 1) == "Today's plate · 1")
    }

    @Test func browseAheadPlural() {
        #expect(PlateTallyCopy.browseAheadTitle(count: 2) == "Today's plate · 2")
    }
}

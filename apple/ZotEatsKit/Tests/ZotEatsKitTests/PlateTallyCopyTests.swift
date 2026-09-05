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

    @Test func caloriesValueIsHonestZero() {
        #expect(PlateTallyCopy.caloriesValue(0) == "0 cal")
        #expect(PlateTallyCopy.caloriesValue(689) == "689 cal")
        #expect(PlateTallyCopy.caloriesValue(-4) == "0 cal")
    }

    @Test func proteinValueIsHonestZero() {
        #expect(PlateTallyCopy.proteinValue(0) == "0g")
        #expect(PlateTallyCopy.proteinValue(23) == "23g")
    }

    @Test func macrosLineUpdatesWithTotals() {
        #expect(
            PlateTallyCopy.macrosLine(calories: 0, proteinG: 0)
                == "0 cal · 0g protein"
        )
        #expect(
            PlateTallyCopy.macrosLine(calories: 689, proteinG: 6)
                == "689 cal · 6g protein"
        )
    }
}

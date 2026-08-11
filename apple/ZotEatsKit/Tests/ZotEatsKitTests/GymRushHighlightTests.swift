import Testing
@testable import ZotEatsKit

@Suite("GymRushHighlight")
struct GymRushHighlightTests {
    @Test("Open paints the current hour")
    func openHighlightsNow() {
        #expect(GymRushHighlight.currentHour(openNow: true, nowMinutes: 14 * 60 + 20) == 14)
        #expect(GymRushHighlight.currentHour(openNow: true, nowMinutes: 0) == 0)
    }

    @Test("Closed drops the live now marker")
    func closedHasNoHighlight() {
        #expect(GymRushHighlight.currentHour(openNow: false, nowMinutes: 22 * 60) == nil)
        #expect(GymRushHighlight.currentHour(openNow: false, nowMinutes: 5 * 60) == nil)
    }
}

import Foundation
import Testing
@testable import ZotEatsKit

@Suite("WaitzHoursSummary")
struct WaitzHoursSummaryTests {
    @Test func parsesClosedUntilFormats() {
        #expect(WaitzHoursSummary.closedUntilMinutes("Closed until 8:00am") == 8 * 60)
        #expect(WaitzHoursSummary.closedUntilMinutes("Closed until 8:00 AM") == 8 * 60)
        #expect(WaitzHoursSummary.closedUntilMinutes("closed until 10:00pm") == 22 * 60)
        #expect(WaitzHoursSummary.closedUntilMinutes("Closed until 12:00pm") == 12 * 60)
        #expect(WaitzHoursSummary.closedUntilMinutes("Closed until 12am") == 0)
        #expect(WaitzHoursSummary.closedUntilMinutes("Closed until 7:30 AM") == 7 * 60 + 30)
    }

    @Test func rejectsOpenOrUnparseable() {
        #expect(WaitzHoursSummary.closedUntilMinutes("open") == nil)
        #expect(WaitzHoursSummary.closedUntilMinutes("Open") == nil)
        #expect(WaitzHoursSummary.closedUntilMinutes(nil) == nil)
        #expect(WaitzHoursSummary.closedUntilMinutes("  ") == nil)
        #expect(WaitzHoursSummary.closedUntilMinutes("Closed") == nil)
        #expect(WaitzHoursSummary.closedUntilMinutes("Closed until noon") == nil)
    }
}

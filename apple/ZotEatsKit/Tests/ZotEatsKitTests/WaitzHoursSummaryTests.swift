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

    @Test func displayableRangeRequiresParseableClocks() {
        #expect(WaitzHoursSummary.isDisplayableHoursRange("6:00am-11:00pm"))
        #expect(WaitzHoursSummary.isDisplayableHoursRange("6:00 AM – 10:00 PM"))
        #expect(WaitzHoursSummary.isDisplayableHoursRange("6am - 12am"))
        #expect(!WaitzHoursSummary.isDisplayableHoursRange("open"))
        #expect(!WaitzHoursSummary.isDisplayableHoursRange("Closed until 12:00pm"))
        #expect(!WaitzHoursSummary.isDisplayableHoursRange("Open 24 Hours"))
        #expect(!WaitzHoursSummary.isDisplayableHoursRange("foo-bar"))
        #expect(!WaitzHoursSummary.isDisplayableHoursRange(nil))
    }

    @Test func openUntilLineNormalizesClose() {
        #expect(WaitzHoursSummary.openUntilLine("6:00 AM – 12:00 AM") == "Open until 12:00 AM")
        #expect(WaitzHoursSummary.openUntilLine("6am - 12am") == "Open until 12:00 AM")
        #expect(WaitzHoursSummary.openUntilLine("6:00am-11:00pm") == "Open until 11:00 PM")
        #expect(WaitzHoursSummary.openUntilLine("open") == nil)
        #expect(WaitzHoursSummary.openUntilLine("Closed until 8:00am") == nil)
    }

    @Test func rangeBoundsParsesOpenAndClose() {
        #expect(WaitzHoursSummary.openMinutes("6:00am-11:00pm") == 6 * 60)
        #expect(WaitzHoursSummary.closeMinutes("6:00am-11:00pm") == 23 * 60)
        #expect(WaitzHoursSummary.closeMinutes("6am - 12am") == 0)
    }

    @Test("Closed-until beats stale feed isOpen")
    func effectivelyOpenClosedUntil() {
        #expect(
            !WaitzHoursSummary.isEffectivelyOpen(
                feedIsOpen: true,
                hoursSummary: "Closed until 8:00am",
                nowMinutes: 6 * 60
            )
        )
    }

    @Test("Displayable range beats stale feed after close")
    func effectivelyOpenPastClose() {
        #expect(
            !WaitzHoursSummary.isEffectivelyOpen(
                feedIsOpen: true,
                hoursSummary: "6:00am-12:00pm",
                nowMinutes: 14 * 60
            )
        )
    }

    @Test("Displayable range stays open inside window")
    func effectivelyOpenInRange() {
        #expect(
            WaitzHoursSummary.isEffectivelyOpen(
                feedIsOpen: false,
                hoursSummary: "6:00am-10:00pm",
                nowMinutes: 12 * 60
            )
        )
    }

    @Test("Midnight close treats 12am as end of day")
    func effectivelyOpenMidnightClose() {
        #expect(
            WaitzHoursSummary.isEffectivelyOpen(
                feedIsOpen: true,
                hoursSummary: "6am - 12am",
                nowMinutes: 22 * 60
            )
        )
        #expect(
            !WaitzHoursSummary.isEffectivelyOpen(
                feedIsOpen: true,
                hoursSummary: "6am - 12am",
                nowMinutes: 0
            )
        )
    }

    @Test("Bare open or nil hours trusts feed flag")
    func effectivelyOpenTrustsFeedWhenNoClock() {
        #expect(
            WaitzHoursSummary.isEffectivelyOpen(
                feedIsOpen: true,
                hoursSummary: "open",
                nowMinutes: 14 * 60
            )
        )
        #expect(
            !WaitzHoursSummary.isEffectivelyOpen(
                feedIsOpen: false,
                hoursSummary: nil,
                nowMinutes: 14 * 60
            )
        )
    }
}

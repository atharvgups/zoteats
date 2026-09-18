import Testing
@testable import ZotEatsKit

@Suite("ArcWidgetAccessibilityLabel")
struct ArcWidgetAccessibilityLabelTests {
    @Test("Closed with Opens at announces both")
    func closedOpensAt() {
        #expect(
            ArcWidgetAccessibilityLabel.label(
                isOpen: false,
                hoursLine: "Opens at 6:00 AM",
                percent: nil,
                isTypical: false
            ) == "ARC, closed, Opens at 6:00 AM"
        )
    }

    @Test("Closed with Opens tomorrow announces both")
    func closedOpensTomorrow() {
        #expect(
            ArcWidgetAccessibilityLabel.label(
                isOpen: false,
                hoursLine: "Opens tomorrow at 8:00 AM",
                percent: nil,
                isTypical: false
            ) == "ARC, closed, Opens tomorrow at 8:00 AM"
        )
    }

    @Test("Closed · hours line does not double closed")
    func closedDotHours() {
        #expect(
            ArcWidgetAccessibilityLabel.label(
                isOpen: false,
                hoursLine: "Closed · 6:00 AM – 12:00 AM",
                percent: nil,
                isTypical: false
            ) == "ARC, Closed · 6:00 AM – 12:00 AM"
        )
    }

    @Test("Open with live percent")
    func openLive() {
        #expect(
            ArcWidgetAccessibilityLabel.label(
                isOpen: true,
                hoursLine: "Open until 12:00 AM",
                percent: 42,
                isTypical: false
            ) == "ARC, open, 42 percent full, live, Open until 12:00 AM"
        )
    }

    @Test("Open with typical percent")
    func openTypical() {
        #expect(
            ArcWidgetAccessibilityLabel.label(
                isOpen: true,
                hoursLine: "Open until 12:00 AM",
                percent: 55,
                isTypical: true
            ) == "ARC, open, 55 percent full, typical estimate, Open until 12:00 AM"
        )
    }

    @Test("Open approximate hours appends schedule cue")
    func openApproximate() {
        #expect(
            ArcWidgetAccessibilityLabel.label(
                isOpen: true,
                hoursLine: "Open until 12:00 AM",
                percent: 42,
                isTypical: false,
                hoursApproximate: true
            ) == "ARC, open, 42 percent full, live, Open until 12:00 AM, schedule may be approximate"
        )
    }

    @Test("Closed Opens-at approximate appends cue after hours")
    func closedApproximate() {
        #expect(
            ArcWidgetAccessibilityLabel.label(
                isOpen: false,
                hoursLine: "Opens at 6:00 AM",
                percent: nil,
                isTypical: false,
                hoursApproximate: true
            ) == "ARC, closed, Opens at 6:00 AM, schedule may be approximate"
        )
    }

    @Test("Approximate with blank hours omits cue")
    func approximateBlankHours() {
        #expect(
            ArcWidgetAccessibilityLabel.label(
                isOpen: false,
                hoursLine: "  ",
                percent: nil,
                isTypical: false,
                hoursApproximate: true
            ) == "ARC, closed"
        )
    }

    @Test("Live open appends Updated freshness")
    func liveUpdated() {
        #expect(
            ArcWidgetAccessibilityLabel.label(
                isOpen: true,
                hoursLine: "Open until 12:00 AM",
                percent: 42,
                isTypical: false,
                updatedRelative: "just now"
            ) == "ARC, open, 42 percent full, live, Open until 12:00 AM, Updated just now"
        )
    }

    @Test("Live approximate then Updated")
    func approximateThenUpdated() {
        #expect(
            ArcWidgetAccessibilityLabel.label(
                isOpen: true,
                hoursLine: "Open until 12:00 AM",
                percent: 42,
                isTypical: false,
                hoursApproximate: true,
                updatedRelative: "just now"
            ) == "ARC, open, 42 percent full, live, Open until 12:00 AM, schedule may be approximate, Updated just now"
        )
    }

    @Test("Typical omits Updated when not wired")
    func typicalNoUpdated() {
        #expect(
            ArcWidgetAccessibilityLabel.label(
                isOpen: true,
                hoursLine: "Open until 12:00 AM",
                percent: 55,
                isTypical: true,
                updatedRelative: nil
            ) == "ARC, open, 55 percent full, typical estimate, Open until 12:00 AM"
        )
    }

    @Test("Blank updatedRelative is omitted")
    func blankUpdatedOmitted() {
        #expect(
            ArcWidgetAccessibilityLabel.label(
                isOpen: true,
                hoursLine: "Open until 12:00 AM",
                percent: 42,
                isTypical: false,
                updatedRelative: "  "
            ) == "ARC, open, 42 percent full, live, Open until 12:00 AM"
        )
    }
}

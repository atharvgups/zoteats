import Testing
@testable import ZotEatsKit

@Suite("GymRushAccessibilityLabel")
struct GymRushAccessibilityLabelTests {
    private func curve(peakAt hour: Int, value: Int = 80) -> [Int] {
        var c = Array(repeating: 0, count: 24)
        c[hour] = value
        return c
    }

    @Test("Empty or all-zero curve reports no rush data")
    func noRushData() {
        #expect(
            GymRushAccessibilityLabel.label(
                curve: Array(repeating: 0, count: 24),
                currentHour: 14,
                busiestSummary: nil,
                quietestSummary: nil
            ) == "Today at the ARC, typical estimate, No rush data for today"
        )
        #expect(
            GymRushAccessibilityLabel.label(
                curve: [],
                currentHour: nil,
                busiestSummary: nil,
                quietestSummary: nil
            ).contains("No rush data for today")
        )
    }

    @Test("Closed omits now, keeps peak and typical")
    func closedNoNow() {
        #expect(
            GymRushAccessibilityLabel.label(
                curve: curve(peakAt: 18),
                currentHour: nil,
                busiestSummary: nil,
                quietestSummary: nil
            ) == "Today at the ARC, typical estimate, Peak around 6 PM"
        )
    }

    @Test("Open includes now hour")
    func openIncludesNow() {
        #expect(
            GymRushAccessibilityLabel.label(
                curve: curve(peakAt: 18),
                currentHour: 14,
                busiestSummary: nil,
                quietestSummary: nil
            ) == "Today at the ARC, typical estimate, Peak around 6 PM, Now around 2 PM"
        )
    }

    @Test("Noon and midnight peak labels")
    func noonAndMidnight() {
        #expect(
            GymRushAccessibilityLabel.label(
                curve: curve(peakAt: 12),
                currentHour: nil,
                busiestSummary: nil,
                quietestSummary: nil
            ).contains("Peak around 12 PM")
        )
        #expect(
            GymRushAccessibilityLabel.label(
                curve: curve(peakAt: 0),
                currentHour: nil,
                busiestSummary: nil,
                quietestSummary: nil
            ).contains("Peak around 12 AM")
        )
    }

    @Test("Busiest and quietest summaries append when present")
    func summariesAppend() {
        #expect(
            GymRushAccessibilityLabel.label(
                curve: curve(peakAt: 17),
                currentHour: nil,
                busiestSummary: "Usually busiest 5 PM–8 PM",
                quietestSummary: "usually quietest around 10 AM"
            ) == "Today at the ARC, typical estimate, Peak around 5 PM, Usually busiest 5 PM–8 PM, usually quietest around 10 AM"
        )
    }

    @Test("Whitespace-only summaries are omitted")
    func stripsWhitespaceSummaries() {
        let label = GymRushAccessibilityLabel.label(
            curve: curve(peakAt: 10),
            currentHour: nil,
            busiestSummary: "  ",
            quietestSummary: "\n"
        )
        #expect(label == "Today at the ARC, typical estimate, Peak around 10 AM")
    }
}

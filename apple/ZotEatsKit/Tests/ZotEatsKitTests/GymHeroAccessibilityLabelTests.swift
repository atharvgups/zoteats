import Testing
@testable import ZotEatsKit

@Suite("GymHeroAccessibilityLabel")
struct GymHeroAccessibilityLabelTests {
    @Test("Closed with Opens at drops redundant idle Closed — opens")
    func closedOpensAt() {
        #expect(
            GymHeroAccessibilityLabel.label(
                isOpen: false,
                hoursLine: "Opens at 6:00 AM",
                percent: nil,
                levelLabel: nil,
                isTypical: false,
                peopleCount: nil,
                idleMessage: "Closed — opens at 6:00 AM"
            ) == "ARC, Anteater Recreation Center, closed, Opens at 6:00 AM"
        )
    }

    @Test("Closed with Opens tomorrow")
    func closedOpensTomorrow() {
        #expect(
            GymHeroAccessibilityLabel.label(
                isOpen: false,
                hoursLine: "Opens tomorrow at 8:00 AM",
                percent: nil,
                levelLabel: nil,
                isTypical: false,
                peopleCount: nil,
                idleMessage: "Closed — opens tomorrow at 8:00 AM"
            ) == "ARC, Anteater Recreation Center, closed, Opens tomorrow at 8:00 AM"
        )
    }

    @Test("Open live crowding with people")
    func openLive() {
        #expect(
            GymHeroAccessibilityLabel.label(
                isOpen: true,
                hoursLine: "Open until 12:00 AM",
                percent: 42,
                levelLabel: "Busy",
                isTypical: false,
                peopleCount: 180,
                idleMessage: nil
            ) == "ARC, Anteater Recreation Center, open, 42 percent full, Busy, live, 180 people, Open until 12:00 AM"
        )
    }

    @Test("Open typical estimate")
    func openTypical() {
        #expect(
            GymHeroAccessibilityLabel.label(
                isOpen: true,
                hoursLine: "Open until 12:00 AM",
                percent: 55,
                levelLabel: "Busy",
                isTypical: true,
                peopleCount: nil,
                idleMessage: nil
            ) == "ARC, Anteater Recreation Center, open, 55 percent full, Busy, typical estimate, Open until 12:00 AM"
        )
    }

    @Test("Open without crowding keeps idle estimate copy")
    func openNoCrowding() {
        #expect(
            GymHeroAccessibilityLabel.label(
                isOpen: true,
                hoursLine: "Open until 12:00 AM",
                percent: nil,
                levelLabel: nil,
                isTypical: false,
                peopleCount: nil,
                idleMessage: "No busyness estimate right now"
            ) == "ARC, Anteater Recreation Center, open, No busyness estimate right now, Open until 12:00 AM"
        )
    }

    @Test("Live open appends Updated freshness")
    func liveUpdated() {
        #expect(
            GymHeroAccessibilityLabel.label(
                isOpen: true,
                hoursLine: "Open until 12:00 AM",
                percent: 42,
                levelLabel: "Busy",
                isTypical: false,
                peopleCount: 180,
                idleMessage: nil,
                updatedRelative: "just now"
            ) == "ARC, Anteater Recreation Center, open, 42 percent full, Busy, live, 180 people, Open until 12:00 AM, Updated just now"
        )
    }

    @Test("Typical estimate omits Updated even if relative passed")
    func typicalOmitsUpdatedWhenNotWired() {
        // Call site only passes updatedRelative for live; helper still appends if given.
        #expect(
            GymHeroAccessibilityLabel.label(
                isOpen: true,
                hoursLine: "Open until 12:00 AM",
                percent: 55,
                levelLabel: "Busy",
                isTypical: true,
                peopleCount: nil,
                idleMessage: nil,
                updatedRelative: nil
            ) == "ARC, Anteater Recreation Center, open, 55 percent full, Busy, typical estimate, Open until 12:00 AM"
        )
    }

    @Test("Blank updatedRelative is omitted")
    func blankUpdatedOmitted() {
        #expect(
            GymHeroAccessibilityLabel.label(
                isOpen: true,
                hoursLine: "Open until 12:00 AM",
                percent: 42,
                levelLabel: "Busy",
                isTypical: false,
                peopleCount: nil,
                idleMessage: nil,
                updatedRelative: "  "
            ) == "ARC, Anteater Recreation Center, open, 42 percent full, Busy, live, Open until 12:00 AM"
        )
    }

    @Test("Approximate hours cue follows hoursLine")
    func approximateHours() {
        #expect(
            GymHeroAccessibilityLabel.label(
                isOpen: true,
                hoursLine: "Open until 12:00 AM",
                percent: nil,
                levelLabel: nil,
                isTypical: false,
                peopleCount: nil,
                idleMessage: "No busyness estimate right now",
                hoursApproximate: true
            ) == "ARC, Anteater Recreation Center, open, No busyness estimate right now, Open until 12:00 AM, schedule may be approximate"
        )
    }

    @Test("Approximate cue omitted when hoursLine blank")
    func approximateWithoutHours() {
        #expect(
            GymHeroAccessibilityLabel.label(
                isOpen: false,
                hoursLine: "  ",
                percent: nil,
                levelLabel: nil,
                isTypical: false,
                peopleCount: nil,
                idleMessage: nil,
                hoursApproximate: true
            ) == "ARC, Anteater Recreation Center, closed"
        )
    }

    @Test("Approximate cue comes before Updated freshness")
    func approximateBeforeUpdated() {
        #expect(
            GymHeroAccessibilityLabel.label(
                isOpen: true,
                hoursLine: "Open until 12:00 AM",
                percent: 42,
                levelLabel: "Busy",
                isTypical: false,
                peopleCount: nil,
                idleMessage: nil,
                updatedRelative: "just now",
                hoursApproximate: true
            ) == "ARC, Anteater Recreation Center, open, 42 percent full, Busy, live, Open until 12:00 AM, schedule may be approximate, Updated just now"
        )
    }
}

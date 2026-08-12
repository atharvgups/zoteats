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
}

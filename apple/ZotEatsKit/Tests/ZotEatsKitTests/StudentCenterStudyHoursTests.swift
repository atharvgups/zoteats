import Foundation
import Testing
@testable import ZotEatsKit

@Suite("StudentCenterStudyHours")
struct StudentCenterStudyHoursTests {
    @Test func weekdayAfternoonOpensCourtyardAndCommuter() {
        // Monday 2:00 PM Pacific
        let now = ISO8601DateFormatter().date(from: "2026-07-13T21:00:00Z")!
        let spaces = StudentCenterStudyHours.spaces(now: now)
        #expect(spaces.count == 3)
        #expect(spaces[0].name.contains("Courtyard"))
        #expect(spaces[0].isOpen)
        #expect(spaces[1].isOpen)
        #expect(spaces[2].isOpen)
        #expect(spaces[1].hours.contains("8:00 PM"))
    }

    @Test func weekendClosesHillsideAndUsesWeekendCommuterHours() {
        // Saturday 2:00 PM Pacific
        let now = ISO8601DateFormatter().date(from: "2026-07-18T21:00:00Z")!
        let spaces = StudentCenterStudyHours.spaces(now: now)
        #expect(spaces[1].hours.contains("5:00 PM"))
        #expect(spaces[2].isOpen == false)
        #expect(spaces[2].hours.localizedCaseInsensitiveContains("weekend"))
    }

    @Test func lateNightClosesAll() {
        // Monday 12:30 AM Pacific
        let now = ISO8601DateFormatter().date(from: "2026-07-13T07:30:00Z")!
        let spaces = StudentCenterStudyHours.spaces(now: now)
        #expect(spaces.allSatisfy { !$0.isOpen })
    }

    @Test func occupancyNoteIsHonest() {
        #expect(StudentCenterStudyHours.occupancyNote.localizedCaseInsensitiveContains("recalibrat"))
        #expect(!StudentCenterStudyHours.occupancyNote.localizedCaseInsensitiveContains("%"))
    }
}

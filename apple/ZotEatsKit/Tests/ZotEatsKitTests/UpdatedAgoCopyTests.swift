import Foundation
import Testing
@testable import ZotEatsKit

@Suite("UpdatedAgoCopy")
struct UpdatedAgoCopyTests {
    @Test("Under a minute is just now")
    func justNow() {
        let now = Date()
        let recent = now.addingTimeInterval(-30)
        #expect(UpdatedAgoCopy.relative(from: recent, now: now) == "just now")
        #expect(UpdatedAgoCopy.phrase(from: recent, now: now) == "Updated just now")
    }

    @Test("Minutes use short ago copy")
    func minutesAgo() {
        let now = Date()
        let past = now.addingTimeInterval(-5 * 60)
        #expect(UpdatedAgoCopy.relative(from: past, now: now) == "5 min. ago")
        #expect(UpdatedAgoCopy.phrase(from: past, now: now) == "Updated 5 min. ago")
    }

    @Test("Hours and days scale")
    func hoursAndDays() {
        let now = Date()
        #expect(
            UpdatedAgoCopy.relative(from: now.addingTimeInterval(-2 * 3600), now: now)
                == "2 hr. ago"
        )
        #expect(
            UpdatedAgoCopy.relative(from: now.addingTimeInterval(-2 * 86400), now: now)
                == "2 days ago"
        )
    }
}

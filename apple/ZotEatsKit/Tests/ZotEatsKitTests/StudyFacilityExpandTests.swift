import Foundation
import Testing
@testable import ZotEatsKit

@Suite("StudyFacilityExpand")
struct StudyFacilityExpandTests {
    @Test func prefersDeepLinkOverQuietest() {
        #expect(
            StudyFacilityExpand.targetID(
                pendingFacilityID: nil,
                deepLinkFacilityID: 2,
                quietestFacilityID: 1
            ) == 2
        )
    }

    @Test func pendingBeatsAppliedDeepLink() {
        #expect(
            StudyFacilityExpand.targetID(
                pendingFacilityID: 3,
                deepLinkFacilityID: 2,
                quietestFacilityID: 1
            ) == 3
        )
    }

    @Test func fallsBackToQuietest() {
        #expect(
            StudyFacilityExpand.targetID(
                pendingFacilityID: nil,
                deepLinkFacilityID: nil,
                quietestFacilityID: 1
            ) == 1
        )
    }

    @Test func pendingFacilityIDFromStudyLink() {
        #expect(
            StudyFacilityExpand.pendingFacilityID(from: .study(facilityID: 2)) == 2
        )
        #expect(StudyFacilityExpand.pendingFacilityID(from: .study()) == nil)
        #expect(StudyFacilityExpand.pendingFacilityID(from: .eat()) == nil)
        #expect(StudyFacilityExpand.pendingFacilityID(from: nil) == nil)
    }

    @Test("Bare Study / Libraries closed clears a prior pin")
    func nilFacilityClearsPin() {
        #expect(StudyFacilityExpand.pinAfterApplying(linkFacilityID: nil) == nil)
        #expect(!StudyFacilityExpand.shouldExpandPulse(linkFacilityID: nil))
        // After clear, target falls through to quietest (nil overnight).
        #expect(
            StudyFacilityExpand.targetID(
                pendingFacilityID: nil,
                deepLinkFacilityID: StudyFacilityExpand.pinAfterApplying(linkFacilityID: nil),
                quietestFacilityID: nil
            ) == nil
        )
    }

    @Test("Facility deep link still pins and pulses")
    func facilityPinWins() {
        #expect(StudyFacilityExpand.pinAfterApplying(linkFacilityID: 2) == 2)
        #expect(StudyFacilityExpand.shouldExpandPulse(linkFacilityID: 2))
        #expect(
            StudyFacilityExpand.targetID(
                pendingFacilityID: nil,
                deepLinkFacilityID: StudyFacilityExpand.pinAfterApplying(linkFacilityID: 2),
                quietestFacilityID: 1
            ) == 2
        )
    }
}

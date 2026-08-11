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
}

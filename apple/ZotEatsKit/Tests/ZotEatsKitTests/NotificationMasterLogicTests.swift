import Foundation
import Testing
@testable import ZotEatsKit

@Suite("NotificationMasterLogic")
struct NotificationMasterLogicTests {
    @Test func unsetMasterFollowsExistingChildren() {
        #expect(NotificationMasterLogic.masterEnabled(stored: nil, anyChildEnabled: true))
        #expect(!NotificationMasterLogic.masterEnabled(stored: nil, anyChildEnabled: false))
        #expect(NotificationMasterLogic.masterEnabled(stored: true, anyChildEnabled: false))
        #expect(!NotificationMasterLogic.masterEnabled(stored: false, anyChildEnabled: true))
    }

    @Test func firstMasterOnAppliesDefaults() {
        #expect(
            NotificationMasterLogic.shouldApplySensibleDefaults(
                masterJustEnabled: true,
                advancedCustomized: false,
                anyChildEnabled: false
            )
        )
        #expect(
            !NotificationMasterLogic.shouldApplySensibleDefaults(
                masterJustEnabled: true,
                advancedCustomized: true,
                anyChildEnabled: false
            )
        )
        #expect(
            !NotificationMasterLogic.shouldApplySensibleDefaults(
                masterJustEnabled: true,
                advancedCustomized: false,
                anyChildEnabled: true
            )
        )
        #expect(
            !NotificationMasterLogic.shouldApplySensibleDefaults(
                masterJustEnabled: false,
                advancedCustomized: false,
                anyChildEnabled: false
            )
        )
    }
}

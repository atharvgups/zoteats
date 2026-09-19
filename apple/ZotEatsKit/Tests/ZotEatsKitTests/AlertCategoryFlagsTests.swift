import Testing
@testable import ZotEatsKit

@Suite("AlertCategoryFlags")
struct AlertCategoryFlagsTests {
    @Test func masterOnEnablesEveryExistingCategory() {
        let flags = AlertCategoryFlags.applyingMaster(true)
        #expect(flags.diningOpen)
        #expect(flags.diningClosing)
        #expect(flags.campusHours)
        #expect(flags.libraryBusy)
        #expect(flags.masterOn)
    }

    @Test func masterOffClearsEveryExistingCategory() {
        let flags = AlertCategoryFlags.applyingMaster(false)
        #expect(!flags.diningOpen)
        #expect(!flags.diningClosing)
        #expect(!flags.campusHours)
        #expect(!flags.libraryBusy)
        #expect(!flags.masterOn)
    }

    @Test func mixedCategoriesKeepMasterOn() {
        let flags = AlertCategoryFlags(
            diningOpen: false,
            diningClosing: false,
            campusHours: false,
            libraryBusy: true
        )
        #expect(flags.masterOn)
    }

    @Test func emptyCategoriesKeepMasterOff() {
        let flags = AlertCategoryFlags(
            diningOpen: false,
            diningClosing: false,
            campusHours: false,
            libraryBusy: false
        )
        #expect(!flags.masterOn)
    }
}

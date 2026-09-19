import Foundation
import Testing
@testable import ZotEatsKit

@Suite("UsefulAlertCopy")
struct UsefulAlertCopyTests {
    @Test func diningClosingSoonNamesTheMeal() {
        #expect(
            UsefulAlertCopy.closingSoonTitle(placeName: "Brandywine", mealPeriod: "Dinner")
                == "Brandywine · Dinner closing soon"
        )
    }

    @Test func campusClosingSoonOmitsMeal() {
        #expect(
            UsefulAlertCopy.closingSoonTitle(placeName: "Starbucks", mealPeriod: nil)
                == "Starbucks closing soon"
        )
    }

    @Test func closingBodyUsesClock() {
        #expect(
            UsefulAlertCopy.closingSoonBody(closesAtMinutes: 21 * 60)
                == "Closes at 9:00 PM. Head over if you still need it."
        )
    }

    @Test func libraryBusyUsesRealPercent() {
        #expect(UsefulAlertCopy.libraryBusyTitle(name: "Langson") == "Langson is getting busy")
        #expect(
            UsefulAlertCopy.libraryBusyBody(percent: 82)
                == "Live Waitz reading: 82%. Open Study to pick a quieter floor."
        )
    }
}

import Foundation
import Testing
@testable import ZotEatsKit

@Suite("OpeningAlertCopy")
struct OpeningAlertCopyTests {
    @Test func diningUsesMealCloseNotDaySpan() {
        #expect(
            OpeningAlertCopy.body(openUntilMinutes: 21 * 60)
                == "Open until 9:00 PM. Head over when you're ready."
        )
    }

    @Test func limitedDinnerCloseFormats() {
        #expect(
            OpeningAlertCopy.body(openUntilMinutes: 19 * 60)
                == "Open until 7:00 PM. Head over when you're ready."
        )
    }

    @Test func campusKeepsContinuousSpan() {
        #expect(
            OpeningAlertCopy.body(hoursSpan: "7:30 AM – 4:00 PM")
                == "Open 7:30 AM – 4:00 PM. Head over when you're ready."
        )
    }

    @Test func missingHoursFallsBack() {
        #expect(
            OpeningAlertCopy.body()
                == "Doors are open — head over when you're ready."
        )
        #expect(
            OpeningAlertCopy.body(hoursSpan: "  ")
                == "Doors are open — head over when you're ready."
        )
    }

    @Test func mealCloseWinsOverSpan() {
        #expect(
            OpeningAlertCopy.body(
                openUntilMinutes: 14 * 60,
                hoursSpan: "7:15 AM – 8:00 PM"
            ) == "Open until 2:00 PM. Head over when you're ready."
        )
    }
}

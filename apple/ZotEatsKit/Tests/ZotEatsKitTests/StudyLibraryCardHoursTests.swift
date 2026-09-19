import Testing
@testable import ZotEatsKit

@Suite("StudyLibraryCardHours")
struct StudyLibraryCardHoursTests {
    private let langsonOpen = LibraryBuildingHours(
        id: "langson",
        shortName: "Langson",
        rendered: "8:00 AM – 11:00 PM",
        isOpen: true,
        openMinutes: 8 * 60,
        closeMinutes: 23 * 60
    )

    private let gatewayClosedSpan = LibraryBuildingHours(
        id: "science",
        shortName: "Gateway",
        rendered: "1:00 PM – 11:00 PM",
        isOpen: false,
        openMinutes: 13 * 60,
        closeMinutes: 23 * 60
    )

    private let closedOnly = LibraryBuildingHours(
        id: "langson",
        shortName: "Langson",
        rendered: "Closed",
        isOpen: false
    )

    @Test("Open cards prefer today’s LibCal span")
    func openPrefersTodaySpan() {
        #expect(
            StudyLibraryCardHours.line(
                isOpen: true,
                hoursSummary: "open",
                libraryHours: langsonOpen
            ) == "8:00 AM – 11:00 PM"
        )
    }

    @Test("Open cards fall back to Waitz Open until")
    func openFallsBackToWaitz() {
        #expect(
            StudyLibraryCardHours.line(
                isOpen: true,
                hoursSummary: "8:00am-10:00pm",
                libraryHours: nil
            ) == "Open until 10:00 PM"
        )
        #expect(
            StudyLibraryCardHours.line(
                isOpen: true,
                hoursSummary: "open",
                libraryHours: nil
            ) == nil
        )
    }

    @Test("Closed cards use Opens at from Waitz")
    func closedOpensAtFromWaitz() {
        #expect(
            StudyLibraryCardHours.line(
                isOpen: false,
                hoursSummary: "Closed until 1:00pm",
                libraryHours: closedOnly,
                nowMinutes: 11 * 60
            ) == "Opens at 1:00 PM"
        )
    }

    @Test("Closed cards use Opens at from LibCal when Waitz has no clock")
    func closedOpensAtFromLibCal() {
        #expect(
            StudyLibraryCardHours.line(
                isOpen: false,
                hoursSummary: "open",
                libraryHours: gatewayClosedSpan,
                nowMinutes: 11 * 60
            ) == "Opens at 1:00 PM"
        )
    }

    @Test("Closed cards omit a line that only repeats Closed")
    func closedOmitsRedundantClosed() {
        #expect(
            StudyLibraryCardHours.line(
                isOpen: false,
                hoursSummary: nil,
                libraryHours: closedOnly,
                nowMinutes: 11 * 60
            ) == nil
        )
        #expect(
            StudyLibraryCardHours.line(
                isOpen: false,
                hoursSummary: "open",
                libraryHours: nil,
                nowMinutes: 11 * 60
            ) == nil
        )
    }
}

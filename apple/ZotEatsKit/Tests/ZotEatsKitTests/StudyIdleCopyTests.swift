import Foundation
import Testing
@testable import ZotEatsKit

@Suite("StudyIdleCopy")
struct StudyIdleCopyTests {
    private func point(
        id: Int,
        name: String,
        category: String,
        isOpen: Bool,
        hoursSummary: String?
    ) -> BusynessPoint {
        BusynessPoint(
            id: id,
            name: name,
            category: category,
            count: nil,
            capacity: nil,
            percent: isOpen ? 12 : 0,
            level: BusynessService.level(forPercent: isOpen ? 12 : 0),
            isOpen: isOpen,
            hoursSummary: hoursSummary,
            updatedAt: Date(),
            subLocations: nil
        )
    }

    @Test func soonestReopenFromLibraryPool() {
        let langson = point(
            id: 1,
            name: "Langson Library",
            category: "Library",
            isOpen: false,
            hoursSummary: "Closed until 8:00am"
        )
        let science = point(
            id: 2,
            name: "Science Library",
            category: "Library",
            isOpen: false,
            hoursSummary: "Closed until 10:00am"
        )
        #expect(StudyIdleCopy.soonestReopenMinutes(from: [science, langson]) == 8 * 60)
    }

    @Test func soonestReopenNilWithoutClosedUntil() {
        let closed = point(
            id: 1,
            name: "Langson Library",
            category: "Library",
            isOpen: false,
            hoursSummary: "open"
        )
        #expect(StudyIdleCopy.soonestReopenMinutes(from: [closed]) == nil)
    }

    @Test func quietestClosedDetailPrefersOpensAt() {
        #expect(
            StudyIdleCopy.quietestClosedDetail(reopenMinutes: 8 * 60, nowMinutes: 6 * 60)
                == "Opens at 8:00 AM"
        )
        #expect(
            StudyIdleCopy.quietestClosedDetail(reopenMinutes: nil, nowMinutes: 6 * 60)
                == QuietestLibraryGlance.closedDetail
        )
    }

    @Test func quietestClosedDetailPastReopenSaysTomorrow() {
        #expect(
            StudyIdleCopy.quietestClosedDetail(reopenMinutes: 8 * 60, nowMinutes: 13 * 60)
                == "Opens tomorrow at 8:00 AM"
        )
    }

    @Test func facilityClosedDetailFromWaitz() {
        #expect(
            StudyIdleCopy.facilityClosedDetail(
                hoursSummary: "Closed until 8:00am",
                nowMinutes: 6 * 60
            ) == "Opens at 8:00 AM"
        )
        #expect(
            StudyIdleCopy.facilityClosedDetail(
                hoursSummary: "Closed until 12:00pm",
                nowMinutes: 10 * 60
            ) == "Opens at 12:00 PM"
        )
        #expect(
            StudyIdleCopy.facilityClosedDetail(
                hoursSummary: "Closed until 8:00am",
                nowMinutes: 13 * 60
            ) == "Opens tomorrow at 8:00 AM"
        )
        #expect(
            StudyIdleCopy.facilityClosedDetail(hoursSummary: nil, nowMinutes: 6 * 60)
                == StudyFacilityCrowding.closedDetail
        )
        #expect(
            StudyIdleCopy.facilityClosedDetail(hoursSummary: "open", nowMinutes: 6 * 60)
                == StudyFacilityCrowding.closedDetail
        )
    }

    @Test func facilityOpenDetailFromWaitzRange() {
        #expect(
            StudyIdleCopy.facilityOpenDetail(hoursSummary: "6:00am-11:00pm")
                == "Open until 11:00 PM"
        )
        #expect(
            StudyIdleCopy.facilityOpenDetail(hoursSummary: "6am - 12am")
                == "Open until 12:00 AM"
        )
        #expect(StudyIdleCopy.facilityOpenDetail(hoursSummary: "open") == nil)
        #expect(StudyIdleCopy.facilityOpenDetail(hoursSummary: "Closed until 8:00am") == nil)
        #expect(StudyIdleCopy.facilityOpenDetail(hoursSummary: nil) == nil)
    }

    @Test func facilityOpenDetailFallsBackToLibCal() {
        let hours = LibraryBuildingHours(
            id: "langson",
            shortName: "Langson",
            rendered: "8:00 AM – 8:00 PM",
            isOpen: true,
            openMinutes: 8 * 60,
            closeMinutes: 20 * 60
        )
        #expect(
            StudyIdleCopy.facilityOpenDetail(hoursSummary: "open", libraryHours: hours)
                == "Open until 8:00 PM"
        )
    }

    @Test func facilityClosedDetailFallsBackToLibCalOpen() {
        let hours = LibraryBuildingHours(
            id: "science",
            shortName: "Science",
            rendered: "8:00 AM – 8:00 PM",
            isOpen: false,
            openMinutes: 8 * 60,
            closeMinutes: 20 * 60
        )
        #expect(
            StudyIdleCopy.facilityClosedDetail(
                hoursSummary: nil,
                nowMinutes: 6 * 60,
                libraryHours: hours
            ) == "Opens at 8:00 AM"
        )
    }
}

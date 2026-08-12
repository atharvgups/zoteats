import Foundation
import Testing
@testable import ZotEatsKit

@Suite("QuietestLibraryGlance")
struct QuietestLibraryGlanceTests {
    private func point(
        id: Int,
        name: String,
        category: String,
        percent: Int?,
        isOpen: Bool,
        updatedAt: Date = Date()
    ) -> BusynessPoint {
        BusynessPoint(
            id: id,
            name: name,
            category: category,
            count: nil,
            capacity: nil,
            percent: percent,
            level: BusynessService.level(forPercent: percent),
            isOpen: isOpen,
            hoursSummary: nil,
            updatedAt: updatedAt,
            subLocations: nil
        )
    }

    @Test func closedLibrariesShowClosedGlance() {
        let closed = point(
            id: 2,
            name: "Science Library",
            category: "Library",
            percent: 10,
            isOpen: false
        )
        #expect(QuietestLibraryPick.best(from: [closed]) == nil)
        #expect(QuietestLibraryGlance.shouldShowClosed(from: [closed]))
        #expect(QuietestLibraryGlance.hasLibraryFacilities([closed]))
    }

    @Test func openPickSuppressesClosedGlance() {
        let open = point(
            id: 2,
            name: "Science Library",
            category: "Library",
            percent: 12,
            isOpen: true
        )
        #expect(QuietestLibraryPick.best(from: [open]) != nil)
        #expect(!QuietestLibraryGlance.shouldShowClosed(from: [open]))
    }

    @Test func gymOnlyFeedIsNotLibraryClosed() {
        let arc = point(
            id: 1,
            name: "Anteater Recreation Center",
            category: "Recreation",
            percent: 40,
            isOpen: false
        )
        #expect(!QuietestLibraryGlance.hasLibraryFacilities([arc]))
        #expect(!QuietestLibraryGlance.shouldShowClosed(from: [arc]))
        #expect(QuietestLibraryGlance.diningStatusTip(from: [arc]) == nil)
    }

    @Test func diningStatusTipOpenPick() {
        let stamp = Date(timeIntervalSince1970: 1_720_000_100)
        let open = point(
            id: 2,
            name: "Science Library",
            category: "Library",
            percent: 12,
            isOpen: true,
            updatedAt: stamp
        )
        #expect(
            QuietestLibraryGlance.diningStatusTip(from: [open])
                == .open(name: "Science Library", percent: 12, facilityID: 2, updatedAt: stamp)
        )
    }

    @Test func diningStatusTipLibrariesClosed() {
        let closed = point(
            id: 2,
            name: "Science Library",
            category: "Library",
            percent: 10,
            isOpen: false
        )
        #expect(
            QuietestLibraryGlance.diningStatusTip(from: [closed])
                == .librariesClosed(reopenMinutes: nil)
        )
    }

    @Test func diningStatusTipLibrariesClosedWithWaitzReopen() {
        let closed = BusynessPoint(
            id: 2,
            name: "Science Library",
            category: "Library",
            count: nil,
            capacity: nil,
            percent: 10,
            level: .notBusy,
            isOpen: false,
            hoursSummary: "Closed until 8:00am",
            updatedAt: Date(),
            subLocations: nil
        )
        #expect(
            QuietestLibraryGlance.diningStatusTip(from: [closed])
                == .librariesClosed(reopenMinutes: 8 * 60)
        )
    }

    @Test func widgetRectangularDetailOpen() {
        #expect(
            QuietestLibraryGlance.widgetRectangularDetail(percent: 8)
                == "8% full · quietest now"
        )
    }

    @Test func widgetClosedSecondaryMatchesStudyNotFetchFailure() {
        #expect(
            QuietestLibraryGlance.widgetRectangularDetail(percent: nil)
                == QuietestLibraryGlance.closedDetail
        )
        #expect(
            QuietestLibraryGlance.widgetHomeSecondary(percent: nil)
                == QuietestLibraryGlance.closedDetail
        )
        #expect(
            QuietestLibraryGlance.widgetRectangularDetail(percent: nil)
                != "No live data"
        )
        #expect(QuietestLibraryGlance.widgetHomeSecondary(percent: 12) == nil)
    }

    @Test func widgetClosedSecondaryPrefersWaitzOpensAt() {
        #expect(
            QuietestLibraryGlance.widgetRectangularDetail(
                percent: nil,
                reopenMinutes: 8 * 60,
                nowMinutes: 6 * 60
            ) == "Opens at 8:00 AM"
        )
        #expect(
            QuietestLibraryGlance.widgetHomeSecondary(
                percent: nil,
                reopenMinutes: 8 * 60,
                nowMinutes: 6 * 60
            ) == "Opens at 8:00 AM"
        )
        #expect(
            QuietestLibraryGlance.widgetRectangularDetail(
                percent: nil,
                reopenMinutes: 8 * 60,
                nowMinutes: 13 * 60
            ) == "Opens tomorrow at 8:00 AM"
        )
    }
}

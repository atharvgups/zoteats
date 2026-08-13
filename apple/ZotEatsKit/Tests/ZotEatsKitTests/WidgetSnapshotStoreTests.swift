import Foundation
import Testing
@testable import ZotEatsKit

@Suite("WidgetSnapshotStore + countdown copy")
struct WidgetSnapshotStoreTests {
    @Test func countdownShortFormats() {
        let now = Date(timeIntervalSince1970: 1_700_000_000)
        #expect(
            WidgetCountdownCopy.short(until: now.addingTimeInterval(45), now: now) == "45s"
        )
        #expect(
            WidgetCountdownCopy.short(until: now.addingTimeInterval(12 * 60), now: now) == "12m"
        )
        #expect(
            WidgetCountdownCopy.short(until: now.addingTimeInterval(90 * 60), now: now) == "1h 30m"
        )
        #expect(WidgetCountdownCopy.closesLine(until: now.addingTimeInterval(60), now: now) == "closes 1m")
    }

    @Test func diningRoundTripViaSuite() {
        let key = WidgetSnapshotStore.diningLocationsKey
        SharedDefaults.suite.removeObject(forKey: key)
        SharedDefaults.suite.removeObject(forKey: key + WidgetSnapshotStore.savedAtSuffix)

        let hall = DiningLocation(
            id: "anteatery",
            name: "The Anteatery",
            area: "Middle Earth",
            openNow: true,
            todayHours: "7:00 AM – 9:00 PM",
            availablePeriods: ["Lunch"],
            periods: [.init(name: "Lunch", startMinutes: 11 * 60, endMinutes: 14 * 60)],
            hoursApproximate: false
        )
        WidgetSnapshotStore.saveDiningLocations([hall])
        let loaded = WidgetSnapshotStore.loadDiningLocations()
        #expect(loaded?.count == 1)
        #expect(loaded?.first?.id == "anteatery")
        #expect(WidgetSnapshotStore.savedAt(for: key) != nil)

        SharedDefaults.suite.removeObject(forKey: key)
        SharedDefaults.suite.removeObject(forKey: key + WidgetSnapshotStore.savedAtSuffix)
    }

    @Test func emptyCopyIsReadable() {
        #expect(!WidgetLoadEmptyCopy.title.isEmpty)
        #expect(WidgetLoadEmptyCopy.detail.contains("app"))
    }
}

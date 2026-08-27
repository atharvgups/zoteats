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
        #expect(
            WidgetCountdownCopy.closesLine(
                until: now.addingTimeInterval(60),
                now: now
            ).hasPrefix("until ")
        )
        #expect(
            WidgetCountdownCopy.opensLine(
                until: now.addingTimeInterval(57 * 60),
                now: now
            ).hasPrefix("at ")
        )
        let thursday = ISO8601DateFormatter().date(from: "2026-07-16T18:15:00Z")! // Thu 11:15 AM PDT
        let monday = ISO8601DateFormatter().date(from: "2026-07-13T03:00:00Z")! // Sun 8 PM PDT
        let far = WidgetCountdownCopy.opensLine(until: thursday, now: monday)
        #expect(!far.contains("opens"))
        #expect(!far.contains("h "))
        #expect(far.contains("11:15"))
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
        #expect(WidgetSnapshotStore.savedOnCurrentIrvineDay(key))
        #expect(WidgetSnapshotStore.loadDiningLocationsIfCurrentDay()?.first?.id == "anteatery")

        SharedDefaults.suite.removeObject(forKey: key)
        SharedDefaults.suite.removeObject(forKey: key + WidgetSnapshotStore.savedAtSuffix)
        #expect(WidgetSnapshotStore.loadDiningLocationsIfCurrentDay() == nil)
    }

    @Test func diningMenuRoundTripViaSuite() {
        let key = WidgetSnapshotStore.diningMenusKey
        SharedDefaults.suite.removeObject(forKey: key)
        SharedDefaults.suite.removeObject(forKey: key + WidgetSnapshotStore.savedAtSuffix)

        let menu = DiningMenu(
            locationId: "anteatery",
            date: "2026-08-13",
            period: "Brunch",
            stations: [
                MenuStation(
                    name: "Home",
                    items: [
                        MenuItem(
                            id: "1",
                            name: "Scrambled Eggs",
                            description: nil,
                            calories: 142,
                            servingSize: nil,
                            allergens: [],
                            dietaryTags: []
                        ),
                    ]
                ),
            ]
        )
        WidgetSnapshotStore.saveDiningMenu(menu)
        // Brunch stores under Breakfast pill — widget peeks with primary name.
        let loaded = WidgetSnapshotStore.loadDiningMenu(
            hall: "anteatery",
            period: "Breakfast",
            dateISO: "2026-08-13"
        )
        #expect(loaded?.stations.first?.items.first?.name == "Scrambled Eggs")
        #expect(
            WidgetSnapshotStore.diningMenuEntryKey(
                hall: "anteatery",
                period: "Brunch",
                dateISO: "2026-08-13"
            ) == "anteatery|breakfast|2026-08-13"
        )
        #expect(WidgetSnapshotStore.savedAt(for: key) != nil)

        SharedDefaults.suite.removeObject(forKey: key)
        SharedDefaults.suite.removeObject(forKey: key + WidgetSnapshotStore.savedAtSuffix)
    }

    @Test func emptyCopyIsReadable() {
        #expect(!WidgetLoadEmptyCopy.title.isEmpty)
        #expect(WidgetLoadEmptyCopy.detail.localizedCaseInsensitiveContains("eat"))
    }
}

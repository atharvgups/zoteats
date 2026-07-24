import Foundation
import Testing
@testable import ZotEatsKit

@Suite("SnapshotCache")
struct SnapshotCacheTests {
    private func temporaryCache() -> SnapshotCache {
        SnapshotCache(directory: FileManager.default.temporaryDirectory
            .appendingPathComponent("snapshot-tests-\(UUID().uuidString)"))
    }

    @Test func roundTripsModelsIncludingDates() async throws {
        let cache = temporaryCache()
        let point = BusynessPoint(
            id: 1, name: "Langson Library", category: "Library",
            count: 42, capacity: 700, percent: 6, level: .notBusy,
            isOpen: true, hoursSummary: nil,
            updatedAt: Date(timeIntervalSince1970: 1_752_600_000),
            subLocations: nil
        )
        cache.save([point], key: "busyness")
        // Saves are fire-and-forget; give the detached task a beat.
        try await Task.sleep(for: .milliseconds(300))

        let loaded = cache.load([BusynessPoint].self, key: "busyness")
        #expect(loaded == [point])
    }

    @Test func missingSnapshotIsNil() {
        #expect(temporaryCache().load([DiningLocation].self, key: "nope") == nil)
    }

    @Test func corruptSnapshotIsNilNotFatal() throws {
        let dir = FileManager.default.temporaryDirectory
            .appendingPathComponent("snapshot-tests-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        try Data("not json".utf8).write(to: dir.appendingPathComponent("locations.json"))
        let cache = SnapshotCache(directory: dir)
        #expect(cache.load([DiningLocation].self, key: "locations") == nil)
    }

    @Test func menusSnapshotIsDayScoped() async throws {
        let cache = temporaryCache()
        let menu = DiningMenu(locationId: "anteatery", date: "2026-07-16", period: "Lunch", stations: [])
        cache.save(MenusSnapshot(dateISO: "2026-07-16", menus: ["k": menu]), key: "menus")
        try await Task.sleep(for: .milliseconds(300))

        let loaded = cache.load(MenusSnapshot.self, key: "menus")
        #expect(loaded?.dateISO == "2026-07-16")
        #expect(loaded?.menus["k"]?.period == "Lunch")
    }
}

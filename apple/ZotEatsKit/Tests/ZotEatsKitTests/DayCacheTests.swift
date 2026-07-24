import Foundation
import Testing
@testable import ZotEatsKit

@Suite("DayCache")
struct DayCacheTests {
    @Test func servesSameDayEntries() async {
        let cache = tempDayCache()
        await cache.store(Data("menu-bytes".utf8), key: "dining:/restaurants", day: "2026-07-16")
        let hit = await cache.data(for: "dining:/restaurants", day: "2026-07-16")
        #expect(hit == Data("menu-bytes".utf8))
    }

    @Test func rejectsYesterdaysEntries() async {
        let cache = tempDayCache()
        await cache.store(Data("stale".utf8), key: "k", day: "2026-07-15")
        let hit = await cache.data(for: "k", day: "2026-07-16")
        #expect(hit == nil)
    }

    @Test func survivesAcrossInstancesSameDirectory() async {
        let dir = FileManager.default.temporaryDirectory
            .appendingPathComponent("day-cache-shared-\(UUID().uuidString)")
        await DayCache(directory: dir).store(Data("persisted".utf8), key: "k", day: "2026-07-16")
        let hit = await DayCache(directory: dir).data(for: "k", day: "2026-07-16")
        #expect(hit == Data("persisted".utf8))
    }

    @Test func keysWithQueryCharactersAreFilesystemSafe() async {
        let cache = tempDayCache()
        let key = "dining:/restaurantToday?id=brandywine&date=2026-07-16"
        await cache.store(Data("x".utf8), key: key, day: "2026-07-16")
        let hit = await cache.data(for: key, day: "2026-07-16")
        #expect(hit == Data("x".utf8))
    }

    @Test func distinctKeysDoNotCollide() {
        let a = DayCache.fileName(for: "dining:/restaurantToday?id=brandywine&date=2026-07-16")
        let b = DayCache.fileName(for: "dining:/restaurantToday?id=brandywine&date=2026-07-17")
        #expect(a != b)
    }
}

@Suite("Day caching across service instances")
struct DayCachedServicesTests {
    private let noon = Date(timeIntervalSince1970: 1_752_087_600) // 2026-07-09 12:00 PDT

    @Test func secondDiningServiceInstanceNeverTouchesTheNetwork() async throws {
        let dir = FileManager.default.temporaryDirectory
            .appendingPathComponent("day-cache-dining-\(UUID().uuidString)")

        // First "launch": everything comes from the network.
        let firstHTTP = CountingHTTP()
        let first = DiningService(http: firstHTTP, dayCache: DayCache(directory: dir), now: { noon })
        _ = await first.locations()
        _ = try await first.menu(for: "the-anteatery", period: "Lunch")
        #expect(firstHTTP.requests > 0)

        // Second "launch": new service, new in-memory cache, same disk. All hits.
        let secondHTTP = CountingHTTP()
        let second = DiningService(http: secondHTTP, dayCache: DayCache(directory: dir), now: { noon })
        let locations = await second.locations()
        let menu = try await second.menu(for: "the-anteatery", period: "Lunch")
        #expect(secondHTTP.requests == 0)
        #expect(!locations.isEmpty)
        #expect(!menu.stations.isEmpty)
    }

    @Test func freshBypassesTheDayCache() async throws {
        let dir = FileManager.default.temporaryDirectory
            .appendingPathComponent("day-cache-fresh-\(UUID().uuidString)")

        let warmup = DiningService(http: CountingHTTP(), dayCache: DayCache(directory: dir), now: { noon })
        _ = await warmup.locations()

        let http = CountingHTTP()
        let service = DiningService(http: http, dayCache: DayCache(directory: dir), now: { noon })
        _ = await service.locations(fresh: true)
        #expect(http.requests > 0)
    }

    @Test func secondCampusServiceInstanceNeverTouchesTheNetwork() async throws {
        let monday = Date(timeIntervalSince1970: 1_752_501_600) // 2026-07-14 07:00 PDT (Tue)... any weekday works
        let dir = FileManager.default.temporaryDirectory
            .appendingPathComponent("day-cache-campus-\(UUID().uuidString)")

        let firstHTTP = CountingHTTP()
        let first = CampusService(http: firstHTTP, dayCache: DayCache(directory: dir), now: { monday })
        _ = try await first.places()
        _ = try await first.menu(for: "halal-shack")
        #expect(firstHTTP.requests > 0)

        let secondHTTP = CountingHTTP()
        let second = CampusService(http: secondHTTP, dayCache: DayCache(directory: dir), now: { monday })
        let places = try await second.places()
        let menu = try await second.menu(for: "halal-shack")
        #expect(secondHTTP.requests == 0)
        #expect(!places.isEmpty)
        #expect(!menu.isEmpty)
    }

    @Test func liveBusynessIsNeverDayCached() async throws {
        // BusynessService intentionally has no DayCache hook; this pins that.
        let http = CountingHTTP()
        let service = BusynessService(http: http, cache: TTLCache())
        _ = try await service.all()
        let second = BusynessService(http: CountingHTTP(), cache: TTLCache())
        _ = try await second.all()
        // Each new instance re-fetches — no cross-instance persistence.
        #expect(http.requests == 1)
    }
}

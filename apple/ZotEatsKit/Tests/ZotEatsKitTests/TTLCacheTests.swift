import Foundation
import Testing
@testable import ZotEatsKit

@Suite("TTLCache")
struct TTLCacheTests {
    @Test func overlappingRememberSharesOneLoader() async throws {
        let cache = TTLCache()
        let hits = Counter()
        async let first: Int = cache.remember("k", ttl: 60) {
            await hits.increment()
            try await Task.sleep(nanoseconds: 80_000_000)
            return 7
        }
        async let second: Int = cache.remember("k", ttl: 60) {
            await hits.increment()
            return 99
        }
        let values = try await (first, second)
        #expect(values.0 == 7)
        #expect(values.1 == 7)
        #expect(await hits.value == 1)
    }

    @Test func failedRefreshKeepsStaleValue() async throws {
        let cache = TTLCache()
        let first = try await cache.remember("menu", ttl: 0.05) { "lunch" }
        #expect(first == "lunch")
        try await Task.sleep(nanoseconds: 80_000_000)
        #expect(await cache.get("menu", as: String.self) == nil)
        #expect(await cache.stale("menu", as: String.self) == "lunch")

        let recovered = try await cache.remember("menu", ttl: 60) { () -> String in
            throw TestFailure()
        }
        #expect(recovered == "lunch")
    }

    @Test func invalidateStartsANewLoad() async throws {
        let cache = TTLCache()
        _ = try await cache.remember("halls", ttl: 60) { 1 }
        await cache.invalidate("halls")
        let next = try await cache.remember("halls", ttl: 60) { 2 }
        #expect(next == 2)
        #expect(await cache.get("halls", as: Int.self) == 2)
    }
}

private actor Counter {
    var value = 0
    func increment() { value += 1 }
}

private struct TestFailure: Error {}

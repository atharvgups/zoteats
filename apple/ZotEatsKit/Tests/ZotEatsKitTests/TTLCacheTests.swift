import Foundation
import Testing
@testable import ZotEatsKit

@Suite("TTLCache", .serialized)
struct TTLCacheTests {
    @Test func overlappingRememberSharesOneLoader() async throws {
        let cache = TTLCache()
        let hits = Counter()
        let firstStarted = Gate()
        async let first: Int = cache.remember("k", ttl: 60) {
            await hits.increment()
            await firstStarted.open()
            try await Task.sleep(nanoseconds: 80_000_000)
            return 7
        }
        await firstStarted.wait()
        let second = try await cache.remember("k", ttl: 60) {
            await hits.increment()
            return 99
        }
        #expect(try await first == 7)
        #expect(second == 7)
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

private actor Gate {
    private var opened = false
    private var waiters: [CheckedContinuation<Void, Never>] = []

    func open() {
        opened = true
        let pending = waiters
        waiters.removeAll()
        for waiter in pending { waiter.resume() }
    }

    func wait() async {
        if opened { return }
        await withCheckedContinuation { waiters.append($0) }
    }
}

private struct TestFailure: Error {}

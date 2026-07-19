import Foundation

/// Minimal in-memory TTL cache — port of main/services/cache.ts.
/// Keeps third-party API calls polite and the UI snappy.
public actor TTLCache {
    private struct Entry {
        let value: any Sendable
        let expiresAt: Date
    }

    private var store: [String: Entry] = [:]

    public init() {}

    public func get<T: Sendable>(_ key: String, as type: T.Type) -> T? {
        guard let entry = store[key] else { return nil }
        guard Date() <= entry.expiresAt else {
            store[key] = nil
            return nil
        }
        return entry.value as? T
    }

    public func set<T: Sendable>(_ key: String, value: T, ttl: TimeInterval) {
        store[key] = Entry(value: value, expiresAt: Date().addingTimeInterval(ttl))
    }

    /// Return the cached value, or run `loader`, cache its result, and return it.
    /// `fresh: true` (explicit user refresh) skips the read but still updates
    /// the cache, so followers get the new value.
    public func remember<T: Sendable>(
        _ key: String,
        ttl: TimeInterval,
        fresh: Bool = false,
        loader: @Sendable () async throws -> T
    ) async rethrows -> T {
        if !fresh, let cached = get(key, as: T.self) { return cached }
        let value = try await loader()
        set(key, value: value, ttl: ttl)
        return value
    }
}

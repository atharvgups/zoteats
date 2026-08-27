import Foundation

/// Minimal in-memory TTL cache — port of main/services/cache.ts.
/// Keeps third-party API calls polite and the UI snappy.
///
/// Overlapping `remember` calls for the same key share one in-flight loader
/// (Instagram / Weather-style). Expired entries stay as a last-known fallback
/// when the network fails, instead of blanking the UI.
public actor TTLCache {
    private struct Entry {
        let value: any Sendable
        let expiresAt: Date
    }

    private var store: [String: Entry] = [:]
    private var inflight: [String: Task<any Sendable, Error>] = [:]
    private var generation: [String: UUID] = [:]

    public init() {}

    public func get<T: Sendable>(_ key: String, as type: T.Type) -> T? {
        guard let entry = store[key], Date() <= entry.expiresAt else { return nil }
        return entry.value as? T
    }

    /// Last-known value even after TTL expiry — used when a refresh fails.
    public func stale<T: Sendable>(_ key: String, as type: T.Type) -> T? {
        store[key]?.value as? T
    }

    public func set<T: Sendable>(_ key: String, value: T, ttl: TimeInterval) {
        store[key] = Entry(value: value, expiresAt: Date().addingTimeInterval(ttl))
    }

    /// Drop a cached entry so the next `remember` reloads from the network.
    public func invalidate(_ key: String) {
        store[key] = nil
        generation[key] = UUID()
        inflight[key] = nil
    }

    /// Drop every key with the given prefix (e.g. `"dining:today:"`).
    public func invalidatePrefix(_ prefix: String) {
        for key in store.keys where key.hasPrefix(prefix) {
            store[key] = nil
            generation[key] = UUID()
            inflight[key] = nil
        }
        for key in inflight.keys where key.hasPrefix(prefix) {
            generation[key] = UUID()
            inflight[key] = nil
        }
    }

    /// Return a fresh cached value, join an in-flight load, or run `loader`.
    /// On loader failure, returns a stale entry when one exists.
    public func remember<T: Sendable>(
        _ key: String,
        ttl: TimeInterval,
        loader: @escaping @Sendable () async throws -> T
    ) async throws -> T {
        if let cached = get(key, as: T.self) { return cached }

        if let existing = inflight[key] {
            do {
                if let value = try await existing.value as? T {
                    return value
                }
                if let staleValue = stale(key, as: T.self) { return staleValue }
                throw TTLCacheTypeError(key: key)
            } catch {
                if let staleValue = stale(key, as: T.self) { return staleValue }
                throw error
            }
        }

        let token = UUID()
        generation[key] = token
        let task = Task<any Sendable, Error> {
            try await loader()
        }
        inflight[key] = task
        defer {
            if generation[key] == token {
                inflight[key] = nil
            }
        }

        do {
            guard let value = try await task.value as? T else {
                if let staleValue = stale(key, as: T.self) { return staleValue }
                throw TTLCacheTypeError(key: key)
            }
            if generation[key] == token {
                set(key, value: value, ttl: ttl)
            }
            return value
        } catch {
            if let staleValue = stale(key, as: T.self) { return staleValue }
            throw error
        }
    }
}

private struct TTLCacheTypeError: Error {
    let key: String
}

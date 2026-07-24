import Foundation

/// Tiny disk cache powering stale-while-revalidate launches: stores render the
/// last-known data instantly on cold start, then refresh silently. Files are
/// small JSON blobs in Application Support; every read/write is best-effort —
/// a missing or corrupt snapshot just means the old skeleton path.
public struct SnapshotCache: Sendable {
    private let directory: URL

    public static let shared = SnapshotCache()

    public init(directory: URL? = nil) {
        if let directory {
            self.directory = directory
        } else {
            let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
                ?? FileManager.default.temporaryDirectory
            self.directory = base.appendingPathComponent("ZotEatsSnapshots", isDirectory: true)
        }
        try? FileManager.default.createDirectory(at: self.directory, withIntermediateDirectories: true)
    }

    private static let encoder: JSONEncoder = {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        return encoder
    }()

    private static let decoder: JSONDecoder = {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return decoder
    }()

    private func fileURL(for key: String) -> URL {
        directory.appendingPathComponent("\(key).json")
    }

    /// Synchronous read — snapshot files are a few KB, so this is safe at init.
    public func load<T: Decodable>(_ type: T.Type, key: String) -> T? {
        guard let data = try? Data(contentsOf: fileURL(for: key)) else { return nil }
        return try? Self.decoder.decode(type, from: data)
    }

    /// Fire-and-forget write off the caller's thread.
    public func save<T: Encodable & Sendable>(_ value: T, key: String) {
        let url = fileURL(for: key)
        Task.detached(priority: .utility) {
            guard let data = try? Self.encoder.encode(value) else { return }
            try? data.write(to: url, options: .atomic)
        }
    }

    public func remove(key: String) {
        try? FileManager.default.removeItem(at: fileURL(for: key))
    }
}

/// Day-scoped menu snapshot so yesterday's menus never masquerade as today's.
public struct MenusSnapshot: Codable, Sendable {
    public let dateISO: String
    public let menus: [String: DiningMenu]

    public init(dateISO: String, menus: [String: DiningMenu]) {
        self.dateISO = dateISO
        self.menus = menus
    }
}

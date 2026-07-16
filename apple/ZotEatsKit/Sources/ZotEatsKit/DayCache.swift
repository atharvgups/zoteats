import Foundation

/// Disk cache for day-stable API responses: once menus, dish details, or hours
/// are pulled, they're kept for the rest of the day (Irvine time) — across
/// launches — so repeat calls never touch the network. Live feeds (library and
/// gym occupancy) must NOT use this; they go stale in minutes, not days.
///
/// Entries are raw response bytes keyed by request, stamped with the day they
/// were fetched. A stale or corrupt entry is simply a miss.
public actor DayCache {
    public static let shared = DayCache()

    private let directory: URL

    private struct Entry: Codable {
        let day: String
        let payload: Data
    }

    public init(directory: URL? = nil) {
        if let directory {
            self.directory = directory
        } else {
            let base = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask).first
                ?? FileManager.default.temporaryDirectory
            self.directory = base.appendingPathComponent("ZotEatsDayCache", isDirectory: true)
        }
        try? FileManager.default.createDirectory(at: self.directory, withIntermediateDirectories: true)
    }

    /// The cached bytes for `key`, if they were stored on `day`.
    public func data(for key: String, day: String) -> Data? {
        guard let raw = try? Data(contentsOf: fileURL(for: key)),
              let entry = try? JSONDecoder().decode(Entry.self, from: raw)
        else { return nil }
        guard entry.day == day else {
            // Yesterday's entry — reclaim the space.
            try? FileManager.default.removeItem(at: fileURL(for: key))
            return nil
        }
        return entry.payload
    }

    public func store(_ payload: Data, key: String, day: String) {
        guard let raw = try? JSONEncoder().encode(Entry(day: day, payload: payload)) else { return }
        try? raw.write(to: fileURL(for: key), options: .atomic)
    }

    /// Drop everything (used by explicit user refresh paths if ever needed).
    public func clear() {
        guard let files = try? FileManager.default.contentsOfDirectory(at: directory, includingPropertiesForKeys: nil) else { return }
        for file in files {
            try? FileManager.default.removeItem(at: file)
        }
    }

    private func fileURL(for key: String) -> URL {
        directory.appendingPathComponent("\(Self.fileName(for: key)).json")
    }

    /// Filesystem-safe, collision-resistant name: readable prefix + FNV-1a hash.
    static func fileName(for key: String) -> String {
        let safe = key.map { $0.isLetter || $0.isNumber || $0 == "-" || $0 == "_" ? $0 : "_" }
        var hash: UInt64 = 0xcbf29ce484222325
        for byte in key.utf8 {
            hash ^= UInt64(byte)
            hash = hash &* 0x100000001b3
        }
        return "\(String(safe.prefix(80)))-\(String(hash, radix: 16))"
    }
}

import Foundation
import os

/// Launch-to-content measurement: logs one line the first time real content
/// (not a skeleton) renders. CI scrapes this from the simulator's unified log
/// to keep the "content in under half a second on warm launches" bar honest.
@MainActor
enum PerfMetrics {
    private static let logger = Logger(subsystem: "com.atharvgupta.zoteats", category: "perf")
    private static var appStart: Date = .now
    private static var reported = false

    /// Call as early as possible in the app's lifecycle.
    static func markLaunch() {
        appStart = .now
        reported = false
    }

    /// Call when a tab first shows real data. Only the first call logs.
    static func markFirstContent(_ source: String, cached: Bool) {
        guard !reported else { return }
        reported = true
        let ms = Int(Date.now.timeIntervalSince(appStart) * 1000)
        logger.notice("ZOTEATS_PERF first-content \(ms, privacy: .public)ms source=\(source, privacy: .public) cached=\(cached, privacy: .public)")
    }
}

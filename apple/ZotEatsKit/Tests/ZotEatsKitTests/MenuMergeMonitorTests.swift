import Foundation
import Testing
@testable import ZotEatsKit

/// Live merge audit against today's Anteater API + Hub.
/// Run with: ZOTEATS_LIVE_TESTS=1 swift test --filter MenuMergeMonitor
@Suite("MenuMergeMonitor", .enabled(if: ProcessInfo.processInfo.environment["ZOTEATS_LIVE_TESTS"] == "1"))
struct MenuMergeMonitorTests {
    @Test func liveMergeKeepsAnteaterEntreesAndNeverRendersStaplesOnlyStations() async throws {
        let service = DiningService()
        let date = UCITime.todayISO()
        let halls = ["anteatery", "brandywine"]
        let periods = ["Breakfast", "Lunch", "Dinner", "Afternoon Snack", "Late Night"]
        var issues: [MenuMergeIssue] = []
        var checked = 0
        for hall in halls {
            let hub = await service.hubStations(forHall: hall, date: date, forceRefresh: true)
            for period in periods {
                let anteater = try await service.anteaterBoard(
                    for: hall,
                    period: period,
                    date: date,
                    forceRefresh: true
                )
                let timed = anteater.stations.filter {
                    !CampusMenuNormalize.isAvailableAllDay($0.name) && !$0.items.isEmpty
                }
                if timed.isEmpty, hub.isEmpty { continue }
                let merged = DiningService.mergeHubOntoAnteater(anteater, hubStations: hub)
                let found = DiningService.auditMergedMenu(
                    anteater: anteater,
                    hubStations: hub,
                    merged: merged
                )
                issues.append(contentsOf: found)
                checked += 1
            }
        }
        #expect(checked > 0)
        if !issues.isEmpty {
            let summary = issues.map(\.description).joined(separator: "\n")
            Issue.record("Menu merge guardrail failed:\n\(summary)")
        }
        #expect(issues.isEmpty, "Hub dropped an Anteater entree or left a station staples-only")
    }
}

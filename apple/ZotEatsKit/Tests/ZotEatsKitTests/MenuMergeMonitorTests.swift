import Foundation
import Testing
@testable import ZotEatsKit

/// Live merge audit against Anteater API + Hub for every hall, meal, and
/// posted day in the current Eat window.
/// Run with: ZOTEATS_LIVE_TESTS=1 swift test --filter MenuMergeMonitor
@Suite("MenuMergeMonitor", .enabled(if: ProcessInfo.processInfo.environment["ZOTEATS_LIVE_TESTS"] == "1"))
struct MenuMergeMonitorTests {
    @Test func liveMergeDiffsPostedMenuForEveryHallMealAndDay() async throws {
        let service = DiningService()
        let today = UCITime.todayISO()
        let range = await service.publishedDateRange(forceRefresh: true)
        let through = range?.latest ?? today
        let dates = EatPostedDays.isoDates(from: today, through: through)
        let halls = ["anteatery", "brandywine", HallDirectory.oasisComingSoonID]
        let periods = ["Breakfast", "Lunch", "Dinner", "Afternoon Snack", "Late Night"]
        var issues: [MenuMergeIssue] = []
        var checked = 0
        var refreshed = Set<String>()
        for hall in halls {
            for date in dates {
                let key = "\(hall)|\(date)"
                let refresh = refreshed.insert(key).inserted
                let hub = await service.hubStations(forHall: hall, date: date, forceRefresh: refresh)
                for period in periods {
                    if HallDirectory.isOasis(hall) {
                        let menu = (try? await service.menu(
                            for: hall,
                            period: period,
                            date: date,
                            forceRefresh: refresh
                        )) ?? DiningMenu(locationId: hall, date: date, period: period, stations: [])
                        if menu.stations.flatMap(\.items).isEmpty, hub.isEmpty { continue }
                        let posted = DiningService.postedMenuKeys(
                            anteater: DiningMenu(
                                locationId: hall,
                                date: date,
                                period: period,
                                stations: []
                            ),
                            hubStations: hub
                        )
                        for station in menu.stations {
                            for item in station.items {
                                if DiningService.isVerifiedOverrideItem(item) { continue }
                                if DiningService.appearsInPostedMenu(item, keys: posted) { continue }
                                issues.append(MenuMergeIssue(
                                    hallID: hall,
                                    date: date,
                                    period: period,
                                    stationName: station.name,
                                    stationID: station.stationID,
                                    kind: .unpostedMergedDish,
                                    dishName: item.name
                                ))
                            }
                        }
                        checked += 1
                        continue
                    }
                    let anteater = try await service.anteaterBoard(
                        for: hall,
                        period: period,
                        date: date,
                        forceRefresh: refresh
                    )
                    let timed = anteater.stations.filter {
                        !CampusMenuNormalize.isAvailableAllDay($0.name) && !$0.items.isEmpty
                    }
                    if timed.isEmpty, hub.isEmpty { continue }
                    let merged = DiningService.mergeHubOntoAnteater(anteater, hubStations: hub)
                    issues.append(contentsOf: DiningService.auditMergedMenu(
                        anteater: anteater,
                        hubStations: hub,
                        merged: merged
                    ))
                    checked += 1
                }
            }
        }
        #expect(checked > 0)
        if !issues.isEmpty {
            let summary = issues.map(\.description).joined(separator: "\n")
            Issue.record("Menu merge guardrail failed:\n\(summary)")
        }
        #expect(
            issues.isEmpty,
            "Merged menu listed a dish not on the posted source, dropped an Anteater entree, or stacked a competing Twisted Root dish"
        )
    }
}

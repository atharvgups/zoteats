import Foundation
import Testing
@testable import ZotEatsKit

@Suite("StudyBoundaryRefresh")
struct StudyBoundaryRefreshTests {
    private func point(
        id: Int,
        category: String,
        isOpen: Bool,
        hoursSummary: String? = nil
    ) -> BusynessPoint {
        BusynessPoint(
            id: id,
            name: "Spot \(id)",
            category: category,
            count: nil,
            capacity: nil,
            percent: isOpen ? 12 : nil,
            level: isOpen ? .notBusy : .unknown,
            isOpen: isOpen,
            hoursSummary: hoursSummary,
            updatedAt: Date(timeIntervalSince1970: 1_800_000_000),
            subLocations: nil
        )
    }

    @Test func openLibraryUsesShortCadence() {
        let now = Date(timeIntervalSince1970: 1_800_000_000)
        let facilities = [point(id: 1, category: "Library", isOpen: true)]
        #expect(StudyBoundaryRefresh.anyLibraryOpen(from: facilities))
        let fire = StudyBoundaryRefresh.nextFire(now: now, facilities: facilities)
        #expect(fire == now.addingTimeInterval(10 * 60))
    }

    @Test func closedLibrariesProbeMorningOpen() {
        // Monday 2026-07-13, 7:50 AM Pacific — 8:00 probe is 10m away.
        let now = ISO8601DateFormatter().date(from: "2026-07-13T14:50:00Z")!
        let facilities = [point(id: 1, category: "Library", isOpen: false)]
        #expect(!StudyBoundaryRefresh.anyLibraryOpen(from: facilities))
        let fire = StudyBoundaryRefresh.nextFire(now: now, facilities: facilities)
        let eight = UCITime.date(
            forMinutes: 8 * 60,
            nowMinutes: UCITime.nowMinutes(now: now),
            now: now
        )
        #expect(fire == eight.addingTimeInterval(2))
    }

    @Test func closedLibrariesPreferWaitzReopen() {
        // Monday 11:50 AM — Waitz noon beats morning-only probes (already past).
        let now = ISO8601DateFormatter().date(from: "2026-07-13T18:50:00Z")!
        let facilities = [
            point(
                id: 1,
                category: "Library",
                isOpen: false,
                hoursSummary: "Closed until 12:00pm"
            ),
        ]
        let fire = StudyBoundaryRefresh.nextFire(now: now, facilities: facilities)
        let noon = UCITime.date(
            forMinutes: 12 * 60,
            nowMinutes: UCITime.nowMinutes(now: now),
            now: now
        )
        #expect(fire == noon.addingTimeInterval(2))
    }

    @Test func libraryCategoryBeatsOpenNonLibrary() {
        let facilities = [
            point(id: 1, category: "Library", isOpen: false),
            point(id: 2, category: "Recreation", isOpen: true),
        ]
        #expect(!StudyBoundaryRefresh.anyLibraryOpen(from: facilities))
    }

    @Test func emptyLibraryFeedFallsBackToWholePool() {
        let facilities = [point(id: 2, category: "Recreation", isOpen: true)]
        #expect(StudyBoundaryRefresh.anyLibraryOpen(from: facilities))
    }

    @Test("Closed-until stale isOpen is not anyLibraryOpen")
    func closedUntilStaleOpenIsClosed() {
        let facilities = [
            point(
                id: 1,
                category: "Library",
                isOpen: true,
                hoursSummary: "Closed until 8:00am"
            ),
        ]
        #expect(!StudyBoundaryRefresh.anyLibraryOpen(from: facilities, nowMinutes: 6 * 60))
    }

    @Test("Past-range stale isOpen is not anyLibraryOpen")
    func pastRangeStaleOpenIsClosed() {
        let facilities = [
            point(
                id: 1,
                category: "Library",
                isOpen: true,
                hoursSummary: "8:00am-12:00pm"
            ),
        ]
        #expect(!StudyBoundaryRefresh.anyLibraryOpen(from: facilities, nowMinutes: 14 * 60))
    }
}

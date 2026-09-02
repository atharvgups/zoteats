import Foundation
import Testing
@testable import ZotEatsKit

@Suite("PlateDayMath")
struct PlateDayMathTests {
    private let bowl = PlateEntry(dishName: "Bowl", calories: 420, proteinG: 14)

    @Test func sameDayKeepsEntries() {
        let kept = PlateDayMath.entriesIfCurrentDay(
            savedDateISO: "2026-07-16",
            entries: [bowl],
            todayISO: "2026-07-16"
        )
        #expect(kept == [bowl])
        #expect(PlateDayMath.shouldClear(savedDateISO: "2026-07-16", todayISO: "2026-07-16") == false)
    }

    @Test func yesterdayClearsEntries() {
        let kept = PlateDayMath.entriesIfCurrentDay(
            savedDateISO: "2026-07-15",
            entries: [bowl],
            todayISO: "2026-07-16"
        )
        #expect(kept.isEmpty)
        #expect(PlateDayMath.shouldClear(savedDateISO: "2026-07-15", todayISO: "2026-07-16") == true)
    }

    @Test func missingSavedMeansEmptyWithoutClear() {
        #expect(
            PlateDayMath.entriesIfCurrentDay(
                savedDateISO: nil,
                entries: [bowl],
                todayISO: "2026-07-16"
            ).isEmpty
        )
        #expect(PlateDayMath.shouldClear(savedDateISO: nil, todayISO: "2026-07-16") == false)
        #expect(PlateDayMath.shouldClear(savedDateISO: "", todayISO: "2026-07-16") == false)
    }

    @Test func emptyPlateDropsStorageBlob() {
        #expect(PlateDayMath.shouldDropStorage(entries: []) == true)
        #expect(PlateDayMath.shouldDropStorage(entries: [bowl]) == false)
    }
}

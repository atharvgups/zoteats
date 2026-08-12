import Foundation

// Anteater Recreation Center (ARC) status — port of main/services/campusrec.ts.
//
// UCI Campus Recreation does not publish a machine-readable hours API, and the ARC's
// hours shift by quarter/holidays. Strategy: prefer LIVE hours + open state from the
// Occuspace/Waitz feed when the ARC is tracked there; otherwise fall back to this
// maintained weekly schedule (verify against campusrec.uci.edu/arc/hours.html).

public struct GymService: Sendable {
    private let busyness: BusynessService
    private let now: @Sendable () -> Date

    public init(
        busyness: BusynessService = BusynessService(),
        now: @escaping @Sendable () -> Date = { Date() }
    ) {
        self.busyness = busyness
        self.now = now
    }

    /// Hours as (open, close) in 24h; close may be 24 (midnight). Maintained fallback.
    /// Summer 2026 campusrec.uci.edu/arc/hours.html — Mon–Fri 6 AM–10 PM, Sat/Sun 8 AM–8 PM.
    public static let arcWeek: [(day: String, open: Int, close: Int)] = [
        ("Sunday", 8, 20),
        ("Monday", 6, 22),
        ("Tuesday", 6, 22),
        ("Wednesday", 6, 22),
        ("Thursday", 6, 22),
        ("Friday", 6, 22),
        ("Saturday", 8, 20),
    ]

    static func formatHour(_ hour: Int) -> String {
        let wrapped = hour % 24
        let period = wrapped < 12 ? "AM" : "PM"
        let display = wrapped % 12 == 0 ? 12 : wrapped % 12
        return "\(display):00 \(period)"
    }

    public func status() async -> GymStatus {
        var liveBusyness: BusynessPoint?
        var liveHours: String?
        var liveOpen: Bool?

        if let arc = try? await BusynessService.findArc(in: busyness.all()) {
            liveBusyness = arc
            liveHours = arc.hoursSummary
            liveOpen = arc.isOpen
        }

        let currentDate = now()
        let weekday = PacificTime.weekdayName(now: currentDate)
        let minutes = PacificTime.nowMinutes(now: currentDate)
        let today = Self.arcWeek.first { $0.day == weekday }
        let scheduleOpenNow = today.map { minutes >= $0.open * 60 && minutes < $0.close * 60 } ?? false

        let weekHours = Self.arcWeek.map {
            DayHours(day: $0.day, hours: "\(Self.formatHour($0.open)) – \(Self.formatHour($0.close))")
        }

        let scheduleHours = today.map { "\(Self.formatHour($0.open)) – \(Self.formatHour($0.close))" }
        let waitzReopen = WaitzHoursSummary.closedUntilMinutes(liveHours)
        // Only range-looking Waitz strings are displayable hours — "open" and
        // "Closed until 8:00am" must not become "Open until open".
        let usingLiveRange = Self.isDisplayableHoursRange(liveHours)
        let todayHours = usingLiveRange ? liveHours : scheduleHours

        // Live sensor data wins; otherwise fall back to the typical-pattern
        // estimate, clearly flagged so the UI can label it.
        let typical = TypicalBusyness.arc(now: currentDate)
        let openNow = liveOpen ?? scheduleOpenNow
        let typicalPoint: BusynessPoint? = typical.percentNow > 0 ? BusynessPoint(
            id: -100,
            name: "Anteater Recreation Center",
            category: "Recreation",
            count: nil,
            capacity: nil,
            percent: typical.percentNow,
            level: typical.levelNow,
            isOpen: openNow,
            hoursSummary: nil,
            updatedAt: currentDate,
            subLocations: nil,
            source: .typical
        ) : nil

        return GymStatus(
            name: "Anteater Recreation Center",
            openNow: openNow,
            todayHours: todayHours,
            weekHours: weekHours,
            busyness: liveBusyness ?? typicalPoint,
            hoursApproximate: !usingLiveRange,
            waitzReopenMinutes: waitzReopen,
            typicalCurve: typical.dayCurve,
            busiestSummary: typical.busiestSummary,
            quietestSummary: typical.quietestSummary
        )
    }

    /// True for live Waitz hour strings that look like a continuous range
    /// (`"6:00 AM – 10:00 PM"`), not `"open"` / `"Closed until …"`.
    static func isDisplayableHoursRange(_ summary: String?) -> Bool {
        guard let summary else { return false }
        let trimmed = summary.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return false }
        if WaitzHoursSummary.closedUntilMinutes(trimmed) != nil { return false }
        if trimmed.lowercased() == "open" { return false }
        return trimmed.contains("–") || trimmed.contains("-")
    }

    /// Next schedule open or close as a wall-clock `Date` (Irvine), for widget reload.
    /// Pair with Waitz `Closed until …` via `GymBoundaryRefresh` when live.
    public static func nextScheduleBoundary(now: Date = Date()) -> Date? {
        let weekday = PacificTime.weekdayName(now: now)
        let minutes = PacificTime.nowMinutes(now: now)
        guard let idx = arcWeek.firstIndex(where: { $0.day == weekday }) else { return nil }
        let today = arcWeek[idx]
        let openM = today.open * 60
        let closeM = today.close * 60 // 24 → 1440 (midnight)

        if minutes < openM {
            return UCITime.date(forMinutes: openM, nowMinutes: minutes, now: now)
        }
        if minutes < closeM {
            if closeM >= 24 * 60 {
                let calendar = PacificTime.calendar
                let start = calendar.startOfDay(for: now)
                return calendar.date(byAdding: .day, value: 1, to: start)
            }
            return UCITime.date(forMinutes: closeM, nowMinutes: minutes, now: now)
        }
        // After today's close — next day's open (rolls via UCITime when open < now).
        let next = arcWeek[(idx + 1) % arcWeek.count]
        return UCITime.date(forMinutes: next.open * 60, nowMinutes: minutes, now: now)
    }
}

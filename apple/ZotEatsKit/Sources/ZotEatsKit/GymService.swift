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
    static let arcWeek: [(day: String, open: Int, close: Int)] = [
        ("Sunday", 8, 24),
        ("Monday", 6, 24),
        ("Tuesday", 6, 24),
        ("Wednesday", 6, 24),
        ("Thursday", 6, 24),
        ("Friday", 6, 24),
        ("Saturday", 8, 21),
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

        let todayHours = liveHours ?? today.map { "\(Self.formatHour($0.open)) – \(Self.formatHour($0.close))" }

        return GymStatus(
            name: "Anteater Recreation Center",
            openNow: liveOpen ?? scheduleOpenNow,
            todayHours: todayHours,
            weekHours: weekHours,
            busyness: liveBusyness,
            hoursApproximate: liveHours == nil
        )
    }
}

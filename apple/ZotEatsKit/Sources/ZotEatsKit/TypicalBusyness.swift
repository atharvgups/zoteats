import Foundation

// "Typical busyness" model — Google-style "usually busy at this time" estimates
// for facilities the live Waitz feed does not cover (dining halls, the ARC).
// Estimates are ALWAYS labeled `.typical` so the UI can distinguish them from
// live sensor data; live data takes precedence wherever it exists.
//
// Dining curves anchor to the day's real meal windows from the Anteater API
// (rush builds after a period opens and tapers toward its end). The ARC curve
// is a maintained weekly pattern (like the hours schedule in GymService):
// moderate early-morning rush, midday bump, heavy 4–8 PM peak, quieter weekends.

/// Where a busyness reading came from.
public enum BusynessSource: String, Codable, Sendable {
    case live
    case typical
}

/// A typical-pattern estimate for one facility on one day.
public struct TypicalEstimate: Sendable, Equatable {
    /// Estimated percent full right now (0 when closed).
    public let percentNow: Int
    public let levelNow: BusynessLevel
    /// 24 hourly percents for today (index = hour, 0 = closed).
    public let dayCurve: [Int]
    /// e.g. "Usually busiest 6–8 PM".
    public let busiestSummary: String?
    /// e.g. "Usually quietest around 10 AM".
    public let quietestSummary: String?

    public init(
        percentNow: Int,
        levelNow: BusynessLevel,
        dayCurve: [Int],
        busiestSummary: String?,
        quietestSummary: String?
    ) {
        self.percentNow = percentNow
        self.levelNow = levelNow
        self.dayCurve = dayCurve
        self.busiestSummary = busiestSummary
        self.quietestSummary = quietestSummary
    }
}

public enum TypicalBusyness {
    // MARK: - Dining

    /// Estimate for a dining hall from today's actual meal windows.
    public static func dining(periods: [MealPeriodWindow], now: Date = Date()) -> TypicalEstimate {
        let weekday = PacificTime.weekdayName(now: now)
        let isWeekend = weekday == "Saturday" || weekday == "Sunday"
        let curve = diningCurve(periods: periods, isWeekend: isWeekend)
        return estimate(curve: curve, now: now)
    }

    /// Relative draw of each meal period (dinner is the crush, breakfast is calm).
    static func periodPeak(_ name: String) -> Int {
        switch name.lowercased() {
        case "breakfast": 50
        case "brunch": 75
        case "lunch": 85
        case "dinner": 90
        default: 45 // "All Day" and other untimed offerings
        }
    }

    /// 24 hourly percents derived from meal windows: quick ramp after opening,
    /// full rush through the middle, tapering toward the end of the period.
    static func diningCurve(periods: [MealPeriodWindow], isWeekend: Bool) -> [Int] {
        var curve = [Int](repeating: 0, count: 24)
        for period in periods {
            guard let start = period.startMinutes, let end = period.endMinutes, end > start else { continue }
            let peak = Double(periodPeak(period.name)) * (isWeekend ? 0.85 : 1.0)
            for hour in 0..<24 {
                let midpoint = hour * 60 + 30
                guard midpoint >= start && midpoint < end else { continue }
                let progress = Double(midpoint - start) / Double(end - start)
                let shape: Double =
                    progress < 0.15 ? 0.65 :
                    progress < 0.55 ? 1.0 :
                    progress < 0.8 ? 0.75 : 0.5
                curve[hour] = max(curve[hour], Int((peak * shape).rounded()))
            }
        }
        return curve
    }

    // MARK: - ARC

    /// Estimate for the Anteater Recreation Center from the maintained weekly pattern.
    public static func arc(now: Date = Date()) -> TypicalEstimate {
        let weekday = PacificTime.weekdayName(now: now)
        let curve = arcCurve(weekday: weekday)
        return estimate(curve: curve, now: now)
    }

    /// Hour -> typical percent, clamped to the ARC's open hours for that day.
    static func arcCurve(weekday: String) -> [Int] {
        let isWeekend = weekday == "Saturday" || weekday == "Sunday"

        // Maintained pattern (verify against lived experience each quarter):
        // weekdays peak hard 4–8 PM with a small 6–8 AM rush; weekends are a
        // gentler midday bump.
        let weekdayPattern: [Int: Int] = [
            6: 40, 7: 50, 8: 45, 9: 35, 10: 30, 11: 35, 12: 45, 13: 55, 14: 50,
            15: 50, 16: 60, 17: 75, 18: 90, 19: 85, 20: 70, 21: 55, 22: 40, 23: 30,
        ]
        let weekendPattern: [Int: Int] = [
            8: 25, 9: 35, 10: 45, 11: 55, 12: 60, 13: 60, 14: 55, 15: 50,
            16: 50, 17: 45, 18: 40, 19: 35, 20: 30, 21: 25, 22: 20, 23: 15,
        ]
        let pattern = isWeekend ? weekendPattern : weekdayPattern

        let day = GymService.arcWeek.first { $0.day == weekday }
        var curve = [Int](repeating: 0, count: 24)
        guard let day else { return curve }
        for hour in 0..<24 where hour >= day.open && hour < day.close {
            curve[hour] = pattern[hour] ?? 0
        }
        return curve
    }

    // MARK: - Shared

    static func estimate(curve: [Int], now: Date) -> TypicalEstimate {
        let hour = PacificTime.nowMinutes(now: now) / 60
        let percentNow = (0..<24).contains(hour) ? curve[hour] : 0
        let (busiest, quietest) = summaries(curve: curve)
        return TypicalEstimate(
            percentNow: percentNow,
            levelNow: percentNow == 0 ? .unknown : BusynessService.level(forPercent: percentNow),
            dayCurve: curve,
            busiestSummary: busiest,
            quietestSummary: quietest
        )
    }

    /// Human summaries of the curve: the contiguous peak block and the calmest open hour.
    static func summaries(curve: [Int]) -> (busiest: String?, quietest: String?) {
        guard let maxValue = curve.max(), maxValue > 0,
              let maxIndex = curve.firstIndex(of: maxValue)
        else { return (nil, nil) }

        let peakFloor = Int(Double(maxValue) * 0.85)
        var lo = maxIndex
        var hi = maxIndex
        while lo > 0, curve[lo - 1] >= peakFloor { lo -= 1 }
        while hi < 23, curve[hi + 1] >= peakFloor { hi += 1 }
        let busiest = lo == hi
            ? "Usually busiest around \(hourLabel(lo))"
            : "Usually busiest \(hourLabel(lo))–\(hourLabel(hi + 1))"

        let openHours = curve.enumerated().filter { $0.element > 0 }
        let quietest = openHours
            .min { $0.element < $1.element }
            .map { "usually quietest around \(hourLabel($0.offset))" }

        return (busiest, quietest)
    }

    /// Short one-liner for "right now", or nil when closed/no estimate.
    public static func nowLabel(forPercent percent: Int) -> String? {
        switch percent {
        case ..<1: nil
        case ..<40: "Usually quiet now"
        case ..<70: "Usually moderate now"
        default: "Usually packed now"
        }
    }

    static func hourLabel(_ hour: Int) -> String {
        let wrapped = hour % 24
        let period = wrapped < 12 ? "AM" : "PM"
        let display = wrapped % 12 == 0 ? 12 : wrapped % 12
        return "\(display) \(period)"
    }
}

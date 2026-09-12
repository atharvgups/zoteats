import Foundation

/// Honest ARC idle / closed chrome — "opens at 6:00 AM" before today's open,
/// and "opens tomorrow at …" after today's close (not a vague "see you tomorrow").
/// Prefers Waitz reopen / live close over the maintained week when they disagree.
public enum ArcIdleCopy {
    /// Today's open minutes (Irvine) from the maintained ARC week, when known.
    public static func todayOpenMinutes(
        weekday: String,
        arcWeek: [(day: String, open: Int, close: Int)] = GymService.arcWeek
    ) -> Int? {
        arcWeek.first { $0.day == weekday }.map { $0.open * 60 }
    }

    /// Today's close minutes (Irvine). Close hour 24 → 1440.
    public static func todayCloseMinutes(
        weekday: String,
        arcWeek: [(day: String, open: Int, close: Int)] = GymService.arcWeek
    ) -> Int? {
        arcWeek.first { $0.day == weekday }.map { $0.close * 60 }
    }

    /// Next calendar day's open minutes (Irvine) from the maintained ARC week.
    public static func tomorrowOpenMinutes(
        weekday: String,
        arcWeek: [(day: String, open: Int, close: Int)] = GymService.arcWeek
    ) -> Int? {
        guard let idx = arcWeek.firstIndex(where: { $0.day == weekday }) else { return nil }
        return arcWeek[(idx + 1) % arcWeek.count].open * 60
    }

    /// True once today's window is finished (Irvine minutes).
    private static func isDoneForToday(
        nowMinutes: Int,
        opensAtMinutesToday: Int?,
        closesAtMinutesToday: Int?
    ) -> Bool {
        if let close = closesAtMinutesToday {
            return nowMinutes >= close
        }
        // No close known — treat as done when past today's open (or no open at all).
        if let open = opensAtMinutesToday {
            return nowMinutes >= open
        }
        return true
    }

    /// Today's open minutes for closed chrome — prefer Waitz `Closed until …`
    /// when the ARC is closed so holiday / late opens don't say “Opens at 6 AM”
    /// after 6 AM.
    public static func opensAtMinutesToday(
        weekday: String,
        openNow: Bool,
        waitzReopenMinutes: Int? = nil,
        arcWeek: [(day: String, open: Int, close: Int)] = GymService.arcWeek
    ) -> Int? {
        let schedule = todayOpenMinutes(weekday: weekday, arcWeek: arcWeek)
        guard !openNow, let waitz = waitzReopenMinutes else { return schedule }
        return waitz
    }

    /// Effective close for closed chrome — Waitz live-range close when known;
    /// when Waitz `Closed until …` is already past, pin done-for-today at that
    /// reopen so afternoon holiday closes say “Opens tomorrow” instead of
    /// waiting on the maintained 10 PM close.
    public static func closesAtMinutesToday(
        weekday: String,
        openNow: Bool,
        nowMinutes: Int,
        waitzCloseMinutes: Int? = nil,
        waitzReopenMinutes: Int? = nil,
        arcWeek: [(day: String, open: Int, close: Int)] = GymService.arcWeek
    ) -> Int? {
        if let waitz = waitzCloseMinutes { return waitz }
        if !openNow, let reopen = waitzReopenMinutes, nowMinutes >= reopen {
            return reopen
        }
        return todayCloseMinutes(weekday: weekday, arcWeek: arcWeek)
    }

    /// Tomorrow's open — prefer Waitz `Closed until …` when that clock is
    /// already past (next open is tomorrow at that time).
    public static func opensAtMinutesTomorrow(
        weekday: String,
        openNow: Bool = true,
        nowMinutes: Int? = nil,
        waitzReopenMinutes: Int? = nil,
        arcWeek: [(day: String, open: Int, close: Int)] = GymService.arcWeek
    ) -> Int? {
        let schedule = tomorrowOpenMinutes(weekday: weekday, arcWeek: arcWeek)
        if !openNow,
           let waitz = waitzReopenMinutes,
           let now = nowMinutes,
           now >= waitz {
            return waitz
        }
        return schedule
    }

    /// Copy when the Gym hero has no busyness %.
    public static func noBusynessMessage(
        openNow: Bool,
        nowMinutes: Int,
        opensAtMinutesToday: Int?,
        closesAtMinutesToday: Int?,
        opensAtMinutesTomorrow: Int? = nil
    ) -> String {
        if openNow {
            return "No busyness estimate right now"
        }
        if let open = opensAtMinutesToday, nowMinutes < open {
            return "Closed — opens at \(UCITime.format(minutes: open))"
        }
        if isDoneForToday(
            nowMinutes: nowMinutes,
            opensAtMinutesToday: opensAtMinutesToday,
            closesAtMinutesToday: closesAtMinutesToday
        ), let tomorrow = opensAtMinutesTomorrow {
            return "Closed — opens tomorrow at \(UCITime.format(minutes: tomorrow))"
        }
        // Unknown schedule / closed while today's window still lists as open.
        return "Closed — see you tomorrow"
    }

    /// Widget hours line while closed (open path stays "Open until …").
    public static func closedHoursLine(
        todayHours: String?,
        nowMinutes: Int,
        opensAtMinutesToday: Int?,
        closesAtMinutesToday: Int? = nil,
        opensAtMinutesTomorrow: Int? = nil
    ) -> String {
        if let open = opensAtMinutesToday, nowMinutes < open {
            return "Opens at \(UCITime.format(minutes: open))"
        }
        if isDoneForToday(
            nowMinutes: nowMinutes,
            opensAtMinutesToday: opensAtMinutesToday,
            closesAtMinutesToday: closesAtMinutesToday
        ), let tomorrow = opensAtMinutesTomorrow {
            return "Opens tomorrow at \(UCITime.format(minutes: tomorrow))"
        }
        guard let hours = todayHours else { return "Closed" }
        return "Closed · \(hours)"
    }

    /// Shared open chrome for widget / Gym hero hours.
    public static func hoursLine(
        openNow: Bool,
        todayHours: String?,
        nowMinutes: Int,
        opensAtMinutesToday: Int?,
        closesAtMinutesToday: Int? = nil,
        opensAtMinutesTomorrow: Int? = nil
    ) -> String {
        if openNow {
            guard let hours = todayHours else { return "Open" }
            if let line = WaitzHoursSummary.openUntilLine(hours) {
                return line
            }
            return "Open · \(hours)"
        }
        return closedHoursLine(
            todayHours: todayHours,
            nowMinutes: nowMinutes,
            opensAtMinutesToday: opensAtMinutesToday,
            closesAtMinutesToday: closesAtMinutesToday,
            opensAtMinutesTomorrow: opensAtMinutesTomorrow
        )
    }
}

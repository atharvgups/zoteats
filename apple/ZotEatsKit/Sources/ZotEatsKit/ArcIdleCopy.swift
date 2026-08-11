import Foundation

/// Honest ARC idle / closed chrome — "opens at 6:00 AM" before today's open,
/// not "see you tomorrow" while the hall is still hours away from opening.
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

    /// Copy when the Gym hero has no busyness %.
    public static func noBusynessMessage(
        openNow: Bool,
        nowMinutes: Int,
        opensAtMinutesToday: Int?,
        closesAtMinutesToday: Int?
    ) -> String {
        if openNow {
            return "No busyness estimate right now"
        }
        if let open = opensAtMinutesToday, nowMinutes < open {
            return "Closed — opens at \(UCITime.format(minutes: open))"
        }
        if let close = closesAtMinutesToday, nowMinutes >= close {
            return "Closed — see you tomorrow"
        }
        // Unknown schedule / between windows without clear open — keep honest.
        return "Closed — see you tomorrow"
    }

    /// Widget hours line while closed (open path stays "Open until …").
    public static func closedHoursLine(
        todayHours: String?,
        nowMinutes: Int,
        opensAtMinutesToday: Int?
    ) -> String {
        if let open = opensAtMinutesToday, nowMinutes < open {
            return "Opens at \(UCITime.format(minutes: open))"
        }
        guard let hours = todayHours else { return "Closed" }
        return "Closed · \(hours)"
    }

    /// Shared open chrome for widget / Gym hero hours.
    public static func hoursLine(
        openNow: Bool,
        todayHours: String?,
        nowMinutes: Int,
        opensAtMinutesToday: Int?
    ) -> String {
        if openNow {
            guard let hours = todayHours else { return "Open" }
            if let close = hours.components(separatedBy: "–").last?
                .trimmingCharacters(in: .whitespaces),
               !close.isEmpty {
                return "Open until \(close)"
            }
            return "Open · \(hours)"
        }
        return closedHoursLine(
            todayHours: todayHours,
            nowMinutes: nowMinutes,
            opensAtMinutesToday: opensAtMinutesToday
        )
    }
}

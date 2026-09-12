import Foundation

/// Honest Campus place hours chrome — "Opens at …" / "Opens tomorrow at …"
/// / "Opens Monday at …" / "Open until …" instead of a raw today's window
/// next to a Closed pill.
public enum CampusPlaceHoursLine {
    public static func resolve(
        openNow: Bool,
        todayHours: String?,
        opensAtMinutes: Int?,
        closesAtMinutes: Int?,
        opensTomorrowAtMinutes: Int?,
        /// True when today's (or a later) schedule was resolved from the feed —
        /// distinguishes weekend "off" from a missing/unparseable schedule.
        hoursKnown: Bool = true,
        opensNextAtMinutes: Int? = nil,
        opensNextWeekday: String? = nil
    ) -> String {
        if openNow {
            if let close = closesAtMinutes {
                return "Open until \(UCITime.format(minutes: close))"
            }
            guard let hours = todayHours else { return "Open" }
            if hours.localizedCaseInsensitiveContains("24") {
                return "Open 24 hours"
            }
            if let close = hours.components(separatedBy: "–").last?
                .trimmingCharacters(in: .whitespaces),
               !close.isEmpty {
                return "Open until \(close)"
            }
            return "Open · \(hours)"
        }

        if let open = opensAtMinutes {
            return "Opens at \(UCITime.format(minutes: open))"
        }
        if let open = opensTomorrowAtMinutes {
            return "Opens tomorrow at \(UCITime.format(minutes: open))"
        }
        if let open = opensNextAtMinutes, let weekday = opensNextWeekday, !weekday.isEmpty {
            return "Opens \(weekday) at \(UCITime.format(minutes: open))"
        }
        // Never echo a past todayHours window beside a Closed pill (Fri after
        // close → Sat off used to show "7:30 AM – 4:00 PM").
        if hoursKnown || todayHours != nil {
            return "Closed today"
        }
        return "Hours unavailable"
    }

    /// Compact secondary line for Campus Open widget rows (open venues only).
    public static func widgetOpenHours(
        todayHours: String?,
        closesAtMinutes: Int?
    ) -> String {
        if let close = closesAtMinutes {
            return "until \(UCITime.format(minutes: close))"
        }
        guard let hours = todayHours else { return "Open" }
        if hours.localizedCaseInsensitiveContains("24") {
            return "Open 24 hours"
        }
        if let close = hours.components(separatedBy: "–").last?
            .trimmingCharacters(in: .whitespaces),
           !close.isEmpty {
            return "until \(close)"
        }
        return hours
    }
}

public extension CampusPlace {
    /// List / sheet hours line driven by live open boundaries.
    var hoursLine: String {
        CampusPlaceHoursLine.resolve(
            openNow: openNow,
            todayHours: todayHours,
            opensAtMinutes: opensAtMinutes,
            closesAtMinutes: closesAtMinutes,
            opensTomorrowAtMinutes: opensTomorrowAtMinutes,
            hoursKnown: hoursKnown,
            opensNextAtMinutes: opensNextAtMinutes,
            opensNextWeekday: opensNextWeekday
        )
    }
}

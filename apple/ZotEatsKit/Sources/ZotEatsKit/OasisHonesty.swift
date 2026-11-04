import Foundation

/// Official Oasis hours from MyDiningHub `the-oasis-dining-hall`.
///
/// Standard Hub schedule: Lunch Mo-Fr 11:00-14:00, Dinner Mo-Th 16:30-20:00,
/// weekends off. Veteran's Day 2026-11-11 is a Hub special (all Wednesday off).
/// First service was Monday 5 October 2026. Hub menus currently post through
/// 17 December 2026. Never invent a menu.
public enum OasisSchedule: Sendable {
    /// Single source of truth. Format every Eat / widget line from this ISO.
    public static let firstServiceISO = "2026-10-05"

    /// Hub standard Lunch window (Irvine minutes).
    public static let lunchStartMinutes = 11 * 60
    public static let lunchEndMinutes = 14 * 60
    /// Hub standard Dinner window (Irvine minutes).
    public static let dinnerStartMinutes = 16 * 60 + 30
    public static let dinnerEndMinutes = 20 * 60

    /// Dated Hub specials that close the hall.
    public static let closedISOs: Set<String> = [
        "2026-11-11",
    ]

    /// Compact tile leftover; live tiles use until/opens hours instead.
    public static let opensLine = formatOpensLine(iso: firstServiceISO)

    public static func hasOpened(on iso: String) -> Bool {
        iso >= firstServiceISO
    }

    public static func isClosedDate(_ iso: String) -> Bool {
        closedISOs.contains(iso)
    }

    public static func isLunchWeekday(_ weekday: String) -> Bool {
        switch weekday.lowercased() {
        case "monday", "tuesday", "wednesday", "thursday", "friday":
            return true
        default:
            return false
        }
    }

    public static func isDinnerWeekday(_ weekday: String) -> Bool {
        switch weekday.lowercased() {
        case "monday", "tuesday", "wednesday", "thursday":
            return true
        default:
            return false
        }
    }

    public static func servesLunch(on iso: String, weekday: String) -> Bool {
        !isClosedDate(iso) && isLunchWeekday(weekday) && (hasOpened(on: iso) || iso >= firstServiceISO)
    }

    public static func servesDinner(on iso: String, weekday: String) -> Bool {
        !isClosedDate(iso) && isDinnerWeekday(weekday) && (hasOpened(on: iso) || iso >= firstServiceISO)
    }

    /// Hub-posted Lunch/Dinner that this weekday actually serves. Closed
    /// specials and Friday dinner stay off even if Hub copied SKUs.
    public static func postedMealIsServed(_ name: String, on iso: String, weekday: String) -> Bool {
        if isClosedDate(iso) { return false }
        if name.caseInsensitiveCompare("Lunch") == .orderedSame {
            return isLunchWeekday(weekday)
        }
        if name.caseInsensitiveCompare("Dinner") == .orderedSame {
            return isDinnerWeekday(weekday)
        }
        return false
    }

    /// Published Hub windows after `firstServiceISO`. Empty before open,
    /// on Sat/Sun, Friday dinner, and dated closures — never a fake menu.
    public static func mealWindows(on iso: String, weekday: String) -> [MealPeriodWindow] {
        var windows: [MealPeriodWindow] = []
        if servesLunch(on: iso, weekday: weekday) {
            windows.append(
                MealPeriodWindow(
                    name: "Lunch",
                    startMinutes: lunchStartMinutes,
                    endMinutes: lunchEndMinutes
                )
            )
        }
        if servesDinner(on: iso, weekday: weekday) {
            windows.append(
                MealPeriodWindow(
                    name: "Dinner",
                    startMinutes: dinnerStartMinutes,
                    endMinutes: dinnerEndMinutes
                )
            )
        }
        return windows
    }

    public static func todayHours(on iso: String, weekday: String) -> String? {
        let windows = mealWindows(on: iso, weekday: weekday)
        guard !windows.isEmpty else { return nil }
        return windows.compactMap { window -> String? in
            guard let start = window.startMinutes, let end = window.endMinutes else { return nil }
            return "\(PacificTime.formatMinutes(start)) – \(PacificTime.formatMinutes(end))"
        }
        .joined(separator: ", ")
    }

    /// Next Lunch (or Friday-after-Thursday, Monday after Friday) Oasis serves.
    public static func nextService(
        after iso: String
    ) -> (iso: String, weekday: String, dayOffset: Int, minutes: Int, period: String)? {
        guard let start = date(fromISO: iso) else { return nil }
        if let open = date(fromISO: firstServiceISO), iso < firstServiceISO {
            let offset = PacificTime.calendar.dateComponents([.day], from: start, to: open).day ?? 0
            if offset > 0 {
                return (
                    firstServiceISO,
                    PacificTime.weekdayName(now: open),
                    offset,
                    lunchStartMinutes,
                    "Lunch"
                )
            }
        }
        for offset in 1...12 {
            let day = PacificTime.calendar.date(byAdding: .day, value: offset, to: start) ?? start
            let dayISO = PacificTime.todayISO(now: day)
            let weekday = PacificTime.weekdayName(now: day)
            if servesLunch(on: dayISO, weekday: weekday) {
                return (dayISO, weekday, offset, lunchStartMinutes, "Lunch")
            }
        }
        return nil
    }

    public static func isOpen(on iso: String, weekday: String, nowMinutes: Int) -> Bool {
        mealWindows(on: iso, weekday: weekday).contains { window in
            guard let start = window.startMinutes, let end = window.endMinutes else { return false }
            return nowMinutes >= start && nowMinutes < end
        }
    }

    /// Keep Hub Lunch/Dinner that this calendar day actually serves.
    public static func servingPeriods(
        from posted: [String],
        on iso: String,
        weekday: String
    ) -> [String] {
        posted.filter { postedMealIsServed($0, on: iso, weekday: weekday) }
    }

    static func formatOpensLine(iso: String) -> String {
        guard let date = date(fromISO: iso) else { return "Opens Oct 5" }
        let out = DateFormatter()
        out.timeZone = PacificTime.timeZone
        out.locale = Locale(identifier: "en_US_POSIX")
        out.dateFormat = "EEE MMM d"
        return "Opens \(out.string(from: date))"
    }

    private static func date(fromISO iso: String) -> Date? {
        let parser = DateFormatter()
        parser.timeZone = PacificTime.timeZone
        parser.locale = Locale(identifier: "en_US_POSIX")
        parser.dateFormat = "yyyy-MM-dd"
        return parser.date(from: iso)
    }
}

/// Short Eat copy for The Oasis while no official board has dishes.
/// Hub hours are real. Never invent a menu.
public enum OasisComingSoonCopy: Sendable {
    public static let unpostedCard = "Menu not posted"
    public static let openUnposted = "Open, menu not posted"

    /// Hall-card status while no official Oasis dishes exist.
    public static var cardStatus: String { cardStatus(on: UCITime.todayISO()) }
    /// Selected empty board.
    public static var selectedLine: String { selectedLine(on: UCITime.todayISO()) }

    public static func cardStatus(
        on iso: String,
        weekday: String? = nil,
        nowMinutes: Int = UCITime.nowMinutes()
    ) -> String {
        _ = weekday
        _ = nowMinutes
        return unpostedCard
    }

    public static func selectedLine(
        on iso: String,
        weekday: String? = nil,
        nowMinutes: Int = UCITime.nowMinutes()
    ) -> String {
        let day = weekday ?? PacificTime.weekdayName(now: date(fromISO: iso) ?? Date())
        if OasisSchedule.isOpen(on: iso, weekday: day, nowMinutes: nowMinutes) {
            return "Open, menu not posted."
        }
        if !OasisSchedule.mealWindows(on: iso, weekday: day).isEmpty {
            return "UCI has not posted a menu. Hours are lunch 11 AM to 2 PM Monday to Friday, and dinner 4:30 to 8 PM Monday to Thursday."
        }
        return "Closed today. UCI has not posted a menu."
    }

    private static func date(fromISO iso: String) -> Date? {
        let parser = DateFormatter()
        parser.timeZone = PacificTime.timeZone
        parser.locale = Locale(identifier: "en_US_POSIX")
        parser.dateFormat = "yyyy-MM-dd"
        return parser.date(from: iso)
    }
}

/// Dining Hub listing for The Oasis. Peek `getLocations`; only `liveBoard`
/// means Hub marked `hasActiveMenus`. Recipes are scraped separately — a live
/// flag with an empty SKU map still stays unposted (no invented menu).
public enum OasisHubListing: Equatable, Sendable {
    case notListed
    case comingSoon
    case liveBoard(urlKey: String)

    public static func resolve(
        _ rows: [(urlKey: String, hasActiveMenus: Bool)]
    ) -> OasisHubListing {
        guard let row = rows.first(where: { HallDirectory.isOasis($0.urlKey) }) else {
            return .notListed
        }
        if row.hasActiveMenus {
            return .liveBoard(urlKey: row.urlKey)
        }
        return .comingSoon
    }
}

import Foundation

/// Official first service day for The Oasis (Mesa Court), from Dining Hub hours.
///
/// Hub `the-oasis-dining-hall` specials are all-off through 2026-10-02
/// (Summer, Welcome Week, then "9/28 - 10/2"). Standard hours are Mon–Fri
/// Lunch 11:00–14:30, Afternoon Snack 14:30–16:30, Dinner 16:30–20:00.
/// First serving day is Monday 5 October 2026 — not meal-plan start (Sept 21).
public enum OasisSchedule: Sendable {
    /// Single source of truth. Format every Eat / widget line from this ISO.
    public static let firstServiceISO = "2026-10-05"

    /// Hub standard Lunch window (Irvine minutes).
    public static let lunchStartMinutes = 11 * 60
    public static let lunchEndMinutes = 14 * 60 + 30
    /// Hub standard Afternoon Snack window (Irvine minutes).
    public static let snackStartMinutes = 14 * 60 + 30
    public static let snackEndMinutes = 16 * 60 + 30
    /// Hub standard Dinner window (Irvine minutes).
    public static let dinnerStartMinutes = 16 * 60 + 30
    public static let dinnerEndMinutes = 20 * 60

    /// Compact tile: "Opens Mon Oct 5"
    public static let opensLine = formatOpensLine(iso: firstServiceISO)

    public static func hasOpened(on iso: String) -> Bool {
        iso >= firstServiceISO
    }

    public static func isWeekday(_ weekday: String) -> Bool {
        switch weekday.lowercased() {
        case "monday", "tuesday", "wednesday", "thursday", "friday":
            return true
        default:
            return false
        }
    }

    /// Published Hub weekday windows after `firstServiceISO`. Empty before open
    /// and on Sat/Sun — never a fake menu.
    public static func mealWindows(on iso: String, weekday: String) -> [MealPeriodWindow] {
        guard hasOpened(on: iso), isWeekday(weekday) else { return [] }
        return [
            MealPeriodWindow(
                name: "Lunch",
                startMinutes: lunchStartMinutes,
                endMinutes: lunchEndMinutes
            ),
            MealPeriodWindow(
                name: "Afternoon Snack",
                startMinutes: snackStartMinutes,
                endMinutes: snackEndMinutes
            ),
            MealPeriodWindow(
                name: "Dinner",
                startMinutes: dinnerStartMinutes,
                endMinutes: dinnerEndMinutes
            ),
        ]
    }

    public static func todayHours(on iso: String, weekday: String) -> String? {
        guard !mealWindows(on: iso, weekday: weekday).isEmpty else { return nil }
        return "\(PacificTime.formatMinutes(lunchStartMinutes)) – \(PacificTime.formatMinutes(dinnerEndMinutes))"
    }

    /// Next Lunch after `iso` that Oasis actually serves.
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
        for offset in 1...10 {
            let day = PacificTime.calendar.date(byAdding: .day, value: offset, to: start) ?? start
            let dayISO = PacificTime.todayISO(now: day)
            let weekday = PacificTime.weekdayName(now: day)
            if hasOpened(on: dayISO), isWeekday(weekday) {
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
        let day = weekday ?? PacificTime.weekdayName(now: date(fromISO: iso) ?? Date())
        if OasisSchedule.isOpen(on: iso, weekday: day, nowMinutes: nowMinutes) {
            return unpostedCard
        }
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
            return "UCI has not posted a menu. Hours are lunch 11 AM to 2:30 PM, snack 2:30 to 4:30 PM, and dinner 4:30 to 8 PM, Monday to Friday."
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

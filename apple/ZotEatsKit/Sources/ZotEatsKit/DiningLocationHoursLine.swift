import Foundation

/// Static dining-hall hours chrome for pickers / lists that don't tick countdowns —
/// period + clock time, or tomorrow's first meal, instead of a raw daily window.
public enum DiningLocationHoursLine {
    public static func resolve(
        state: HallOpenState,
        todayHours: String?,
        opensTomorrowAtMinutes: Int?,
        opensTomorrowPeriod: String?
    ) -> String {
        switch state {
        case .open(let period, let closesAt):
            return "\(period) · until \(UCITime.format(minutes: closesAt % (24 * 60)))"
        case .openingLater(let period, let opensAt):
            return "\(period) at \(UCITime.format(minutes: opensAt))"
        case .closedForToday:
            if let open = opensTomorrowAtMinutes {
                let meal = opensTomorrowPeriod ?? "Opens"
                return "\(meal) tomorrow · \(UCITime.format(minutes: open))"
            }
            return "Closed for today"
        case .unknown:
            return todayHours ?? "Closed today"
        }
    }
}

public extension DiningLocation {
    /// Opening Alerts / settings detail line from live meal windows.
    func hoursLine(nowMinutes: Int = UCITime.nowMinutes()) -> String {
        DiningLocationHoursLine.resolve(
            state: openState(nowMinutes: nowMinutes),
            todayHours: todayHours,
            opensTomorrowAtMinutes: opensTomorrowAtMinutes,
            opensTomorrowPeriod: opensTomorrowPeriod
        )
    }
}

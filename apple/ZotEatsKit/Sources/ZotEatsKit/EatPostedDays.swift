import Foundation

/// Days Eat should offer in the day picker — today always, future days only
/// when that hall actually has a posted board (not every day inside `/dateRange`).
public enum EatPostedDays {
    public static func visible(
        candidates: [(isoDate: String, label: String)],
        todayISO: String,
        postedISOs: Set<String>?
    ) -> [(isoDate: String, label: String)] {
        candidates.filter { day in
            if day.isoDate == todayISO { return true }
            guard let postedISOs else { return false }
            return postedISOs.contains(day.isoDate)
        }
    }
}

/// Honest empty copy when a browsed day/meal has no dishes — no jargon.
public enum EatBrowseEmptyCopy {
    public static func message(period: String, browsingFutureDay: Bool) -> String {
        let meal = period.trimmingCharacters(in: .whitespacesAndNewlines)
        if browsingFutureDay {
            if meal.isEmpty {
                return "UCI hasn’t posted a menu for this day yet. Pick another day above."
            }
            return "No \(meal.lowercased()) on the board for this day. Try another meal, or pick another day above."
        }
        if meal.isEmpty {
            return "This hall hasn’t posted a menu yet. Check back soon."
        }
        return "This hall hasn’t published \(meal.lowercased()) yet. Check back soon."
    }
}

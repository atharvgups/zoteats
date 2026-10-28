import Foundation

/// Why a student flagged a dish listing. UCI's feeds sometimes put a recipe
/// on the wrong hall or leave a leftover on the board; reports never move or
/// invent dishes.
public enum DishReportReason: String, Codable, Sendable, CaseIterable, Equatable, Hashable {
    case notAtHall
    case notServed
    case wrongStation

    public var title: String {
        switch self {
        case .notAtHall: return DishReportCopy.notAtHall
        case .notServed: return DishReportCopy.notServed
        case .wrongStation: return DishReportCopy.wrongStation
        }
    }
}

/// One person's flag for a dish on one hall, meal, and Irvine day.
public struct DishReport: Codable, Equatable, Sendable, Identifiable {
    public var date: String
    public var hall: String
    public var meal: String
    public var dishID: String
    public var dishName: String
    public var reason: DishReportReason
    public var authorID: String
    public var updatedAt: Date

    public var id: String {
        DishReportLogic.reportID(
            date: date,
            hall: hall,
            meal: meal,
            dishID: dishID,
            dishName: dishName,
            authorID: authorID
        )
    }

    public init(
        date: String,
        hall: String,
        meal: String,
        dishID: String,
        dishName: String,
        reason: DishReportReason,
        authorID: String,
        updatedAt: Date = Date()
    ) {
        self.date = DishReportLogic.canonicalDate(date)
        self.hall = DishReportLogic.canonicalHall(hall)
        self.meal = DishReportLogic.canonicalMeal(meal)
        self.dishID = DishReportLogic.canonicalDishID(dishID, dishName: dishName)
        self.dishName = dishName.trimmingCharacters(in: .whitespacesAndNewlines)
        self.reason = reason
        self.authorID = authorID.trimmingCharacters(in: .whitespacesAndNewlines)
        self.updatedAt = updatedAt
    }
}

public enum DishReportCopy {
    public static let rowTitle = "Report a problem"
    public static let rowSubtitle = "Flag a listing that looks wrong"
    public static let dialogTitle = "What's wrong with this dish?"
    public static let dialogMessage =
        "UCI's board is sometimes off. The dish stays listed until they fix the feed."
    public static let notAtHall = "Not at this hall"
    public static let notServed = "Not being served"
    public static let wrongStation = "Wrong station"
    public static let thanks = "Thanks. You flagged this for today."
    public static let already = "You already flagged this today."
    public static let missingNote = "Reported missing"
    public static let missingCaption = "Students say this isn't here today."
    public static let cancel = "Cancel"
}

public enum DishReportLogic {
    /// Unique people who must flag the same listing before Eat shows the note.
    public static let missingThreshold = 2

    public static func canonicalDate(_ date: String) -> String {
        date.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    public static func canonicalHall(_ hall: String) -> String {
        let trimmed = hall.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        if HallDirectory.isOasis(trimmed) { return "oasis" }
        if trimmed == "the-anteatery" { return "anteatery" }
        return trimmed
    }

    public static func canonicalMeal(_ meal: String) -> String {
        MealPeriodPill.canonical(meal)
    }

    public static func canonicalDishID(_ dishID: String, dishName: String) -> String {
        let trimmed = dishID.trimmingCharacters(in: .whitespacesAndNewlines)
        if !trimmed.isEmpty { return trimmed }
        let nameKey = MealReview.key(for: dishName)
        return nameKey.isEmpty ? "" : "name:\(nameKey)"
    }

    public static func listingKey(
        date: String,
        hall: String,
        meal: String,
        dishID: String,
        dishName: String = ""
    ) -> String {
        let id = canonicalDishID(dishID, dishName: dishName)
        return [
            canonicalDate(date),
            canonicalHall(hall),
            canonicalMeal(meal).lowercased(),
            id.lowercased(),
        ].joined(separator: "|")
    }

    public static func reportID(
        date: String,
        hall: String,
        meal: String,
        dishID: String,
        dishName: String,
        authorID: String
    ) -> String {
        let author = authorID.trimmingCharacters(in: .whitespacesAndNewlines)
        return "\(listingKey(date: date, hall: hall, meal: meal, dishID: dishID, dishName: dishName))|\(author)"
    }

    public static func reports(
        in reports: [DishReport],
        date: String,
        hall: String,
        meal: String,
        dishID: String,
        dishName: String = ""
    ) -> [DishReport] {
        let id = canonicalDishID(dishID, dishName: dishName)
        guard !canonicalDate(date).isEmpty, !canonicalHall(hall).isEmpty, !id.isEmpty else {
            return []
        }
        let key = listingKey(date: date, hall: hall, meal: meal, dishID: dishID, dishName: dishName)
        return reports.filter {
            listingKey(
                date: $0.date,
                hall: $0.hall,
                meal: $0.meal,
                dishID: $0.dishID,
                dishName: $0.dishName
            ) == key
        }
    }

    public static func uniqueAuthorCount(
        in reports: [DishReport],
        date: String,
        hall: String,
        meal: String,
        dishID: String,
        dishName: String = ""
    ) -> Int {
        Set(
            self.reports(
                in: reports,
                date: date,
                hall: hall,
                meal: meal,
                dishID: dishID,
                dishName: dishName
            ).map(\.authorID)
        ).filter { !$0.isEmpty }.count
    }

    /// Subtle card/sheet note only. Never hides, moves, or invents a dish.
    public static func isReportedMissing(
        in reports: [DishReport],
        date: String,
        hall: String,
        meal: String,
        dishID: String,
        dishName: String = ""
    ) -> Bool {
        uniqueAuthorCount(
            in: reports,
            date: date,
            hall: hall,
            meal: meal,
            dishID: dishID,
            dishName: dishName
        ) >= missingThreshold
    }

    public static func lookup(
        _ reports: [DishReport],
        date: String,
        hall: String,
        meal: String,
        dishID: String,
        dishName: String,
        authorID: String
    ) -> DishReport? {
        let wanted = reportID(
            date: date,
            hall: hall,
            meal: meal,
            dishID: dishID,
            dishName: dishName,
            authorID: authorID
        )
        return reports.first { $0.id == wanted }
    }

    public static func upsert(
        existing: [DishReport],
        date: String,
        hall: String,
        meal: String,
        dishID: String,
        dishName: String,
        reason: DishReportReason,
        authorID: String,
        now: Date = Date()
    ) -> [DishReport] {
        let trimmedAuthor = authorID.trimmingCharacters(in: .whitespacesAndNewlines)
        let report = DishReport(
            date: date,
            hall: hall,
            meal: meal,
            dishID: dishID,
            dishName: dishName,
            reason: reason,
            authorID: trimmedAuthor,
            updatedAt: now
        )
        guard !report.date.isEmpty, !report.hall.isEmpty, !report.meal.isEmpty,
              !report.dishID.isEmpty, !report.authorID.isEmpty
        else { return existing }
        var next = existing.filter { $0.id != report.id }
        next.append(report)
        return next.sorted { $0.updatedAt > $1.updatedAt }
    }

    /// Reports never rewrite the board. Callers keep this as the Eat menu.
    public static func leavingMenuUnchanged(_ menu: DiningMenu) -> DiningMenu {
        menu
    }
}

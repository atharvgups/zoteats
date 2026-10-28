package com.atharvgupta.anteats.data

data class DishReport(
    val date: String,
    val hall: String,
    val meal: String,
    val dishID: String,
    val dishName: String,
    val reason: String,
    val authorID: String,
    val updatedAt: String,
) {
    val id: String
        get() = DishReportLogic.reportID(date, hall, meal, dishID, dishName, authorID)
}

object DishReportReason {
    const val NOT_AT_HALL = "notAtHall"
    const val NOT_SERVED = "notServed"
    const val WRONG_STATION = "wrongStation"
    val all = listOf(NOT_AT_HALL, NOT_SERVED, WRONG_STATION)

    fun title(reason: String): String = when (reason) {
        NOT_AT_HALL -> DishReportCopy.notAtHall
        NOT_SERVED -> DishReportCopy.notServed
        WRONG_STATION -> DishReportCopy.wrongStation
        else -> DishReportCopy.rowTitle
    }
}

object DishReportCopy {
    const val rowTitle = "Report a problem"
    const val rowSubtitle = "Flag a listing that looks wrong"
    const val dialogTitle = "What's wrong with this dish?"
    const val dialogMessage =
        "UCI's board is sometimes off. The dish stays listed until they fix the feed."
    const val notAtHall = "Not at this hall"
    const val notServed = "Not being served"
    const val wrongStation = "Wrong station"
    const val thanks = "Thanks. You flagged this for today."
    const val already = "You already flagged this today."
    const val missingNote = "Reported missing"
    const val missingCaption = "Students say this isn't here today."
    const val cancel = "Cancel"
}

object DishReportLogic {
    const val missingThreshold = 2

    fun canonicalHall(hall: String): String {
        val trimmed = hall.trim().lowercase()
        if (HallDirectory.isOasis(trimmed)) return "oasis"
        if (trimmed == "the-anteatery") return "anteatery"
        return trimmed
    }

    fun canonicalMeal(meal: String): String = DiningLogic.canonicalPill(meal)

    fun canonicalDishID(dishID: String, dishName: String): String {
        val trimmed = dishID.trim()
        if (trimmed.isNotEmpty()) return trimmed
        val nameKey = dishName.trim().lowercase()
        return if (nameKey.isEmpty()) "" else "name:$nameKey"
    }

    fun listingKey(
        date: String,
        hall: String,
        meal: String,
        dishID: String,
        dishName: String = "",
    ): String {
        val id = canonicalDishID(dishID, dishName)
        return listOf(
            date.trim(),
            canonicalHall(hall),
            canonicalMeal(meal).lowercase(),
            id.lowercase(),
        ).joinToString("|")
    }

    fun reportID(
        date: String,
        hall: String,
        meal: String,
        dishID: String,
        dishName: String,
        authorID: String,
    ): String = "${listingKey(date, hall, meal, dishID, dishName)}|${authorID.trim()}"

    fun reports(
        reports: List<DishReport>,
        date: String,
        hall: String,
        meal: String,
        dishID: String,
        dishName: String = "",
    ): List<DishReport> {
        val id = canonicalDishID(dishID, dishName)
        if (date.trim().isEmpty() || canonicalHall(hall).isEmpty() || id.isEmpty()) return emptyList()
        val key = listingKey(date, hall, meal, dishID, dishName)
        return reports.filter {
            listingKey(it.date, it.hall, it.meal, it.dishID, it.dishName) == key
        }
    }

    fun uniqueAuthorCount(
        reports: List<DishReport>,
        date: String,
        hall: String,
        meal: String,
        dishID: String,
        dishName: String = "",
    ): Int = reports(reports, date, hall, meal, dishID, dishName)
        .map { it.authorID }
        .filter { it.isNotBlank() }
        .toSet()
        .size

    fun isReportedMissing(
        reports: List<DishReport>,
        date: String,
        hall: String,
        meal: String,
        dishID: String,
        dishName: String = "",
    ): Boolean = uniqueAuthorCount(reports, date, hall, meal, dishID, dishName) >= missingThreshold

    fun lookup(
        reports: List<DishReport>,
        date: String,
        hall: String,
        meal: String,
        dishID: String,
        dishName: String,
        authorID: String,
    ): DishReport? {
        val wanted = reportID(date, hall, meal, dishID, dishName, authorID)
        return reports.firstOrNull { it.id == wanted }
    }

    fun upsert(
        existing: List<DishReport>,
        date: String,
        hall: String,
        meal: String,
        dishID: String,
        dishName: String,
        reason: String,
        authorID: String,
        updatedAt: String,
    ): List<DishReport> {
        val report = DishReport(
            date = date.trim(),
            hall = canonicalHall(hall),
            meal = canonicalMeal(meal),
            dishID = canonicalDishID(dishID, dishName),
            dishName = dishName.trim(),
            reason = reason,
            authorID = authorID.trim(),
            updatedAt = updatedAt,
        )
        if (report.date.isEmpty() || report.hall.isEmpty() || report.meal.isEmpty() ||
            report.dishID.isEmpty() || report.authorID.isEmpty() ||
            report.reason !in DishReportReason.all
        ) {
            return existing
        }
        return (existing.filter { it.id != report.id } + report)
            .sortedByDescending { it.updatedAt }
    }

    fun leavingMenuUnchanged(menu: DiningMenu): DiningMenu = menu
}

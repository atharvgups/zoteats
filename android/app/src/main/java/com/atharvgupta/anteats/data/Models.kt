package com.atharvgupta.anteats.data

data class MealPeriodWindow(
    val name: String,
    val startMinutes: Int?,
    val endMinutes: Int?,
)

data class DiningLocation(
    val id: String,
    val name: String,
    val compactName: String,
    val area: String,
    val openNow: Boolean,
    val todayHours: String?,
    val availablePeriods: List<String>,
    val periods: List<MealPeriodWindow>,
    val comingSoonSubtitle: String? = null,
) {
    val isComingSoon: Boolean get() = comingSoonSubtitle != null
}

data class NutritionFacts(
    val proteinG: Double? = null,
    val totalCarbsG: Double? = null,
    val totalFatG: Double? = null,
    val saturatedFatG: Double? = null,
    val transFatG: Double? = null,
    val sodiumMg: Double? = null,
    val sugarsG: Double? = null,
    val dietaryFiberG: Double? = null,
    val ingredients: String? = null,
) {
    val hasMacros: Boolean
        get() = proteinG != null || totalCarbsG != null || totalFatG != null
    val hasDetails: Boolean
        get() = saturatedFatG != null || transFatG != null || sodiumMg != null ||
            sugarsG != null || dietaryFiberG != null || !ingredients.isNullOrBlank()
}

data class MenuItem(
    val id: String,
    val name: String,
    val description: String?,
    val calories: Int?,
    val servingSize: String?,
    val allergens: List<String>,
    val dietaryTags: List<String>,
    val nutrition: NutritionFacts? = null,
    val stationID: String? = null,
)

data class MenuStation(
    val name: String,
    val items: List<MenuItem>,
    val stationID: String? = null,
    val serviceLabel: String? = null,
) {
    fun withItems(next: List<MenuItem>) = copy(items = next)
}

data class DiningMenu(
    val locationId: String,
    val date: String,
    val period: String,
    val stations: List<MenuStation>,
    val twistedRootMeals: List<String> = emptyList(),
)

data class MenuMergeIssue(
    val hallID: String,
    val date: String,
    val period: String,
    val stationName: String,
    val stationID: String?,
    val kind: Kind,
    val dishName: String,
) {
    enum class Kind {
        LOST_ANTEATER_ENTREE,
        STAPLES_ONLY_DESPITE_ENTREES,
        DUPLICATE_DISH_IN_STATION,
        UNPOSTED_MERGED_DISH,
        HUB_COMPETING_TWISTED_ROOT_ENTREE,
        BOARD_VERIFIED_STATION_MISMATCH,
    }

    override fun toString(): String = when (kind) {
        Kind.LOST_ANTEATER_ENTREE ->
            "$hallID $date $period $stationName lost Anteater entree $dishName"
        Kind.STAPLES_ONLY_DESPITE_ENTREES ->
            "$hallID $date $period $stationName is staples-only while a source still has $dishName"
        Kind.DUPLICATE_DISH_IN_STATION ->
            "$hallID $date $period $stationName lists $dishName more than once"
        Kind.UNPOSTED_MERGED_DISH ->
            "$hallID $date $period $stationName lists $dishName which is not on the posted menu"
        Kind.HUB_COMPETING_TWISTED_ROOT_ENTREE ->
            "$hallID $date $period $stationName added Hub $dishName on top of an Anteater Twisted Root entree"
        Kind.BOARD_VERIFIED_STATION_MISMATCH ->
            "$hallID $date $period $stationName does not match the photographed board for $dishName"
    }
}

data class DiningEvent(
    val title: String,
    val restaurantId: String,
    val start: java.time.ZonedDateTime? = null,
    val end: java.time.ZonedDateTime? = null,
)

data class PublishedDateRange(
    val earliest: String,
    val latest: String,
) {
    fun contains(isoDate: String) = isoDate >= earliest && isoDate <= latest
}

data class EatPostedDay(
    val isoDate: String,
    val label: String,
)

data class PlateEntry(
    val dish: MenuItem,
    val quantity: Int,
) {
    val lineCalories: Int get() = (dish.calories ?: 0) * quantity
    val lineProteinG: Double get() = (dish.nutrition?.proteinG ?: 0.0) * quantity
}

object HallDirectory {
    const val ANTEATERY = "anteatery"
    const val BRANDYWINE = "brandywine"
    const val OASIS = "oasis"
    val fallbackIds = listOf(ANTEATERY, BRANDYWINE)

    fun isOasis(id: String): Boolean = when (id.lowercase()) {
        "oasis", "the-oasis", "the-oasis-dining-hall" -> true
        else -> false
    }

    fun campusHubKey(hallID: String): String? = when (hallID.lowercase()) {
        ANTEATERY -> "the-anteatery"
        BRANDYWINE -> "brandywine"
        "oasis", "the-oasis", "the-oasis-dining-hall" -> "the-oasis-dining-hall"
        else -> null
    }

    fun eatHallID(hubKey: String): String? = when (hubKey.lowercase()) {
        "the-anteatery" -> ANTEATERY
        "brandywine" -> BRANDYWINE
        "oasis", "the-oasis", "the-oasis-dining-hall" -> OASIS
        else -> null
    }

    fun displayName(id: String): String = when (id.lowercase()) {
        ANTEATERY -> "The Anteatery"
        BRANDYWINE -> "Brandywine"
        "oasis", "the-oasis", "the-oasis-dining-hall" -> "The Oasis"
        else -> prettify(id)
    }

    fun compactName(id: String): String = when (id.lowercase()) {
        ANTEATERY -> "Anteatery"
        BRANDYWINE -> "Brandywine"
        "oasis", "the-oasis", "the-oasis-dining-hall" -> "Oasis"
        else -> displayName(id).removePrefix("The ")
    }

    fun area(id: String): String = when (id.lowercase()) {
        ANTEATERY, "oasis", "the-oasis", "the-oasis-dining-hall" -> "Mesa Court"
        BRANDYWINE -> "Middle Earth"
        else -> "UCI Campus"
    }

    private fun prettify(id: String): String =
        id.split('-', '_').joinToString(" ") { part ->
            part.replaceFirstChar { it.uppercase() }
        }
}

object OasisSchedule {
    const val firstServiceISO = "2026-10-05"
    const val lunchStartMinutes = 11 * 60
    const val lunchEndMinutes = 14 * 60
    const val dinnerStartMinutes = 16 * 60 + 30
    const val dinnerEndMinutes = 20 * 60
    const val unpostedCard = "Menu not posted"
    const val openUnposted = "Open, menu not posted"
    val closedISOs = setOf("2026-11-11")

    fun opensLine(iso: String = firstServiceISO): String {
        val stamp = PacificTime.opensStamp(iso) ?: "Mon Oct 5"
        return "Opens $stamp"
    }

    fun hasOpened(iso: String): Boolean = iso >= firstServiceISO

    fun isClosedDate(iso: String): Boolean = iso in closedISOs

    fun isLunchWeekday(weekday: String): Boolean = when (weekday.lowercase()) {
        "monday", "tuesday", "wednesday", "thursday", "friday" -> true
        else -> false
    }

    fun isDinnerWeekday(weekday: String): Boolean = when (weekday.lowercase()) {
        "monday", "tuesday", "wednesday", "thursday" -> true
        else -> false
    }

    fun servesLunch(dateISO: String, weekday: String): Boolean =
        hasOpened(dateISO) && !isClosedDate(dateISO) && isLunchWeekday(weekday)

    fun servesDinner(dateISO: String, weekday: String): Boolean =
        hasOpened(dateISO) && !isClosedDate(dateISO) && isDinnerWeekday(weekday)

    fun mealWindows(dateISO: String, weekday: String): List<MealPeriodWindow> {
        val windows = mutableListOf<MealPeriodWindow>()
        if (servesLunch(dateISO, weekday)) {
            windows += MealPeriodWindow("Lunch", lunchStartMinutes, lunchEndMinutes)
        }
        if (servesDinner(dateISO, weekday)) {
            windows += MealPeriodWindow("Dinner", dinnerStartMinutes, dinnerEndMinutes)
        }
        return windows
    }

    fun todayHours(dateISO: String, weekday: String): String? {
        val windows = mealWindows(dateISO, weekday)
        if (windows.isEmpty()) return null
        return windows.mapNotNull { window ->
            val start = window.startMinutes ?: return@mapNotNull null
            val end = window.endMinutes ?: return@mapNotNull null
            "${PacificTime.formatMinutes(start)} to ${PacificTime.formatMinutes(end)}"
        }.joinToString(", ")
    }

    fun servingPeriods(posted: List<String>, dateISO: String, weekday: String): List<String> =
        posted.filter { name ->
            if (isClosedDate(dateISO)) return@filter false
            when {
                name.equals("Lunch", true) -> isLunchWeekday(weekday)
                name.equals("Dinner", true) -> isDinnerWeekday(weekday)
                else -> false
            }
        }

    fun isOpen(dateISO: String, weekday: String, nowMinutes: Int): Boolean =
        mealWindows(dateISO, weekday).any { window ->
            val start = window.startMinutes ?: return@any false
            val end = window.endMinutes ?: return@any false
            nowMinutes >= start && nowMinutes < end
        }

    fun selectedLine(
        dateISO: String = PacificTime.todayISO(),
        weekday: String = PacificTime.weekdayName(dateISO).orEmpty(),
        nowMinutes: Int = PacificTime.nowMinutes(),
    ): String {
        if (isOpen(dateISO, weekday, nowMinutes)) return "Open, menu not posted."
        if (mealWindows(dateISO, weekday).isNotEmpty()) {
            return "UCI has not posted a menu. Hours are lunch 11 AM to 2 PM Monday to Friday, and dinner 4:30 to 8 PM Monday to Thursday."
        }
        return "Closed today. UCI has not posted a menu."
    }

    fun comingSoonLocation(
        dateISO: String = PacificTime.todayISO(),
        nowMinutes: Int = PacificTime.nowMinutes(),
    ): DiningLocation {
        val weekday = PacificTime.weekdayName(dateISO).orEmpty()
        val windows = mealWindows(dateISO, weekday)
        return DiningLocation(
            id = HallDirectory.OASIS,
            name = HallDirectory.displayName(HallDirectory.OASIS),
            compactName = HallDirectory.compactName(HallDirectory.OASIS),
            area = HallDirectory.area(HallDirectory.OASIS),
            openNow = isOpen(dateISO, weekday, nowMinutes),
            todayHours = todayHours(dateISO, weekday),
            availablePeriods = emptyList(),
            periods = windows,
            comingSoonSubtitle = unpostedCard,
        )
    }

    fun locationFromHubRecipes(
        postedPeriods: List<String>,
        dateISO: String = PacificTime.todayISO(),
        nowMinutes: Int = PacificTime.nowMinutes(),
        windows: List<MealPeriodWindow> = mealWindows(dateISO, PacificTime.weekdayName(dateISO).orEmpty()),
    ): DiningLocation {
        val weekday = PacificTime.weekdayName(dateISO).orEmpty()
        return DiningLocation(
            id = HallDirectory.OASIS,
            name = HallDirectory.displayName(HallDirectory.OASIS),
            compactName = HallDirectory.compactName(HallDirectory.OASIS),
            area = HallDirectory.area(HallDirectory.OASIS),
            openNow = windows.any { window ->
                val start = window.startMinutes ?: return@any false
                val end = window.endMinutes ?: return@any false
                nowMinutes >= start && nowMinutes < end
            },
            todayHours = windows.mapNotNull { window ->
                val start = window.startMinutes ?: return@mapNotNull null
                val end = window.endMinutes ?: return@mapNotNull null
                "${PacificTime.formatMinutes(start)} to ${PacificTime.formatMinutes(end)}"
            }.takeIf { it.isNotEmpty() }?.joinToString(", ") ?: todayHours(dateISO, weekday),
            availablePeriods = postedPeriods.filter { it.isNotBlank() },
            periods = windows,
        )
    }
}

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
    const val lunchEndMinutes = 14 * 60 + 30
    const val dinnerStartMinutes = 16 * 60 + 30
    const val dinnerEndMinutes = 20 * 60

    fun opensLine(iso: String = firstServiceISO): String {
        val weekday = PacificTime.weekdayShort(iso) ?: "Mon"
        val monthDay = PacificTime.monthDay(iso) ?: "Oct 5"
        return "Opens $weekday $monthDay"
    }

    fun comingSoonLocation(dateISO: String = PacificTime.todayISO()): DiningLocation =
        DiningLocation(
            id = HallDirectory.OASIS,
            name = HallDirectory.displayName(HallDirectory.OASIS),
            compactName = HallDirectory.compactName(HallDirectory.OASIS),
            area = HallDirectory.area(HallDirectory.OASIS),
            openNow = false,
            todayHours = null,
            availablePeriods = emptyList(),
            periods = emptyList(),
            comingSoonSubtitle = if (dateISO < firstServiceISO) opensLine() else "Coming soon",
        )
}

package com.atharvgupta.anteats.data

object DiningLogic {
    val mealSelectorPills = listOf("Breakfast", "Lunch", "Afternoon Snack", "Dinner", "Late Night")
    val twistedRootStationIDs = setOf("1929", "1893")
    val emberStationIDs = setOf("1878")
    val standingBurgerStationIDs = setOf("1878", "1935")
    val dessertStationIDs = setOf("1872", "1938")
    val pizzaStationIDs = setOf("1941", "1884")
    val dishBatchChunkSizes = listOf(40, 8, 1)

    enum class StationLane {
        TWISTED_ROOT,
        HOT_ENTREE,
        OTHER,
        SIDES,
        AVAILABLE_ALL_DAY,
        DESSERT,
        PIZZA,
        STANDING_BURGER,
    }

    fun isAfternoonSnack(name: String): Boolean {
        val lower = name.lowercase()
        if ("afternoon snack" in lower) return true
        return "snack" in lower && "evening" !in lower && "late" !in lower
    }

    fun isLateNight(name: String): Boolean {
        val lower = name.lowercase()
        return "late night" in lower || "evening snack" in lower || "overnight" in lower
    }

    fun canonicalPill(liveName: String): String {
        val lower = liveName.trim().lowercase()
        if ("brunch" in lower || "breakfast" in lower) return "Breakfast"
        if ("lunch" in lower) return "Lunch"
        if ("dinner" in lower) return "Dinner"
        if (isAfternoonSnack(lower)) return "Afternoon Snack"
        if (isLateNight(lower)) return "Late Night"
        return liveName.trim()
    }

    fun periodRank(name: String, startMinutes: Int?): Pair<Int, Int> {
        val known = mapOf(
            "breakfast" to 0,
            "brunch" to 1,
            "lunch" to 2,
            "lite lunch" to 3,
            "afternoon snack" to 4,
            "dinner" to 5,
            "limited dinner" to 5,
            "evening snack" to 6,
            "late night" to 7,
            "overnight" to 8,
        )
        val lower = name.lowercase()
        known[lower]?.let { return it * 100 to (startMinutes ?: 0) }
        if ("all day" in lower) return 10_000 to 0
        val start = startMinutes
        return if (start != null) (start / 60 * 100 + 50) to start else 9_000 to 0
    }

    fun primaryPeriods(available: List<String>): List<String> {
        val result = mutableListOf<String>()
        if (available.any { it.equals("Breakfast", true) } || available.any { it.equals("Brunch", true) }) {
            result += "Breakfast"
        }
        if (available.any { it.equals("Lunch", true) }) result += "Lunch"
        if (available.any { isAfternoonSnack(it) }) result += "Afternoon Snack"
        if (available.any { it.equals("Dinner", true) || it.equals("Limited Dinner", true) }) {
            result += "Dinner"
        }
        if (available.any { isLateNight(it) }) result += "Late Night"
        return result
    }

    fun pillIsPosted(pill: String, available: List<String>): Boolean =
        primaryPeriods(available).any { it.equals(pill, true) }

    fun resolvePeriod(primary: String, available: List<String>): String {
        fun match(name: String) = available.firstOrNull { it.equals(name, true) }
        return when (primary.lowercase()) {
            "breakfast" -> match("Breakfast") ?: match("Brunch") ?: primary
            "lunch" -> match("Lunch") ?: match("Brunch") ?: primary
            "dinner" -> match("Dinner") ?: match("Limited Dinner") ?: primary
            "afternoon snack" -> available.firstOrNull { isAfternoonSnack(it) } ?: primary
            "late night" ->
                match("Late Night")
                    ?: match("Evening Snack")
                    ?: match("Overnight")
                    ?: available.firstOrNull { isLateNight(it) }
                    ?: primary
            else -> match(primary) ?: primary
        }
    }

    fun mealPillLabel(pill: String, available: List<String>): String {
        if (canonicalPill(pill) == "Late Night") return "Late Night"
        if (!pillIsPosted(pill, available)) return pill
        val resolved = resolvePeriod(pill, available)
        return if (canonicalPill(resolved) == "Late Night") "Late Night" else resolved.ifBlank { pill }
    }

    fun isWeekend(dateISO: String): Boolean {
        val weekday = PacificTime.weekdayName(dateISO) ?: return false
        return weekday == "Saturday" || weekday == "Sunday"
    }

    fun visibleMealPills(available: List<String>, dateISO: String): List<String> =
        mealSelectorPills.filter { pill ->
            if (canonicalPill(pill) != "Late Night") true
            else !isWeekend(dateISO) && pillIsPosted(pill, available)
        }

    /// Each pill scrapes only that period. Lunch does not union Brunch:
    /// weekend Brunch is Breakfast plus All Day, so the union made both
    /// pills identical. Unposted Lunch stays empty instead of copying Brunch.
    fun menuPeriodNames(primary: String, available: List<String>): List<String> {
        fun match(needle: String) = available.firstOrNull { it.equals(needle, true) }
        if (canonicalPill(primary) == "Lunch") {
            val lunch = match("Lunch") ?: return emptyList()
            return if (lunch.contains("all day", true)) emptyList() else listOf(lunch)
        }
        val resolved = resolvePeriod(primary, available)
        if (resolved.contains("all day", true)) return emptyList()
        val name = match(resolved) ?: return emptyList()
        return listOf(name)
    }

    fun collapsedStationName(name: String): String =
        name.lowercase().replace(Regex("\\s+"), " ").trim()

    fun isTwistedRoot(stationName: String, stationID: String? = null): Boolean {
        if (stationID != null && stationID in twistedRootStationIDs) return true
        val lowered = collapsedStationName(stationName)
        return "twisted root" in lowered || "twistedroot" in lowered
    }

    fun isEmber(stationName: String, stationID: String? = null): Boolean {
        if (stationID != null && stationID in emberStationIDs) return true
        val lowered = collapsedStationName(stationName)
        return lowered == "ember" || lowered.startsWith("ember ")
    }

    fun isStandingBurger(stationName: String, stationID: String? = null): Boolean {
        if (stationID != null && stationID in standingBurgerStationIDs) return true
        if (isEmber(stationName, stationID)) return true
        val lowered = collapsedStationName(stationName)
        if (lowered.isEmpty()) return false
        if ("sizzle" in lowered) return true
        if ("burger" in lowered) return true
        return false
    }

    fun isDessertStation(stationName: String, stationID: String? = null): Boolean {
        if (stationID != null && stationID in dessertStationIDs) return true
        val lowered = collapsedStationName(stationName)
        if (lowered.isEmpty()) return false
        val needles = listOf(
            "honeycake", "bakery", "dessert", "sweets", "pastry",
            "ice cream", "icecream", "cookie", "pudding",
        )
        if (needles.any { it in lowered }) return true
        return lowered == "sweet" || lowered.startsWith("sweet ") || lowered.endsWith(" sweet")
    }

    fun isSidesStation(stationName: String): Boolean {
        val lowered = collapsedStationName(stationName)
        val needles = listOf(
            "soup", "salad", "deli", "farmer", "farm stand", "farmstand",
            "side", "vegetable", "veggie",
        )
        return needles.any { it in lowered }
    }

    fun isAvailableAllDayStation(stationName: String): Boolean {
        val lowered = collapsedStationName(stationName)
        return lowered == "available all day" || lowered == "all day"
    }

    fun dishLooksLikePizza(name: String): Boolean {
        val lowered = collapsedStationName(name)
        return "pizza" in lowered || "flatbread" in lowered
    }

    fun isPizzaStation(
        stationName: String,
        stationID: String? = null,
        items: List<MenuItem> = emptyList(),
    ): Boolean {
        if (isTwistedRoot(stationName, stationID)) return false
        if (isStandingBurger(stationName, stationID)) return false
        val lowered = collapsedStationName(stationName)
        if ("pizza" in lowered || "pizzeria" in lowered) return true
        val maybePizzaBoard =
            (stationID != null && stationID in pizzaStationIDs) ||
                lowered == "oven" ||
                lowered.startsWith("oven ") ||
                lowered.endsWith(" oven") ||
                " oven " in lowered ||
                lowered == "hearth" ||
                lowered.startsWith("hearth ") ||
                lowered.endsWith(" hearth")
        if (!maybePizzaBoard) return false
        return items.any { dishLooksLikePizza(it.name) }
    }

    fun stationLane(
        name: String,
        stationID: String? = null,
        items: List<MenuItem> = emptyList(),
    ): StationLane {
        if (isTwistedRoot(name, stationID)) return StationLane.TWISTED_ROOT
        if (isStandingBurger(name, stationID)) return StationLane.STANDING_BURGER
        if (isAvailableAllDayStation(name)) return StationLane.AVAILABLE_ALL_DAY
        if (isDessertStation(name, stationID)) return StationLane.DESSERT
        if (isPizzaStation(name, stationID, items)) return StationLane.PIZZA
        if (isSidesStation(name)) return StationLane.SIDES
        val lowered = collapsedStationName(name)
        if ("promotion" in lowered || lowered == "also served") return StationLane.OTHER
        return StationLane.HOT_ENTREE
    }

    fun displayStationName(mapped: String?, stationID: String): String {
        val trimmed = mapped?.trim().orEmpty()
        if (isTwistedRoot(trimmed, stationID)) {
            return if (isTwistedRoot(trimmed)) trimmed else "The Twisted Root"
        }
        return trimmed.ifEmpty { "Menu" }
    }

    fun applyStationTags(
        items: List<MenuItem>,
        station: String,
        stationID: String? = null,
    ): List<MenuItem> {
        if (!isTwistedRoot(station, stationID)) return items
        return items.map { item ->
            val tags = item.dietaryTags.toMutableList()
            if (tags.none { it.equals("Vegan", true) }) tags.add(0, "Vegan")
            if (tags.none { it.equals("Vegetarian", true) }) tags += "Vegetarian"
            if (tags == item.dietaryTags) item else item.copy(dietaryTags = tags)
        }
    }

    fun pinTwistedRootFirst(stations: List<MenuStation>): List<MenuStation> =
        stations.mapIndexed { index, station ->
            Triple(stationLane(station.name, station.stationID, station.items), index, station)
        }.sortedWith(compareBy({ it.first }, { it.second })).map { it.third }

    fun mergeKey(station: MenuStation): String? {
        val id = station.stationID?.trim().orEmpty()
        if (id.isNotEmpty()) return "id:$id"
        val name = station.name.trim().lowercase()
        return if (name.isEmpty()) null else "name:$name"
    }

    /// Hearted dishes served on this hall + meal + date board.
    /// Skips Available all day and breakfast-only Brunch copies (pancakes).
    fun favoriteItemsOnBoard(
        stations: List<MenuStation>,
        favoriteNames: Collection<String>,
        period: String? = null,
    ): List<MenuItem> {
        if (favoriteNames.isEmpty()) return emptyList()
        val wanted = favoriteNames.map { it.lowercase() }.toHashSet()
        val seen = mutableSetOf<String>()
        val result = mutableListOf<MenuItem>()
        for (station in stations) {
            if (isAvailableAllDayStation(station.name)) continue
            for (item in station.items) {
                val key = item.name.lowercase()
                if (key !in wanted || !seen.add(key)) continue
                if (isBreakfastOnlyFavorite(item.name, period)) continue
                result += item
            }
        }
        return result
    }

    fun isBreakfastStyleDishName(name: String): Boolean {
        val n = name.lowercase()
        val tokens = listOf(
            "scramble", "hash", "egg", "oatmeal", "sausage", "bacon",
            "pancake", "waffle", "breakfast", "yogurt", "muffin", "chia",
            "french toast",
        )
        return tokens.any { it in n }
    }

    fun isBreakfastOnlyFavorite(name: String, period: String?): Boolean {
        if (period.isNullOrBlank()) return false
        if (canonicalPill(period) == "Breakfast") return false
        return isBreakfastStyleDishName(name)
    }

    fun favoritesSectionTitle(dateISO: String, todayISO: String): String {
        if (dateISO == todayISO) return "Favorites today"
        val weekday = PacificTime.weekdayName(dateISO) ?: return "Favorites"
        return "Favorites on $weekday"
    }

    /// After Lunch unions Brunch, drop dishes that are only on Breakfast.
    fun subtractingBreakfastOnlyBrunchDishes(
        from: List<MenuStation>,
        lunch: List<MenuStation>,
        breakfast: List<MenuStation>,
    ): List<MenuStation> {
        val breakfastKeys = breakfast.flatMap { it.items }.map { it.name.lowercase() }.toHashSet()
        if (breakfastKeys.isEmpty()) return from
        val lunchKeys = lunch.flatMap { it.items }.map { it.name.lowercase() }.toHashSet()
        return from.mapNotNull { station ->
            if (isTwistedRoot(station.name, station.stationID)) return@mapNotNull station
            val kept = station.items.filter { item ->
                item.name.lowercase() in lunchKeys || item.name.lowercase() !in breakfastKeys
            }
            if (kept.isEmpty()) null else station.withItems(kept)
        }
    }

    fun mergeStations(groups: List<List<MenuStation>>): List<MenuStation> {
        val displayName = linkedMapOf<String, String>()
        val items = mutableMapOf<String, MutableList<MenuItem>>()
        val seen = mutableMapOf<String, MutableSet<String>>()
        val ids = mutableMapOf<String, String>()
        for (group in groups) {
            for (station in group) {
                val key = mergeKey(station) ?: continue
                if (key !in displayName) {
                    displayName[key] = station.name.trim()
                    items[key] = mutableListOf()
                    seen[key] = mutableSetOf()
                }
                val sid = station.stationID?.trim().orEmpty()
                if (key !in ids && sid.isNotEmpty()) ids[key] = sid
                for (item in station.items) {
                    if (seen.getValue(key).add(item.name.lowercase())) {
                        items.getValue(key) += item
                    }
                }
            }
        }
        return displayName.mapNotNull { (key, name) ->
            val list = items[key].orEmpty()
            if (list.isEmpty()) null else MenuStation(name = name, items = list, stationID = ids[key])
        }
    }

    fun twistedRootPills(
        available: List<String>,
        stationIDsByPeriod: Map<String, List<String>>,
        stationNames: Map<String, String>,
    ): List<String> = mealSelectorPills.filter { pill ->
        menuPeriodNames(pill, available).any { period ->
            val ids = stationIDsByPeriod.entries.firstOrNull { it.key.equals(period, true) }?.value.orEmpty()
            ids.any { id -> isTwistedRoot(stationNames[id].orEmpty(), id) }
        }
    }

    fun collapseWhitespace(text: String?): String? {
        if (text == null) return null
        val collapsed = text.replace(Regex("\\s+"), " ").trim()
        return collapsed.ifEmpty { null }
    }

    fun servingSize(size: String?, unit: String?): String? {
        if (size.isNullOrBlank()) return null
        if (unit.isNullOrBlank()) return size
        val combined = "$size $unit".trim()
        return if (combined.matches(Regex("^\\d+(\\.\\d+)?\\s*fl$"))) {
            combined.replace("fl", "fl oz")
        } else {
            combined
        }
    }

    fun chunks(ids: List<String>, size: Int): List<List<String>> {
        if (ids.isEmpty()) return emptyList()
        if (size <= 0) return listOf(ids)
        return ids.chunked(size)
    }

    fun clockPill(nowMinutes: Int): String = when {
        nowMinutes < 11 * 60 -> "Breakfast"
        nowMinutes < 14 * 60 + 30 -> "Lunch"
        else -> "Dinner"
    }

    fun autoPill(
        periods: List<MealPeriodWindow>,
        nowMinutes: Int,
        available: List<String> = emptyList(),
        dateISO: String = "2026-07-09",
    ): String {
        val timed = periods.filter { it.startMinutes != null && it.endMinutes != null }
        val live = timed.filter { nowMinutes >= it.startMinutes!! && nowMinutes < it.endMinutes!! }
        val postedSnack = available.any { isAfternoonSnack(it) } ||
            periods.any { isAfternoonSnack(it.name) }
        val postedLate = available.any { isLateNight(it) } ||
            periods.any { isLateNight(it.name) }
        val weekend = isWeekend(dateISO)
        if (!weekend && live.any { canonicalPill(it.name) == "Late Night" }) return "Late Night"
        if (live.any { canonicalPill(it.name) == "Afternoon Snack" }) return "Afternoon Snack"
        if (postedSnack && nowMinutes >= 14 * 60 + 30 && nowMinutes < 16 * 60 + 30) {
            return "Afternoon Snack"
        }
        if (live.any { canonicalPill(it.name) == "Dinner" }) return "Dinner"
        if (live.any { trueMeal(it.name, "lunch", "brunch") }) return "Lunch"
        if (live.any { trueMeal(it.name, "breakfast", "brunch") }) return "Breakfast"
        if (live.any { it.name.contains("brunch", true) }) {
            return postedClockPill(nowMinutes, available)
        }
        if (!weekend && postedLate && nowMinutes >= 20 * 60) return "Late Night"
        val upcoming = timed.filter { it.startMinutes!! > nowMinutes }.minByOrNull { it.startMinutes!! }
        if (upcoming != null) {
            val next = if (upcoming.name.contains("brunch", true)) {
                postedClockPill(nowMinutes, available)
            } else {
                canonicalPill(upcoming.name)
            }
            if (next == "Late Night" && weekend) return "Dinner"
            return next
        }
        return postedClockPill(nowMinutes, available)
    }

    fun postedClockPill(nowMinutes: Int, available: List<String>): String {
        val clock = clockPill(nowMinutes)
        if (available.isEmpty()) return clock
        if (pillIsPosted(clock, available)) return clock
        val hasRealBreakfast = available.any { it.equals("Breakfast", true) }
        val hasBrunch = available.any { it.contains("brunch", true) }
        if (clock == "Lunch" && hasBrunch && !hasRealBreakfast && pillIsPosted("Breakfast", available)) {
            return "Breakfast"
        }
        return clock
    }

    private fun trueMeal(name: String, named: String, excluding: String): Boolean {
        val lower = name.lowercase()
        return named in lower && excluding !in lower
    }

    fun eatHalls(
        locations: List<DiningLocation>,
        hubOasis: DiningLocation? = null,
    ): List<DiningLocation> {
        val anteatery = locations.firstOrNull { it.id.equals(HallDirectory.ANTEATERY, true) }
        val brandywine = locations.firstOrNull { it.id.equals(HallDirectory.BRANDYWINE, true) }
        val oasis = locations.firstOrNull { HallDirectory.isOasis(it.id) && it.availablePeriods.isNotEmpty() }
            ?: hubOasis?.takeIf { it.availablePeriods.isNotEmpty() }
            ?: OasisSchedule.comingSoonLocation()
        return listOfNotNull(anteatery, brandywine, oasis)
    }

    fun emptyMenuCopy(period: String, browsingFuture: Boolean, comingSoon: Boolean): String {
        if (comingSoon) return OasisSchedule.selectedLine()
        val meal = period.trim()
        return if (browsingFuture) {
            if (meal.isEmpty()) {
                "UCI has not posted a menu for this day yet. Pick another day above."
            } else {
                "No ${meal.lowercase()} posted for this day yet. Try another meal, or pick another day above."
            }
        } else if (meal.isEmpty()) {
            "This hall has not posted a menu yet. Check back soon."
        } else {
            "This hall has not published ${meal.lowercase()} yet. Check back soon."
        }
    }
}

package com.atharvgupta.anteats.data

object DiningLogic {
    val mealSelectorPills = listOf("Breakfast", "Lunch", "Afternoon Snack", "Dinner", "Late Night")
    val twistedRootStationIDs = setOf("1929", "1893")
    val emberStationIDs = setOf("1878")
    val standingBurgerStationIDs = setOf("1878", "1935")
    val dessertStationIDs = setOf("1872", "1938")
    val pizzaStationIDs = setOf("1941", "1884")
    val stationHallIDs = mapOf(
        "1926" to "anteatery",
        "1929" to "anteatery",
        "1932" to "anteatery",
        "1935" to "anteatery",
        "1938" to "anteatery",
        "1941" to "anteatery",
        "1944" to "anteatery",
        "1947" to "anteatery",
        "1950" to "anteatery",
        "1953" to "anteatery",
        "1872" to "brandywine",
        "1875" to "brandywine",
        "1878" to "brandywine",
        "1881" to "brandywine",
        "1884" to "brandywine",
        "1887" to "brandywine",
        "1890" to "brandywine",
        "1893" to "brandywine",
        "1896" to "brandywine",
        "1899" to "brandywine",
        "2166" to "brandywine",
        "275501" to "brandywine",
    )
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

    fun hallIDForStation(stationID: String): String? = stationHallIDs[stationID]

    fun stationBelongs(hallID: String, stationID: String?): Boolean {
        val owner = hallIDForStation(stationID ?: return true) ?: return true
        return owner.equals(hallID, ignoreCase = true)
    }

    fun assignedStationID(categoryIDs: List<String>, hallID: String? = null): String? {
        val ids = categoryIDs.flatMap { it.split(",") }.map { it.trim() }.filter { it.isNotEmpty() }
        val known = ids.filter { it in stationHallIDs }
        val scoped = if (hallID != null) {
            val matching = known.filter { stationBelongs(hallID, it) }
            matching.ifEmpty { known }
        } else {
            known
        }
        val pool = scoped.ifEmpty { ids }
        pool.lastOrNull { it in dessertStationIDs }?.let { return it }
        if (hallID != null) {
            pool.lastOrNull { it in twistedRootStationIDs && stationBelongs(hallID, it) }?.let { return it }
        } else {
            pool.lastOrNull { it in twistedRootStationIDs }?.let { return it }
        }
        return pool.lastOrNull { it.length >= 4 && it.all { ch -> ch.isDigit() } }
    }

    fun dietLookupKeys(name: String): List<String> {
        val lower = (collapseWhitespace(name) ?: name).lowercase().trim()
        val keys = mutableListOf(lower)
        var stripped = lower
        if (stripped.startsWith("ae ")) {
            stripped = stripped.drop(3).trim()
            keys += stripped
        }
        for (suffix in listOf(" sandwich", " burger", " wrap")) {
            if (stripped.endsWith(suffix)) {
                val base = stripped.dropLast(suffix.length).trim()
                if (base.isNotEmpty()) keys += base
            }
        }
        val withoutUCI = stripped.replace(Regex("""\s+uci$"""), "")
        if (withoutUCI != stripped) keys += withoutUCI
        for (variant in keys.toList()) {
            val normalized = variant.replace(Regex("[^a-z0-9]+"), "")
            if (normalized.isNotEmpty()) keys += normalized
        }
        val seen = mutableSetOf<String>()
        return keys.filter { seen.add(it) }
    }

    fun hubBoardNameKeys(items: List<MenuItem>): Set<String> =
        items.flatMap { dietLookupKeys(it.name) }.toSet()

    fun appearsOnHubBoard(item: MenuItem, keys: Set<String>): Boolean =
        dietLookupKeys(item.name).any { it in keys }

    fun hubMealFamily(period: String): String? {
        val lower = period.lowercase()
        if ("all day" in lower) return null
        if (isLateNight(lower)) return "late night"
        if (isAfternoonSnack(lower)) return "afternoon snack"
        if ("brunch" in lower) return "brunch"
        if ("lunch" in lower) return "lunch"
        if ("breakfast" in lower) return "breakfast"
        if ("dinner" in lower) return "dinner"
        return null
    }

    fun hubMealStations(period: String, hubStations: List<MenuStation>): List<MenuStation> {
        val lowerPeriod = period.lowercase()
        if ("brunch" in lowerPeriod) {
            return hubStations.filter { "brunch" in it.name.lowercase() }
        }
        val pill = canonicalPill(period)
        val hasBreakfast = hubStations.any {
            val name = it.name.lowercase()
            "breakfast" in name && "brunch" !in name
        }
        val hasLunch = hubStations.any {
            val name = it.name.lowercase()
            "lunch" in name && "brunch" !in name
        }
        return hubStations.filter { station ->
            val name = station.name.lowercase()
            when (pill) {
                "Lunch" -> hasLunch && "lunch" in name && "brunch" !in name
                "Breakfast" ->
                    if (hasBreakfast) "breakfast" in name && "brunch" !in name
                    else "brunch" in name
                "Dinner" -> "dinner" in name
                else -> name.equals(period, ignoreCase = true)
            }
        }
    }

    fun excludingBreakfastOnlyBrunchItems(
        items: List<MenuItem>,
        period: String,
        hubStations: List<MenuStation>,
    ): List<MenuItem> {
        if (canonicalPill(period) != "Lunch") return items
        val breakfast = hubStations
            .filter {
                val name = it.name.lowercase()
                "breakfast" in name && "brunch" !in name
            }
            .flatMap { it.items }
        val breakfastKeys = hubBoardNameKeys(breakfast)
        if (breakfastKeys.isEmpty()) return items
        val lunch = hubStations.filter { "lunch" in it.name.lowercase() }.flatMap { it.items }
        val lunchKeys = hubBoardNameKeys(lunch)
        return items.filter { item ->
            appearsOnHubBoard(item, lunchKeys) || !appearsOnHubBoard(item, breakfastKeys)
        }
    }

    fun hubBoardItems(period: String, hubStations: List<MenuStation>): List<MenuItem> {
        val matching = hubMealStations(period, hubStations).flatMap { it.items }
        return excludingBreakfastOnlyBrunchItems(matching, period, hubStations)
    }

    fun appearsOnOtherHubMealFamily(
        item: MenuItem,
        period: String,
        hubStations: List<MenuStation>,
    ): Boolean {
        val live = hubMealFamily(period) ?: return false
        val other = hubStations
            .filter { station ->
                val family = hubMealFamily(station.name) ?: return@filter false
                family != live
            }
            .flatMap { it.items }
        return appearsOnHubBoard(item, hubBoardNameKeys(other))
    }

    fun hubMealHasStationTags(hallID: String, board: List<MenuItem>): Boolean =
        board.any { item ->
            val sid = item.stationID?.trim().orEmpty()
            sid.isNotEmpty() && stationBelongs(hallID, sid)
        }

    fun canMergeHubExtra(station: MenuStation, extraStationID: String): Boolean {
        val extraID = extraStationID.trim()
        if (extraID.isEmpty()) return false
        val existingID = station.stationID?.trim().orEmpty()
        if (existingID.isNotEmpty() && existingID == extraID) return true
        val stationTwisted = isTwistedRoot(station.name, station.stationID)
        val extraTwisted = isTwistedRoot("", extraID)
        if (!stationTwisted || !extraTwisted) return false
        if (existingID.isEmpty()) return true
        return existingID == extraID
    }

    fun hubItems(station: MenuStation, hallID: String, board: List<MenuItem>): List<MenuItem> =
        board.filter { item ->
            val sid = item.stationID?.trim().orEmpty()
            sid.isNotEmpty() &&
                stationBelongs(hallID, sid) &&
                canMergeHubExtra(station, sid)
        }

    fun droppingOffBoardAnteaterItems(menu: DiningMenu, hubStations: List<MenuStation>): DiningMenu {
        val board = hubBoardItems(menu.period, hubStations)
        if (board.isEmpty()) return menu
        val hubTagged = hubMealHasStationTags(menu.locationId, board)
        val stations = menu.stations.mapNotNull { station ->
            if (isAvailableAllDayStation(station.name)) return@mapNotNull station
            val hubForStation = hubItems(station, menu.locationId, board)
            val isTwisted = isTwistedRoot(station.name, station.stationID)
            if (isTwisted && hubTagged) {
                val lunchPill = canonicalPill(menu.period) == "Lunch"
                if (hubForStation.isEmpty()) return@mapNotNull if (lunchPill) station else null
                if (lunchPill) {
                    val allDayKeys = hubBoardNameKeys(
                        hubStations.filter { "all day" in it.name.lowercase() }.flatMap { it.items },
                    )
                    if (hubForStation.all { appearsOnHubBoard(it, allDayKeys) }) return@mapNotNull station
                }
                val keys = hubBoardNameKeys(hubForStation)
                val kept = station.items.filter { appearsOnHubBoard(it, keys) }
                if (canonicalPill(menu.period) == "Breakfast") {
                    val middayKeys = middayTwistedRootKeys(hubStations)
                    val breakfastKept = kept.filter { shouldKeepTwistedRootOnBreakfast(it, middayKeys) }
                    return@mapNotNull if (breakfastKept.isEmpty()) null else station.withItems(breakfastKept)
                }
                return@mapNotNull if (kept.isEmpty()) null else station.withItems(kept)
            }
            if (hubForStation.isEmpty()) return@mapNotNull station
            val keys = hubBoardNameKeys(hubForStation)
            val kept = station.items.filter { appearsOnHubBoard(it, keys) }
            if (kept.isEmpty()) null else station.withItems(kept)
        }
        return menu.copy(stations = stations)
    }

    fun hubExclusiveItems(menu: DiningMenu, hubStations: List<MenuStation>): List<MenuItem> {
        val matching = excludingBreakfastOnlyBrunchItems(
            hubMealStations(menu.period, hubStations).flatMap { it.items },
            menu.period,
            hubStations,
        )
        val allDayItems = hubStations.filter { "all day" in it.name.lowercase() }.flatMap { it.items }
        val allDayKeys = hubBoardNameKeys(allDayItems)
        val seen = menu.stations.flatMap { it.items }.flatMap { dietLookupKeys(it.name) }.toMutableSet()
        val extras = mutableListOf<MenuItem>()
        fun consider(item: MenuItem) {
            val keys = dietLookupKeys(item.name)
            if (keys.any { it in seen }) return
            if (!stationBelongs(menu.locationId, item.stationID)) return
            val twisted = isTwistedRoot("", item.stationID)
            val onAllDay = appearsOnHubBoard(item, allDayKeys)
            val onOtherMeal = appearsOnOtherHubMealFamily(item, menu.period, hubStations)
            if (onAllDay && onOtherMeal) return
            if (twisted && canonicalPill(menu.period) == "Breakfast") {
                val middayKeys = middayTwistedRootKeys(hubStations)
                if (!shouldKeepTwistedRootOnBreakfast(item, middayKeys)) return
            }
            if (!twisted && onAllDay) return
            if (!twisted && onOtherMeal) return
            seen += keys
            extras += item
        }
        matching.forEach { consider(it) }
        return extras
    }

    fun insertingHubExtras(
        extras: List<MenuItem>,
        menu: DiningMenu,
        stationNames: Map<String, String> = emptyMap(),
    ): DiningMenu {
        if (extras.isEmpty()) {
            val pinned = pinTwistedRootFirst(menu.stations)
            return if (pinned == menu.stations) menu else menu.copy(stations = pinned)
        }
        val stations = menu.stations.toMutableList()
        val leftover = mutableListOf<MenuItem>()

        fun merge(index: Int, items: List<MenuItem>, stationID: String?) {
            val station = stations[index]
            val seen = station.items.map { it.name.lowercase() }.toMutableSet()
            val next = station.items.toMutableList()
            val tagged = applyStationTags(items, station.name, station.stationID ?: stationID)
            for (item in tagged) {
                if (seen.add(item.name.lowercase())) next += item
            }
            stations[index] = station.withItems(next)
        }

        fun insertBeforeAllDay(station: MenuStation) {
            val idx = stations.indexOfFirst { isAvailableAllDayStation(it.name) }
            if (idx >= 0) stations.add(idx, station) else stations += station
        }

        for (item in extras) {
            val sid = item.stationID?.trim().orEmpty()
            if (sid.isEmpty()) {
                leftover += item
                continue
            }
            if (!stationBelongs(menu.locationId, sid)) continue
            val mergeIdx = stations.indexOfFirst { canMergeHubExtra(it, sid) }
            if (mergeIdx >= 0) {
                merge(mergeIdx, listOf(item), sid)
                continue
            }
            val name = displayStationName(stationNames[sid], sid)
            val namedIdx = stations.indexOfFirst {
                it.name.equals(name, ignoreCase = true) && canMergeHubExtra(it, sid)
            }
            if (namedIdx >= 0) {
                merge(namedIdx, listOf(item), sid)
                continue
            }
            insertBeforeAllDay(
                MenuStation(name, applyStationTags(listOf(item), name, sid), sid),
            )
        }
        if (leftover.isNotEmpty()) {
            insertBeforeAllDay(MenuStation("Also served", leftover))
        }
        return menu.copy(stations = pinTwistedRootFirst(stations))
    }

    fun middayTwistedRootKeysFromGroups(groups: List<List<MenuStation>>): Set<String> {
        val items = groups.flatMap { group ->
            group.filter { isTwistedRoot(it.name, it.stationID) }.flatMap { it.items }
        } + groups.flatMap { group ->
            group.flatMap { it.items }.filter { isTwistedRoot("", it.stationID) }
        }
        return hubBoardNameKeys(items)
    }

    fun middayTwistedRootKeys(hubStations: List<MenuStation>): Set<String> {
        val midday = hubStations.filter { station ->
            val name = station.name.lowercase()
            "brunch" in name || ("lunch" in name && "brunch" !in name)
        }
        return middayTwistedRootKeysFromGroups(listOf(midday))
    }

    fun shouldKeepTwistedRootOnBreakfast(item: MenuItem, middayKeys: Set<String>): Boolean {
        if (isBreakfastStyleDishName(item.name)) return true
        return !appearsOnHubBoard(item, middayKeys)
    }

    fun subtractingMiddayTwistedRootFromBreakfast(
        from: List<MenuStation>,
        midday: List<MenuStation>,
    ): List<MenuStation> {
        val middayKeys = middayTwistedRootKeysFromGroups(listOf(midday))
        if (middayKeys.isEmpty()) return from
        return from.mapNotNull { station ->
            if (!isTwistedRoot(station.name, station.stationID)) return@mapNotNull station
            val kept = station.items.filter { shouldKeepTwistedRootOnBreakfast(it, middayKeys) }
            if (kept.isEmpty()) null else station.withItems(kept)
        }
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

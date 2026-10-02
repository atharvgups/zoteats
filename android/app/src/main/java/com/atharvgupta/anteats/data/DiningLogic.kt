package com.atharvgupta.anteats.data

object DiningLogic {
    val mealSelectorPills = listOf("Breakfast", "Lunch", "Dinner")
    val twistedRootStationIDs = setOf("1929", "1893")
    val dishBatchChunkSizes = listOf(40, 8, 1)

    fun canonicalPill(liveName: String): String {
        val lower = liveName.trim().lowercase()
        if ("brunch" in lower || "breakfast" in lower) return "Breakfast"
        if ("lunch" in lower) return "Lunch"
        if ("dinner" in lower) return "Dinner"
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
        if (available.any { it.equals("Dinner", true) || it.equals("Limited Dinner", true) }) {
            result += "Dinner"
        }
        return result
    }

    fun resolvePeriod(primary: String, available: List<String>): String {
        fun match(name: String) = available.firstOrNull { it.equals(name, true) }
        return when (primary.lowercase()) {
            "breakfast" -> match("Breakfast") ?: match("Brunch") ?: primary
            "lunch" -> match("Lunch") ?: match("Brunch") ?: primary
            "dinner" -> match("Dinner") ?: match("Limited Dinner") ?: primary
            else -> match(primary) ?: primary
        }
    }

    fun menuPeriodNames(primary: String, available: List<String>): List<String> {
        val resolved = resolvePeriod(primary, available)
        val names = mutableListOf<String>()
        fun add(needle: String) {
            val match = available.firstOrNull { it.equals(needle, true) } ?: return
            if (names.none { it.equals(match, true) }) names += match
        }
        add(resolved)
        if (canonicalPill(primary) == "Lunch") {
            add("Lunch")
            add("Brunch")
        }
        return names.filter { !it.contains("all day", ignoreCase = true) }
    }

    fun isTwistedRoot(stationName: String, stationID: String? = null): Boolean {
        if (stationID != null && stationID in twistedRootStationIDs) return true
        val lowered = stationName.lowercase().replace(Regex("\\s+"), " ").trim()
        return "twisted root" in lowered || "twistedroot" in lowered
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

    fun pinTwistedRootFirst(stations: List<MenuStation>): List<MenuStation> {
        val twisted = stations.filter { isTwistedRoot(it.name, it.stationID) }
        val rest = stations.filter { !isTwistedRoot(it.name, it.stationID) }
        return twisted + rest
    }

    fun mergeKey(station: MenuStation): String? {
        val id = station.stationID?.trim().orEmpty()
        if (id.isNotEmpty()) return "id:$id"
        val name = station.name.trim().lowercase()
        return if (name.isEmpty()) null else "name:$name"
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

    fun autoPill(periods: List<MealPeriodWindow>, nowMinutes: Int): String {
        val timed = periods.filter { it.startMinutes != null && it.endMinutes != null }
        val live = timed.filter { nowMinutes >= it.startMinutes!! && nowMinutes < it.endMinutes!! }
        if (live.any { canonicalPill(it.name) == "Dinner" }) return "Dinner"
        if (live.any { trueMeal(it.name, "lunch", "brunch") }) return "Lunch"
        if (live.any { trueMeal(it.name, "breakfast", "brunch") }) return "Breakfast"
        if (live.any { it.name.contains("brunch", true) }) return clockPill(nowMinutes)
        val upcoming = timed.filter { it.startMinutes!! > nowMinutes }.minByOrNull { it.startMinutes!! }
        if (upcoming != null) {
            return if (upcoming.name.contains("brunch", true)) clockPill(nowMinutes) else canonicalPill(upcoming.name)
        }
        return clockPill(nowMinutes)
    }

    private fun trueMeal(name: String, named: String, excluding: String): Boolean {
        val lower = name.lowercase()
        return named in lower && excluding !in lower
    }

    fun eatHalls(locations: List<DiningLocation>): List<DiningLocation> {
        val anteatery = locations.firstOrNull { it.id.equals(HallDirectory.ANTEATERY, true) }
        val brandywine = locations.firstOrNull { it.id.equals(HallDirectory.BRANDYWINE, true) }
        val oasis = locations.firstOrNull { HallDirectory.isOasis(it.id) }
            ?: OasisSchedule.comingSoonLocation()
        return listOfNotNull(anteatery, brandywine, oasis)
    }

    fun emptyMenuCopy(period: String, browsingFuture: Boolean, comingSoon: Boolean): String {
        if (comingSoon) return "${OasisSchedule.opensLine()} · Lunch & Dinner"
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

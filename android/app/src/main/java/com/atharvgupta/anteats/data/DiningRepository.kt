package com.atharvgupta.anteats.data

import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.async
import kotlinx.coroutines.awaitAll
import kotlinx.coroutines.coroutineScope
import kotlinx.coroutines.withContext
import kotlinx.serialization.json.Json
import kotlinx.serialization.json.JsonArray
import kotlinx.serialization.json.JsonElement
import kotlinx.serialization.json.JsonObject
import kotlinx.serialization.json.JsonPrimitive
import kotlinx.serialization.json.contentOrNull
import kotlinx.serialization.json.doubleOrNull
import kotlinx.serialization.json.jsonArray
import kotlinx.serialization.json.jsonObject
import kotlinx.serialization.json.jsonPrimitive
import java.net.HttpURLConnection
import java.net.URL
import java.net.URLEncoder
import java.nio.charset.StandardCharsets

class DiningRepository(
    private val base: String = "https://anteaterapi.com/v2/rest/dining",
    private val hubStations: suspend (locationUrlKey: String, dateISO: String) -> List<MenuStation> =
        { key, date -> runCatching { CampusRepository().postedMenu(key, date) }.getOrDefault(emptyList()) },
    private val menuOverrides: suspend () -> MenuOverridePayload =
        { runCatching { MenuOverrideFeed.fetch() }.getOrDefault(MenuOverrideFeed.bundled) },
    private val get: suspend (String) -> Pair<Int, String> = { path -> httpGet(base + path) },
) {
    private val json = Json { ignoreUnknownKeys = true }

    suspend fun publishedDateRange(): PublishedDateRange? = runCatching {
        val data = envelopeObject(get("/dateRange").second)
        PublishedDateRange(
            earliest = data.string("earliest") ?: return@runCatching null,
            latest = data.string("latest") ?: return@runCatching null,
        )
    }.getOrNull()

    suspend fun locations(): List<DiningLocation> {
        val dateISO = PacificTime.todayISO()
        val nowMinutes = PacificTime.nowMinutes()
        val restaurants = runCatching { restaurants() }.getOrNull().orEmpty()
        val hallIds = restaurants.map { it.first }.ifEmpty { HallDirectory.fallbackIds }
        val halls = coroutineScope {
            hallIds.map { id ->
                async { location(id, dateISO, nowMinutes) }
            }.awaitAll()
        }
        val ordered = hallIds.mapNotNull { id -> halls.firstOrNull { it.id == id } }
        val hubOasis = if (ordered.none { HallDirectory.isOasis(it.id) && it.availablePeriods.isNotEmpty() }) {
            oasisFromHub(dateISO)
        } else {
            null
        }
        return DiningLogic.eatHalls(ordered, hubOasis)
    }

    suspend fun menu(hall: String, period: String, dateISO: String): DiningMenu {
        if (HallDirectory.isOasis(hall)) {
            val listed = runCatching { restaurants() }.getOrNull().orEmpty()
                .any { HallDirectory.isOasis(it.first) }
            if (!listed) {
                val hub = oasisHubMenu(period, dateISO)
                return applyOverrides(hub ?: DiningMenu(hall, dateISO, period, emptyList()))
            }
        }
        val today = restaurantToday(hall, dateISO)
        val available = today.values.map { it.name }
        if (available.isEmpty()) {
            return applyOverrides(DiningMenu(hall, dateISO, period, emptyList()))
        }
        val resolved = DiningLogic.resolvePeriod(period, available)
        val periodNames = DiningLogic.menuPeriodNames(period, available)
        if (periodNames.isEmpty()) {
            return applyOverrides(DiningMenu(hall, dateISO, period, emptyList()))
        }
        val stationNames = stationMap()
        val scraped = linkedMapOf<String, List<MenuStation>>()
        var mealStations = emptyList<MenuStation>()
        for (name in periodNames) {
            val more = stationsFor(name, today, stationNames)
            scraped[name] = more
            mealStations = DiningLogic.mergeStations(listOf(mealStations, more))
        }
        if (DiningLogic.canonicalPill(period) == "Lunch") {
            val breakfastName = available.firstOrNull { it.equals("Breakfast", true) }
            if (breakfastName != null) {
                val breakfastStations = stationsFor(breakfastName, today, stationNames)
                val lunchStations = scraped.entries
                    .firstOrNull { it.key.equals("Lunch", true) }
                    ?.value
                    .orEmpty()
                mealStations = DiningLogic.subtractingBreakfastOnlyBrunchDishes(
                    from = mealStations,
                    lunch = lunchStations,
                    breakfast = breakfastStations,
                )
            }
        }
        val periodMatched = periodNames.any { name -> available.any { it.equals(name, true) } }
        val brunchIsTimed = today.values.any { period ->
            period.name.contains("brunch", true) &&
                !period.startTime.isNullOrBlank() &&
                !period.endTime.isNullOrBlank()
        }
        val skipAllDayOnBreakfast = brunchIsTimed && DiningLogic.canonicalPill(period) == "Breakfast"
        val allDayName = available.firstOrNull { it.contains("all day", true) }
        if (periodMatched &&
            !skipAllDayOnBreakfast &&
            !resolved.contains("all day", true) &&
            allDayName != null
        ) {
            val allDay = stationsFor(allDayName, today, stationNames)
            val unique = linkedMapOf<String, MenuItem>()
            for (item in allDay.flatMap { it.items }) {
                unique.putIfAbsent(item.name.lowercase(), item)
            }
            if (unique.isNotEmpty()) {
                mealStations = mealStations + MenuStation("Available all day", unique.values.toList())
            }
        }
        mealStations = DiningLogic.pinTwistedRootFirst(mealStations)
        var menu = DiningMenu(
            locationId = hall,
            date = dateISO,
            period = resolved,
            stations = mealStations,
            twistedRootMeals = DiningLogic.twistedRootPills(
                available = available,
                stationIDsByPeriod = today.values.associate { it.name to it.stationToDishes.keys.toList() },
                stationNames = stationNames,
            ),
        )
        val hubKey = HallDirectory.campusHubKey(hall)
        val hub = if (hubKey != null) {
            runCatching { hubStations(hubKey, dateISO) }.getOrDefault(emptyList())
        } else {
            emptyList()
        }
        if (hub.isNotEmpty()) {
            val onBoard = DiningLogic.droppingOffBoardAnteaterItems(menu, hub)
            val extras = DiningLogic.hubExclusiveItems(onBoard, hub)
            menu = DiningLogic.insertingHubExtras(extras, onBoard, stationNames)
            if (DiningLogic.canonicalPill(menu.period) == "Breakfast") {
                val midday = DiningLogic.hubMealStations("Lunch", hub)
                val trimmed = DiningLogic.subtractingMiddayTwistedRootFromBreakfast(menu.stations, midday)
                if (trimmed != menu.stations) {
                    menu = menu.copy(stations = DiningLogic.pinTwistedRootFirst(trimmed))
                }
            }
        }
        val period = today.values.firstOrNull { it.name.equals(resolved, true) }
        return applyOverrides(
            menu,
            periodStartMinutes = PacificTime.parseMinutes(period?.startTime),
            periodEndMinutes = PacificTime.parseMinutes(period?.endTime),
        )
    }

    private suspend fun applyOverrides(
        menu: DiningMenu,
        periodStartMinutes: Int? = null,
        periodEndMinutes: Int? = null,
    ): DiningMenu {
        val feed = runCatching { menuOverrides() }.getOrDefault(MenuOverrideFeed.bundled)
        val events = runCatching { events() }.getOrDefault(emptyList())
        val withEvents = DiningLogic.attachingEvents(
            events,
            menu,
            periodStartMinutes,
            periodEndMinutes,
        )
        return DiningLogic.droppingEmptyStations(MenuOverrideFeed.applying(feed, withEvents))
    }

    private suspend fun events(): List<DiningEvent> {
        val rows = envelopeArray(get("/events").second)
        return rows.mapNotNull { el ->
            val obj = el as? JsonObject ?: return@mapNotNull null
            val title = obj.string("title")?.trim().orEmpty()
            val hall = obj.string("restaurantId")?.trim().orEmpty()
            if (title.isEmpty() || hall.isEmpty()) return@mapNotNull null
            DiningEvent(
                title = title,
                restaurantId = hall,
                start = DiningLogic.parseEventInstant(obj.string("start")),
                end = DiningLogic.parseEventInstant(obj.string("end")),
            )
        }
    }

    private suspend fun location(
        hall: String,
        dateISO: String,
        nowMinutes: Int,
    ): DiningLocation {
        val today = runCatching { restaurantToday(hall, dateISO) }.getOrDefault(emptyMap())
        val periods = today.values
            .filter { it.stationToDishes.isNotEmpty() }
            .sortedWith(compareBy({ DiningLogic.periodRank(it.name, PacificTime.parseMinutes(it.startTime)).first },
                { DiningLogic.periodRank(it.name, PacificTime.parseMinutes(it.startTime)).second },
                { it.name }))
        val windows = periods.map {
            MealPeriodWindow(it.name, PacificTime.parseMinutes(it.startTime), PacificTime.parseMinutes(it.endTime))
        }
        val starts = windows.mapNotNull { it.startMinutes }
        val ends = windows.mapNotNull { it.endMinutes }
        val openNow = windows.any { w ->
            val start = w.startMinutes ?: return@any false
            val end = w.endMinutes ?: return@any false
            nowMinutes >= start && nowMinutes < end
        }
        val hours = if (starts.isNotEmpty() && ends.isNotEmpty()) {
            "${PacificTime.formatMinutes(starts.min())} to ${PacificTime.formatMinutes(ends.max())}"
        } else {
            null
        }
        return DiningLocation(
            id = hall,
            name = HallDirectory.displayName(hall),
            compactName = HallDirectory.compactName(hall),
            area = HallDirectory.area(hall),
            openNow = openNow,
            todayHours = hours,
            availablePeriods = periods.map { it.name },
            periods = windows,
        )
    }

    private suspend fun restaurants(): List<Pair<String, List<Pair<String, String>>>> {
        val data = envelopeArray(get("/restaurants").second)
        return data.map { el ->
            val obj = el.jsonObject
            val id = obj.string("id") ?: return@map null
            val stations = obj["stations"]?.jsonArray.orEmpty().mapNotNull { station ->
                val s = station.jsonObject
                val sid = s.string("id") ?: return@mapNotNull null
                val name = s.string("name") ?: "Menu"
                sid to name
            }
            id to stations
        }.filterNotNull()
    }

    private suspend fun stationMap(): Map<String, String> =
        runCatching { restaurants().flatMap { it.second }.toMap() }.getOrDefault(emptyMap())

    private suspend fun restaurantToday(hall: String, dateISO: String): Map<String, ApiPeriod> {
        val (code, body) = get("/restaurantToday?id=$hall&date=$dateISO")
        if (code == 404) return emptyMap()
        val data = envelopeObject(body)
        val periods = data["periods"]?.jsonObject ?: return emptyMap()
        return periods.mapValues { (_, value) ->
            val obj = value.jsonObject
            val stationToDishes = linkedMapOf<String, List<String>>()
            obj["stationToDishes"]?.jsonObject?.forEach { (stationId, ids) ->
                stationToDishes[stationId] = ids.jsonArray.mapNotNull { it.jsonPrimitive.contentOrNull }
            }
            ApiPeriod(
                name = obj.string("name") ?: "",
                startTime = obj.string("startTime"),
                endTime = obj.string("endTime"),
                stationToDishes = stationToDishes,
            )
        }
    }

    private suspend fun stationsFor(
        period: String,
        today: Map<String, ApiPeriod>,
        stationNames: Map<String, String>,
    ): List<MenuStation> {
        val match = today.values.firstOrNull { it.name.equals(period, true) } ?: return emptyList()
        val dishMap = dishes(match.stationToDishes.values.flatten())
        return match.stationToDishes.entries.sortedBy { it.key }.mapNotNull { (stationID, dishIDs) ->
            val stationName = DiningLogic.displayStationName(stationNames[stationID], stationID)
            val seen = mutableSetOf<String>()
            val items = dishIDs.mapNotNull { dishMap[it] }
                .filter { seen.add(it.name.lowercase()) }
            if (items.isEmpty()) null
            else MenuStation(
                name = stationName,
                items = DiningLogic.applyStationTags(items, stationName, stationID),
                stationID = stationID,
            )
        }
    }

    private suspend fun dishes(ids: List<String>): Map<String, MenuItem> {
        val unique = ids.distinct().sorted()
        if (unique.isEmpty()) return emptyMap()
        val result = mutableMapOf<String, MenuItem>()
        var pending = unique
        for (size in DiningLogic.dishBatchChunkSizes) {
            if (pending.isEmpty()) break
            val stillMissing = mutableListOf<String>()
            for (chunk in DiningLogic.chunks(pending, size)) {
                val fetched = fetchDishChunk(chunk)
                for (id in chunk) {
                    val dish = fetched[id]
                    if (dish != null) result[id] = dish else stillMissing += id
                }
            }
            pending = stillMissing
            if (size == 1) break
        }
        return result
    }

    private suspend fun fetchDishChunk(ids: List<String>): Map<String, MenuItem> {
        if (ids.isEmpty()) return emptyMap()
        val joined = ids.sorted().joinToString(",")
        val encoded = URLEncoder.encode(joined, StandardCharsets.UTF_8)
        val data = envelopeArray(get("/dishes/batch?ids=$encoded").second)
        return data.mapNotNull { parseDish(it.jsonObject) }.associateBy { it.id }
    }

    private fun parseDish(obj: JsonObject): MenuItem? {
        val id = obj.string("id") ?: return null
        val name = DiningLogic.collapseWhitespace(obj.string("name")) ?: obj.string("name") ?: return null
        val diet = obj["dietRestriction"]?.jsonObject
        val nutrition = obj["nutritionInfo"]?.jsonObject
        val ingredients = DiningLogic.collapseWhitespace(obj.string("ingredients"))
        val facts = nutrition?.let {
            NutritionFacts(
                proteinG = it.flexDouble("proteinG"),
                totalCarbsG = it.flexDouble("totalCarbsG"),
                totalFatG = it.flexDouble("totalFatG"),
                saturatedFatG = it.flexDouble("saturatedFatG"),
                transFatG = it.flexDouble("transFatG"),
                sodiumMg = it.flexDouble("sodiumMg"),
                sugarsG = it.flexDouble("sugarsG"),
                dietaryFiberG = it.flexDouble("dietaryFiberG"),
                ingredients = ingredients,
            )
        }
        return MenuItem(
            id = id,
            name = name,
            description = DiningLogic.collapseWhitespace(obj.string("description")),
            calories = nutrition?.flexDouble("calories")?.let { Math.round(it).toInt() },
            servingSize = DiningLogic.servingSize(
                nutrition?.string("servingSize"),
                nutrition?.string("servingUnit"),
            ),
            allergens = dietAllergens(diet),
            dietaryTags = dietTags(diet),
            nutrition = facts,
            stationID = obj.string("stationId"),
        )
    }

    private fun dietAllergens(diet: JsonObject?): List<String> {
        if (diet == null) return emptyList()
        val flags = listOf(
            "containsEggs" to "Eggs",
            "containsFish" to "Fish",
            "containsMilk" to "Milk",
            "containsPeanuts" to "Peanuts",
            "containsSesame" to "Sesame",
            "containsShellfish" to "Shellfish",
            "containsSoy" to "Soy",
            "containsTreeNuts" to "Tree Nuts",
            "containsWheat" to "Wheat",
        )
        return flags.filter { diet.bool(it.first) }.map { it.second }
    }

    private fun dietTags(diet: JsonObject?): List<String> {
        if (diet == null) return emptyList()
        val tags = mutableListOf<String>()
        val flags = listOf(
            "isVegan" to "Vegan",
            "isVegetarian" to "Vegetarian",
            "isHalal" to "Halal",
            "isKosher" to "Kosher",
            "isGlutenFree" to "Gluten-Free",
            "isOrganic" to "Organic",
            "isLocallyGrown" to "Locally Grown",
        )
        for ((key, label) in flags) if (diet.bool(key)) tags += label
        if (tags.any { it == "Vegan" } && tags.none { it == "Vegetarian" }) tags += "Vegetarian"
        return tags
    }

    private fun envelopeObject(body: String): JsonObject {
        val root = json.parseToJsonElement(body).jsonObject
        if (root["ok"]?.jsonPrimitive?.contentOrNull == "false") {
            error("Anteater API said not ok")
        }
        return root["data"]?.jsonObject ?: JsonObject(emptyMap())
    }

    private fun envelopeArray(body: String): JsonArray {
        val root = json.parseToJsonElement(body).jsonObject
        if (root["ok"]?.jsonPrimitive?.contentOrNull == "false") {
            error("Anteater API said not ok")
        }
        return root["data"]?.jsonArray ?: JsonArray(emptyList())
    }

    private suspend fun oasisFromHub(dateISO: String): DiningLocation? {
        val recipes = oasisHubStations(dateISO)
        if (recipes.isEmpty()) return null
        return OasisSchedule.locationFromHubRecipes(recipes, dateISO)
    }

    private suspend fun oasisHubMenu(period: String, dateISO: String): DiningMenu? {
        val stations = oasisHubStations(dateISO)
        if (stations.isEmpty()) return null
        val available = stations.map { it.name }
        val resolved = DiningLogic.resolvePeriod(period, available)
        val names = DiningLogic.menuPeriodNames(period, available)
        if (names.isEmpty()) {
            return DiningMenu(HallDirectory.OASIS, dateISO, period, emptyList())
        }
        val matched = names.mapNotNull { name ->
            stations.firstOrNull { it.name.equals(name, true) }
        }
        val board = if (matched.isEmpty()) stations else matched
        return DiningMenu(
            HallDirectory.OASIS,
            dateISO,
            resolved,
            DiningLogic.pinTwistedRootFirst(board),
        )
    }

    private suspend fun oasisHubStations(dateISO: String): List<MenuStation> =
        runCatching { hubStations("the-oasis-dining-hall", dateISO) }.getOrNull().orEmpty()

    private data class ApiPeriod(
        val name: String,
        val startTime: String?,
        val endTime: String?,
        val stationToDishes: Map<String, List<String>>,
    )

    companion object {
        private suspend fun httpGet(urlString: String): Pair<Int, String> = withContext(Dispatchers.IO) {
            val url = URL(urlString)
            val conn = (url.openConnection() as HttpURLConnection).apply {
                connectTimeout = 15_000
                readTimeout = 20_000
                requestMethod = "GET"
                setRequestProperty("Accept", "application/json")
                setRequestProperty("User-Agent", "Anteats/1.0 (UCI student utility)")
            }
            try {
                val code = conn.responseCode
                val stream = if (code in 200..299) conn.inputStream else conn.errorStream
                val body = stream?.bufferedReader(StandardCharsets.UTF_8)?.use { it.readText() }.orEmpty()
                code to body
            } finally {
                conn.disconnect()
            }
        }
    }
}

private fun JsonObject.string(key: String): String? =
    this[key]?.jsonPrimitive?.contentOrNull

private fun JsonObject.bool(key: String): Boolean =
    this[key]?.jsonPrimitive?.contentOrNull == "true"

private fun JsonObject.flexDouble(key: String): Double? {
    val el: JsonElement = this[key] ?: return null
    val prim = el as? JsonPrimitive ?: return null
    return prim.doubleOrNull ?: prim.contentOrNull?.toDoubleOrNull()
}

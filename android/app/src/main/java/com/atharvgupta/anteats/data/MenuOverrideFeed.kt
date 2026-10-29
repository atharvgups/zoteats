package com.atharvgupta.anteats.data

import kotlinx.serialization.json.Json
import kotlinx.serialization.json.JsonArray
import kotlinx.serialization.json.JsonObject
import kotlinx.serialization.json.contentOrNull
import kotlinx.serialization.json.intOrNull
import kotlinx.serialization.json.jsonArray
import kotlinx.serialization.json.jsonObject
import kotlinx.serialization.json.jsonPrimitive
import java.net.HttpURLConnection
import java.net.URL
import java.nio.charset.StandardCharsets

data class MenuOverrideItem(
    val id: String,
    val name: String,
    val description: String? = null,
    val calories: Int? = null,
    val dietaryTags: List<String> = emptyList(),
    val allergens: List<String> = emptyList(),
)

data class MenuOverride(
    val date: String,
    val hall: String,
    val period: String,
    val stationID: String,
    val stationName: String,
    val kind: String? = null,
    val verified: Boolean = true,
    val note: String? = null,
    val items: List<MenuOverrideItem>,
) {
    val isSpecial: Boolean
        get() {
            val kind = kind?.trim()?.lowercase().orEmpty()
            if (kind == "special" || kind == "event" || kind == "takeover") return true
            return DiningLogic.isSpecialEventStation(stationName)
        }
}

data class MenuCorrection(
    val date: String,
    val hall: String,
    val period: String,
    val matchName: String,
    val stationID: String? = null,
    val stationName: String? = null,
    val verified: Boolean = true,
    val note: String? = null,
    val removeDietaryTags: List<String> = emptyList(),
    val addAllergens: List<String> = emptyList(),
    val description: String? = null,
    val calories: Int? = null,
    val dietaryTags: List<String>? = null,
    val id: String? = null,
)

data class MenuOverridePayload(
    val overrides: List<MenuOverride> = emptyList(),
    val corrections: List<MenuCorrection> = emptyList(),
) {
    val isEmpty: Boolean get() = overrides.isEmpty() && corrections.isEmpty()
}

object MenuOverrideFeed {
    const val FEED_URL =
        "https://raw.githubusercontent.com/atharvgups/zoteats/main/apple/menu-overrides.json"

    val bundled: MenuOverridePayload = MenuOverridePayload(
        overrides = listOf(
            MenuOverride(
                date = "2026-10-28",
                hall = "anteatery",
                period = "Dinner",
                stationID = "1929",
                stationName = "The Twisted Root",
                kind = "insert",
                verified = true,
                note = "Atharv confirmed in person: Anteatery served Cajun Tofu and White Rice at Twisted Root for dinner. Anteater API and MyDiningHub both omitted the dish.",
                items = listOf(
                    MenuOverrideItem(
                        id = "override:anteatery-dinner-1929-cajun-tofu-2026-10-28",
                        name = "Cajun Tofu and White Rice",
                        dietaryTags = listOf("Vegan", "Vegetarian"),
                    ),
                ),
            ),
            MenuOverride(
                date = "2026-10-29",
                hall = "anteatery",
                period = "Lunch",
                stationID = "override:fable-takeover-2026-10-29",
                stationName = "Fable Station Takeover",
                kind = "special",
                verified = true,
                note = "Atharv photographed the Fable Station Takeover board at Anteatery lunch. Anteater /events lists the takeover with no dishes.",
                items = listOf(
                    MenuOverrideItem(
                        id = "override:anteatery-lunch-fable-chipotle-mushroom-soft-tacos-2026-10-29",
                        name = "Chipotle Mushroom Soft Tacos",
                        description = "Sauteed chipotle mushrooms, fire-roasted salsa and warm flour tortilla",
                        calories = 180,
                        dietaryTags = listOf("Vegan", "Vegetarian", "Plant Forward"),
                    ),
                ),
            ),
        ),
        corrections = listOf(
            MenuCorrection(
                date = "2026-10-29",
                hall = "anteatery",
                period = "Lunch",
                matchName = "Thai Red Curry Bowl",
                stationID = "1926",
                stationName = "Fire and Ice",
                verified = true,
                note = "Atharv confirmed in person at Anteatery lunch: the Fire and Ice Thai Red Curry Bowl contains shrimp.",
                removeDietaryTags = listOf("Vegan", "Vegetarian", "Plant Forward", "Plant Powered"),
                addAllergens = listOf("Shellfish"),
                description = "Thai red curry with shrimp, sweet potatoes and green beans served with jasmine rice topped with cilantro",
            ),
        ),
    )

    fun decode(body: String): MenuOverridePayload {
        val root = runCatching { Json.parseToJsonElement(body) }.getOrNull() ?: return MenuOverridePayload()
        val (overrideRows, correctionRows) = when (root) {
            is JsonObject -> root["overrides"]?.jsonArray to root["corrections"]?.jsonArray
            is JsonArray -> root to null
            else -> null to null
        }
        return MenuOverridePayload(
            overrides = overrideRows?.mapNotNull { decodeOverride(it as? JsonObject) }.orEmpty(),
            corrections = correctionRows?.mapNotNull { decodeCorrection(it as? JsonObject) }.orEmpty(),
        )
    }

    fun hallMatches(overrideHall: String, menuHall: String): Boolean {
        val wanted = overrideHall.trim().lowercase()
        val live = menuHall.trim().lowercase()
        if (wanted == live) return true
        if (HallDirectory.campusHubKey(live) == wanted) return true
        if (HallDirectory.eatHallID(wanted) == live) return true
        return false
    }

    fun periodMatches(overridePeriod: String, menuPeriod: String): Boolean =
        DiningLogic.canonicalPill(overridePeriod)
            .equals(DiningLogic.canonicalPill(menuPeriod), ignoreCase = true)

    fun namesMatch(a: String, b: String): Boolean =
        DiningLogic.collapsedStationName(a) == DiningLogic.collapsedStationName(b)

    fun applying(overrides: List<MenuOverride>, menu: DiningMenu): DiningMenu =
        applying(MenuOverridePayload(overrides = overrides), menu)

    fun applying(feed: MenuOverridePayload, menu: DiningMenu): DiningMenu {
        val inserted = applyingInserts(feed.overrides, menu)
        return applyingCorrections(feed.corrections, inserted)
    }

    fun applyingInserts(overrides: List<MenuOverride>, menu: DiningMenu): DiningMenu {
        val matching = overrides.filter {
            it.date == menu.date &&
                hallMatches(it.hall, menu.locationId) &&
                periodMatches(it.period, menu.period) &&
                it.items.isNotEmpty()
        }
        if (matching.isEmpty()) return menu
        val stations = menu.stations.toMutableList()
        for (entry in matching) {
            val sid = entry.stationID.trim()
            val name = DiningLogic.displayStationName(entry.stationName, sid)
            val dishes = DiningLogic.applyStationTags(
                entry.items.map { item ->
                    MenuItem(
                        id = item.id,
                        name = item.name,
                        description = item.description,
                        calories = item.calories,
                        servingSize = null,
                        allergens = item.allergens,
                        dietaryTags = item.dietaryTags,
                        stationID = sid,
                    )
                },
                name,
                sid,
            )
            val idx = stations.indexOfFirst { canJoin(it, sid, name) }
            if (idx >= 0) {
                val seen = stations[idx].items.map { it.name.lowercase() }.toMutableSet()
                val next = stations[idx].items.toMutableList()
                for (dish in dishes) {
                    if (seen.add(dish.name.lowercase())) next += dish
                }
                stations[idx] = stations[idx].withItems(next)
            } else {
                val lane = if (entry.isSpecial) {
                    DiningLogic.StationLane.HOT_ENTREE
                } else {
                    DiningLogic.StationLane.TWISTED_ROOT
                }
                val insertAt = stations.indexOfFirst {
                    DiningLogic.stationLane(it.name, it.stationID, it.items) > lane
                }.let { if (it < 0) stations.size else it }
                stations.add(insertAt, MenuStation(name, dishes, sid))
            }
        }
        return menu.copy(stations = DiningLogic.pinTwistedRootFirst(stations))
    }

    fun applyingCorrections(corrections: List<MenuCorrection>, menu: DiningMenu): DiningMenu {
        val matching = corrections.filter {
            it.date == menu.date &&
                hallMatches(it.hall, menu.locationId) &&
                periodMatches(it.period, menu.period) &&
                it.matchName.trim().isNotEmpty()
        }
        if (matching.isEmpty()) return menu
        val stations = menu.stations.toMutableList()
        for (entry in matching) {
            val needle = entry.matchName.trim()
            var patched = false
            for (idx in stations.indices) {
                val stationID = entry.stationID?.trim().orEmpty()
                if (stationID.isNotEmpty() &&
                    !DiningLogic.canMergeHubExtra(stations[idx], stationID) &&
                    stations[idx].stationID != stationID
                ) {
                    continue
                }
                var changed = false
                val items = stations[idx].items.map { item ->
                    if (!namesMatch(item.name, needle)) item
                    else {
                        changed = true
                        patched = true
                        patchedItem(item, entry)
                    }
                }
                if (changed) stations[idx] = stations[idx].withItems(items)
            }
            if (patched) continue
            val sid = entry.stationID?.trim().orEmpty()
            val stationName = DiningLogic.displayStationName(entry.stationName, sid)
            val dish = patchedItem(
                MenuItem(
                    id = entry.id ?: "override:correction:${menu.locationId}-${menu.period}-$sid-$needle-${menu.date}"
                        .lowercase()
                        .replace(" ", "-"),
                    name = needle,
                    description = null,
                    calories = null,
                    servingSize = null,
                    allergens = emptyList(),
                    dietaryTags = entry.dietaryTags.orEmpty(),
                    stationID = sid.ifEmpty { null },
                ),
                entry,
            )
            val idx = stations.indexOfFirst { canJoin(it, sid, stationName) }
            if (idx >= 0) {
                stations[idx] = stations[idx].withItems(stations[idx].items + dish)
            } else {
                val insertAt = stations.indexOfFirst {
                    DiningLogic.stationLane(it.name, it.stationID, it.items) >
                        DiningLogic.StationLane.TWISTED_ROOT
                }.let { if (it < 0) stations.size else it }
                stations.add(insertAt, MenuStation(stationName, listOf(dish), sid.ifEmpty { null }))
            }
        }
        return menu.copy(stations = DiningLogic.pinTwistedRootFirst(stations))
    }

    @Volatile private var cachedAt = 0L
    @Volatile private var cached: MenuOverridePayload? = null

    fun fetch(get: (String) -> Pair<Int, String> = { url -> httpGet(url) }): MenuOverridePayload {
        val now = System.currentTimeMillis()
        cached?.let { if (now - cachedAt < 10 * 60 * 1000L) return it }
        val (code, body) = runCatching { get(FEED_URL) }.getOrNull() ?: return bundled
        val next = if (code in 200..299 && body.isNotBlank()) {
            val decoded = decode(body)
            if (decoded.isEmpty) bundled else decoded
        } else {
            bundled
        }
        cached = next
        cachedAt = now
        return next
    }

    private fun canJoin(station: MenuStation, stationID: String, stationName: String): Boolean {
        if (stationID.isNotEmpty() && DiningLogic.canMergeHubExtra(station, stationID)) return true
        if (stationName != "Menu" && namesMatch(station.name, stationName)) return true
        return false
    }

    private fun patchedItem(item: MenuItem, entry: MenuCorrection): MenuItem {
        val remove = entry.removeDietaryTags.map { it.lowercase() }.toSet()
        var tags = item.dietaryTags.filter { it.lowercase() !in remove }
        entry.dietaryTags?.let { tags = it.filter { tag -> tag.lowercase() !in remove } }
        val allergens = item.allergens.toMutableList()
        for (allergen in entry.addAllergens) {
            if (allergens.none { it.equals(allergen, true) }) allergens += allergen
        }
        return item.copy(
            description = entry.description ?: item.description,
            calories = entry.calories ?: item.calories,
            allergens = allergens,
            dietaryTags = tags,
            stationID = item.stationID ?: entry.stationID,
        )
    }

    private fun decodeOverride(obj: JsonObject?): MenuOverride? {
        obj ?: return null
        val date = obj.string("date") ?: return null
        val hall = obj.string("hall") ?: return null
        val period = obj.string("period") ?: return null
        val stationID = obj.string("stationID") ?: return null
        val items = (obj["items"] as? JsonArray)?.mapNotNull { itemEl ->
            val item = itemEl as? JsonObject ?: return@mapNotNull null
            val id = item.string("id") ?: return@mapNotNull null
            val name = item.string("name") ?: return@mapNotNull null
            MenuOverrideItem(
                id = id,
                name = name,
                description = item.string("description"),
                calories = item["calories"]?.jsonPrimitive?.intOrNull,
                dietaryTags = item.stringList("dietaryTags"),
                allergens = item.stringList("allergens"),
            )
        }.orEmpty()
        if (items.isEmpty()) return null
        return MenuOverride(
            date = date,
            hall = hall,
            period = period,
            stationID = stationID,
            stationName = obj.string("stationName") ?: "The Twisted Root",
            kind = obj.string("kind"),
            verified = obj["verified"]?.jsonPrimitive?.contentOrNull != "false",
            note = obj.string("note"),
            items = items,
        )
    }

    private fun decodeCorrection(obj: JsonObject?): MenuCorrection? {
        obj ?: return null
        val date = obj.string("date") ?: return null
        val hall = obj.string("hall") ?: return null
        val period = obj.string("period") ?: return null
        val matchName = obj.string("matchName") ?: return null
        return MenuCorrection(
            date = date,
            hall = hall,
            period = period,
            matchName = matchName,
            stationID = obj.string("stationID"),
            stationName = obj.string("stationName"),
            verified = obj["verified"]?.jsonPrimitive?.contentOrNull != "false",
            note = obj.string("note"),
            removeDietaryTags = obj.stringList("removeDietaryTags"),
            addAllergens = obj.stringList("addAllergens"),
            description = obj.string("description"),
            calories = obj["calories"]?.jsonPrimitive?.intOrNull,
            dietaryTags = (obj["dietaryTags"] as? JsonArray)?.mapNotNull { it.jsonPrimitive.contentOrNull },
            id = obj.string("id"),
        )
    }

    private fun httpGet(url: String): Pair<Int, String> {
        val conn = (URL(url).openConnection() as HttpURLConnection).apply {
            connectTimeout = 8_000
            readTimeout = 8_000
            requestMethod = "GET"
            setRequestProperty("Accept", "application/json")
            setRequestProperty("User-Agent", "Anteats/1.0 (UCI student utility)")
        }
        return try {
            val code = conn.responseCode
            val stream = if (code in 200..299) conn.inputStream else conn.errorStream
            val text = stream?.bufferedReader(StandardCharsets.UTF_8)?.use { it.readText() }.orEmpty()
            code to text
        } finally {
            conn.disconnect()
        }
    }
}

private fun JsonObject.string(key: String): String? = this[key]?.jsonPrimitive?.contentOrNull

private fun JsonObject.stringList(key: String): List<String> =
    (this[key] as? JsonArray)?.mapNotNull { it.jsonPrimitive.contentOrNull }.orEmpty()

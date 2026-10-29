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
)

data class MenuOverride(
    val date: String,
    val hall: String,
    val period: String,
    val stationID: String,
    val stationName: String,
    val verified: Boolean = true,
    val note: String? = null,
    val items: List<MenuOverrideItem>,
)

object MenuOverrideFeed {
    const val FEED_URL =
        "https://raw.githubusercontent.com/atharvgups/zoteats/main/apple/menu-overrides.json"

    val bundled: List<MenuOverride> = listOf(
        MenuOverride(
            date = "2026-10-28",
            hall = "anteatery",
            period = "Dinner",
            stationID = "1929",
            stationName = "The Twisted Root",
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
    )

    fun decode(body: String): List<MenuOverride> {
        val root = runCatching { Json.parseToJsonElement(body) }.getOrNull() ?: return emptyList()
        val rows = when (root) {
            is JsonObject -> root["overrides"]?.jsonArray
            is JsonArray -> root
            else -> null
        } ?: return emptyList()
        return rows.mapNotNull { el ->
            val obj = el as? JsonObject ?: return@mapNotNull null
            val date = obj.string("date") ?: return@mapNotNull null
            val hall = obj.string("hall") ?: return@mapNotNull null
            val period = obj.string("period") ?: return@mapNotNull null
            val stationID = obj.string("stationID") ?: return@mapNotNull null
            val items = (obj["items"] as? JsonArray)?.mapNotNull { itemEl ->
                val item = itemEl as? JsonObject ?: return@mapNotNull null
                val id = item.string("id") ?: return@mapNotNull null
                val name = item.string("name") ?: return@mapNotNull null
                MenuOverrideItem(
                    id = id,
                    name = name,
                    description = item.string("description"),
                    calories = item["calories"]?.jsonPrimitive?.intOrNull,
                    dietaryTags = (item["dietaryTags"] as? JsonArray)
                        ?.mapNotNull { it.jsonPrimitive.contentOrNull }
                        .orEmpty(),
                )
            }.orEmpty()
            if (items.isEmpty()) return@mapNotNull null
            MenuOverride(
                date = date,
                hall = hall,
                period = period,
                stationID = stationID,
                stationName = obj.string("stationName") ?: "The Twisted Root",
                verified = obj["verified"]?.jsonPrimitive?.contentOrNull != "false",
                note = obj.string("note"),
                items = items,
            )
        }
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

    fun applying(overrides: List<MenuOverride>, menu: DiningMenu): DiningMenu {
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
                        allergens = emptyList(),
                        dietaryTags = item.dietaryTags,
                        stationID = sid,
                    )
                },
                name,
                sid,
            )
            val idx = stations.indexOfFirst { DiningLogic.canMergeHubExtra(it, sid) }
            if (idx >= 0) {
                val seen = stations[idx].items.map { it.name.lowercase() }.toMutableSet()
                val next = stations[idx].items.toMutableList()
                for (dish in dishes) {
                    if (seen.add(dish.name.lowercase())) next += dish
                }
                stations[idx] = stations[idx].withItems(next)
            } else {
                val insertAt = stations.indexOfFirst {
                    DiningLogic.stationLane(it.name, it.stationID, it.items) >
                        DiningLogic.StationLane.TWISTED_ROOT
                }.let { if (it < 0) stations.size else it }
                stations.add(insertAt, MenuStation(name, dishes, sid))
            }
        }
        return menu.copy(stations = DiningLogic.pinTwistedRootFirst(stations))
    }

    @Volatile private var cachedAt = 0L
    @Volatile private var cached: List<MenuOverride>? = null

    fun fetch(get: (String) -> Pair<Int, String> = { url -> httpGet(url) }): List<MenuOverride> {
        val now = System.currentTimeMillis()
        cached?.let { if (now - cachedAt < 10 * 60 * 1000L) return it }
        val (code, body) = runCatching { get(FEED_URL) }.getOrNull() ?: return bundled
        val next = if (code in 200..299 && body.isNotBlank()) decode(body) else bundled
        cached = next
        cachedAt = now
        return next
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

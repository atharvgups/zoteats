package com.atharvgupta.anteats.data

import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.withContext
import kotlinx.serialization.json.Json
import kotlinx.serialization.json.JsonArray
import kotlinx.serialization.json.JsonObject
import kotlinx.serialization.json.contentOrNull
import kotlinx.serialization.json.jsonArray
import kotlinx.serialization.json.jsonObject
import kotlinx.serialization.json.jsonPrimitive
import java.net.HttpURLConnection
import java.net.URL
import java.net.URLEncoder
import java.nio.charset.StandardCharsets

data class TimeWindow(val start: Int, val end: Int) {
    val isAllDay: Boolean get() = start == end || end - start >= 24 * 60
    fun contains(minute: Int): Boolean {
        if (isAllDay) return true
        return if (end > start) minute >= start && minute < end else minute >= start || minute < (end % (24 * 60))
    }
}

data class CampusPlace(
    val id: String,
    val name: String,
    val category: String,
    val hasMenu: Boolean,
    val openNow: Boolean,
    val hoursLine: String?,
    val statusLine: String,
)

class CampusRepository {
    private val json = Json { ignoreUnknownKeys = true }
    private val excluded = setOf(
        "the-anteatery", "brandywine", "the-oasis-dining-hall", "the-oasis", "oasis",
        "mesa-commons", "mesa-court-commons", "mesa-court-dining",
        "middle-earth-towers", "middle-earth-commons",
    )
    private val dayAbbr = mapOf(
        "Sunday" to "Su", "Monday" to "Mo", "Tuesday" to "Tu", "Wednesday" to "We",
        "Thursday" to "Th", "Friday" to "Fr", "Saturday" to "Sa",
    )
    private val dayOrder = listOf("Mo", "Tu", "We", "Th", "Fr", "Sa", "Su")

    suspend fun places(): List<CampusPlace> = withContext(Dispatchers.IO) {
        val query = """query(${'$'}campusUrlKey:String!){getLocations(campusUrlKey:${'$'}campusUrlKey){commerceAttributes{url_key hasActiveMenus}aemAttributes{name hoursOfOperation{schedule{name type start_date end_date meal_periods{meal_period opening_hours}}}}}}"""
        val variables = """{"campusUrlKey":"campus"}"""
        val root = graphQL(query, variables)
        val rows = root["data"]?.jsonObject?.get("getLocations")?.jsonArray ?: JsonArray(emptyList())
        val todayISO = PacificTime.todayISO()
        val weekday = PacificTime.weekdayName(todayISO) ?: PacificTime.weekdayName(PacificTime.todayISO()) ?: "Thursday"
        val now = PacificTime.nowMinutes()
        rows.mapNotNull { el ->
            val obj = el.jsonObject
            val key = obj["commerceAttributes"]?.jsonObject?.string("url_key") ?: return@mapNotNull null
            if (key in excluded) return@mapNotNull null
            val name = obj["aemAttributes"]?.jsonObject?.string("name")
                ?.replace("\u00AD", "")
                ?.trim()
                .orEmpty()
            if (name.isEmpty()) return@mapNotNull null
            val schedules = obj["aemAttributes"]?.jsonObject
                ?.get("hoursOfOperation")?.jsonObject
                ?.get("schedule")?.jsonArray ?: JsonArray(emptyList())
            val windows = dayWindows(schedules, todayISO, weekday)
            val openNow = windows.any { it.contains(now) }
            val hours = formatWindows(windows)
            CampusPlace(
                id = key,
                name = name,
                category = categorize(name),
                hasMenu = obj["commerceAttributes"]?.jsonObject?.string("hasActiveMenus") == "true",
                openNow = openNow,
                hoursLine = hours,
                statusLine = when {
                    openNow -> "Open"
                    windows.isNotEmpty() -> "Closed"
                    else -> "Hours not posted"
                },
            )
        }.sortedBy { it.name.lowercase() }
    }

    fun typeMatches(filter: String, category: String): Boolean = when (filter) {
        "Coffee" -> category == "Coffee & Cafes" || category == "Coffee & Cafés"
        "Food" -> category == "Food Courts" || category == "Restaurants & Pubs"
        "Markets" -> category == "Markets"
        else -> true
    }

    fun categorize(name: String): String {
        val lowered = name.lowercase()
        if ("zot n go" in lowered || "market" in lowered) return "Markets"
        if ("pub" in lowered) return "Restaurants & Pubs"
        if (listOf("starbucks", "java", "cafe", "café", "einstein", "jamba", "panera", "green room")
                .any { it in lowered }
        ) {
            return "Coffee & Cafes"
        }
        return "Food Courts"
    }

    private fun dayWindows(schedules: JsonArray, todayISO: String, weekday: String): List<TimeWindow> {
        val special = schedules.firstOrNull { s ->
            val o = s.jsonObject
            o.string("type") == "special" &&
                (o.string("start_date") ?: "9999") <= todayISO &&
                (o.string("end_date") ?: "0000") >= todayISO
        }
        val active = special ?: schedules.firstOrNull { it.jsonObject.string("type") == "standard" } ?: return emptyList()
        val periods = active.jsonObject["meal_periods"]?.jsonArray ?: return emptyList()
        return periods.mapNotNull { windowFrom(it.jsonObject.string("opening_hours"), weekday) }
            .distinct()
            .sortedBy { it.start }
    }

    private fun windowFrom(openingHours: String?, weekday: String): TimeWindow? {
        val dayCode = dayAbbr[weekday] ?: return null
        if (openingHours.isNullOrBlank()) return null
        for (rule in openingHours.split(';')) {
            val trimmed = rule.trim()
            if (trimmed.isEmpty()) continue
            val parts = trimmed.split(' ')
            val daySpec = parts.firstOrNull() ?: continue
            if (!ruleCovers(daySpec, dayCode)) continue
            val remainder = parts.drop(1).joinToString(" ")
            if (remainder.isEmpty() || remainder.contains("off", true)) return null
            val times = remainder.split('-')
            if (times.size != 2) return null
            val start = PacificTime.parseMinutes(times[0].trim()) ?: return null
            val end = PacificTime.parseMinutes(times[1].trim()) ?: return null
            return TimeWindow(start, if (end == start) start else end)
        }
        return null
    }

    private fun ruleCovers(daySpec: String, dayCode: String): Boolean {
        for (token in daySpec.split(',')) {
            if (token == dayCode) return true
            val bounds = token.split('-')
            if (bounds.size == 2) {
                val lo = dayOrder.indexOf(bounds[0])
                val hi = dayOrder.indexOf(bounds[1])
                val day = dayOrder.indexOf(dayCode)
                if (lo >= 0 && hi >= 0 && day >= 0 && lo <= hi && day in lo..hi) return true
            }
        }
        return false
    }

    private fun formatWindows(windows: List<TimeWindow>): String? {
        if (windows.isEmpty()) return null
        if (windows.any { it.isAllDay }) return "Open 24 hours"
        return windows.joinToString(", ") {
            "${PacificTime.formatMinutes(it.start)} to ${PacificTime.formatMinutes(it.end % (24 * 60))}"
        }
    }

    private fun graphQL(query: String, variables: String): JsonObject {
        val url = URL(
            "https://api.elevate-dxp.com/api/mesh/c087f756-cc72-4649-a36f-3a41b700c519/graphql" +
                "?query=${URLEncoder.encode(query, StandardCharsets.UTF_8)}" +
                "&variables=${URLEncoder.encode(variables, StandardCharsets.UTF_8)}",
        )
        val conn = (url.openConnection() as HttpURLConnection).apply {
            connectTimeout = 15_000
            readTimeout = 20_000
            requestMethod = "GET"
            setRequestProperty("Accept", "application/json")
            setRequestProperty("User-Agent", "Anteats/1.0 (UCI student utility)")
            setRequestProperty("Referer", "https://uci.mydininghub.com/")
            setRequestProperty("Origin", "https://uci.mydininghub.com")
            setRequestProperty("store", "ch_uci_en")
            setRequestProperty("x-api-key", "ElevateAPIProd")
            setRequestProperty("magento-store-code", "ch_uci")
            setRequestProperty("magento-website-code", "ch_uci")
            setRequestProperty("magento-store-view-code", "ch_uci_en")
        }
        return try {
            val body = conn.inputStream.bufferedReader(StandardCharsets.UTF_8).use { it.readText() }
            json.parseToJsonElement(body).jsonObject
        } finally {
            conn.disconnect()
        }
    }
}

private fun JsonObject.string(key: String): String? = this[key]?.jsonPrimitive?.contentOrNull

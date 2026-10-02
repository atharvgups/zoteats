package com.atharvgupta.anteats.data

import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.withContext
import kotlinx.serialization.json.Json
import kotlinx.serialization.json.JsonObject
import kotlinx.serialization.json.contentOrNull
import kotlinx.serialization.json.doubleOrNull
import kotlinx.serialization.json.intOrNull
import kotlinx.serialization.json.jsonArray
import kotlinx.serialization.json.jsonObject
import kotlinx.serialization.json.jsonPrimitive
import java.net.HttpURLConnection
import java.net.URL
import java.nio.charset.StandardCharsets

data class StudyZone(
    val id: Int,
    val name: String,
    val percent: Int?,
    val isOpen: Boolean,
    val hours: String?,
    val floors: List<StudyZone>,
)

class StudyRepository {
    private val json = Json { ignoreUnknownKeys = true }

    suspend fun libraries(): List<StudyZone> = withContext(Dispatchers.IO) {
        val conn = (URL("https://waitz.io/live/irvine").openConnection() as HttpURLConnection).apply {
            connectTimeout = 15_000
            readTimeout = 15_000
            requestMethod = "GET"
            setRequestProperty("Accept", "application/json")
        }
        try {
            val body = conn.inputStream.bufferedReader(StandardCharsets.UTF_8).use { it.readText() }
            val root = json.parseToJsonElement(body).jsonObject
            val data = root["data"]?.jsonArray ?: return@withContext emptyList()
            data.mapNotNull { parse(it.jsonObject) }
                .map { it.zone }
                .filter { isStudyLibrary(it.name) }
                .map { it.copy(name = displayName(it.name), floors = it.floors.map { floor -> floor.copy(name = displayName(floor.name)) }) }
        } finally {
            conn.disconnect()
        }
    }

    private data class Parsed(val zone: StudyZone, val category: String)

    private fun parse(obj: JsonObject): Parsed? {
        val name = obj.string("name")?.trim().orEmpty()
        if (name.isEmpty()) return null
        val people = obj["people"]?.jsonPrimitive?.intOrNull
        val capacity = obj["capacity"]?.jsonPrimitive?.intOrNull
        var percent = obj["busyness"]?.jsonPrimitive?.doubleOrNull?.let { Math.round(it).toInt() }
        if (percent == null && people != null && capacity != null && capacity > 0) {
            percent = Math.round(people * 100.0 / capacity).toInt()
        }
        percent = percent?.coerceIn(0, 100)
        val floors = obj["subLocs"]?.jsonArray?.mapNotNull { parse(it.jsonObject)?.zone }.orEmpty()
        val zone = StudyZone(
            id = obj["id"]?.jsonPrimitive?.intOrNull ?: -1,
            name = name,
            percent = percent,
            isOpen = obj.string("isOpen") == "true" || obj.string("isAvailable") == "true",
            hours = obj.string("hourSummary")?.trim()?.ifEmpty { null },
            floors = floors,
        )
        return Parsed(zone, categorize(name))
    }

    private fun isStudyLibrary(name: String): Boolean {
        val lowered = name.lowercase()
        if ("student center" in lowered) return false
        return "langson" in lowered || "science" in lowered || "sci lib" in lowered || "gateway" in lowered
    }

    private fun displayName(name: String): String {
        val lowered = name.lowercase()
        if ("langson" in lowered) return "Langson"
        if ("science" in lowered || "sci lib" in lowered || "gateway" in lowered) return "Gateway"
        return name
    }

    private fun categorize(name: String): String {
        val lowered = name.lowercase()
        return if (Regex("library|libraries|langson|science|gateway|grunigen|multimedia|ayala")
                .containsMatchIn(lowered)
        ) {
            "Library"
        } else {
            "Campus"
        }
    }
}

private fun JsonObject.string(key: String): String? = this[key]?.jsonPrimitive?.contentOrNull

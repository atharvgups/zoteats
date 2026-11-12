package com.atharvgupta.anteats.data

import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.withContext
import kotlinx.serialization.json.Json
import kotlinx.serialization.json.JsonArray
import kotlinx.serialization.json.JsonObject
import kotlinx.serialization.json.JsonPrimitive
import kotlinx.serialization.json.buildJsonObject
import kotlinx.serialization.json.contentOrNull
import kotlinx.serialization.json.jsonArray
import kotlinx.serialization.json.jsonObject
import kotlinx.serialization.json.jsonPrimitive
import java.net.HttpURLConnection
import java.net.URL
import java.nio.charset.StandardCharsets
import java.time.Instant

class DishReportFeed(
    private val token: String = System.getenv("ZOTEATS_REVIEWS_TOKEN").orEmpty(),
    private val get: suspend (url: String, headers: Map<String, String>) -> Pair<Int, String> =
        { url, headers -> http(url, "GET", headers, null) },
    private val send: suspend (method: String, url: String, headers: Map<String, String>, body: String?) -> Pair<Int, String> =
        { method, url, headers, body -> http(url, method, headers, body) },
    private var cache: List<DishReport> = emptyList(),
) {
    fun cached(): List<DishReport> = cache

    fun replaceCache(reports: List<DishReport>) {
        cache = reports
    }

    suspend fun fetch(): List<DishReport> {
        val (code, body) = get(FEED_URL, emptyMap())
        if (code == 404 || body.isBlank()) return cache
        if (code !in 200..299) return cache
        val remote = decode(body)
        cache = merge(cache, remote)
        return cache
    }

    suspend fun submit(
        date: String,
        hall: String,
        meal: String,
        dishID: String,
        dishName: String,
        reason: String,
        authorID: String,
        existing: List<DishReport>,
        updatedAt: String = Instant.now().toString(),
        queue: OutboundIngestQueue? = null,
    ): DishReportSubmitResult {
        val remote = runCatching { fetch() }.getOrDefault(existing.ifEmpty { cache })
        val published = dispatchReport(
            date = date,
            hall = hall,
            meal = meal,
            dishID = dishID,
            dishName = dishName,
            reason = reason,
            authorID = authorID,
            updatedAt = updatedAt,
        )
        if (published) {
            val next = DishReportLogic.upsert(
                existing = remote.ifEmpty { existing },
                date = date,
                hall = hall,
                meal = meal,
                dishID = dishID,
                dishName = dishName,
                reason = reason,
                authorID = authorID,
                updatedAt = updatedAt,
            )
            cache = next
            return DishReportSubmitResult(next, true)
        }
        queue?.enqueue(
            OutboundIngestItem(
                kind = OutboundIngestItem.KIND_REPORT,
                date = date,
                hall = hall,
                meal = meal,
                dishID = dishID,
                dishName = dishName,
                reason = reason,
                authorID = authorID,
                updatedAt = updatedAt,
            ),
        )
        cache = remote.ifEmpty { existing }
        return DishReportSubmitResult(cache, false)
    }

    suspend fun submitFeedback(
        date: String,
        hall: String,
        meal: String,
        dishID: String,
        dishName: String,
        text: String,
        authorID: String,
        updatedAt: String = Instant.now().toString(),
        queue: OutboundIngestQueue? = null,
    ): Boolean {
        val clipped = DishFeedbackLogic.clipped(text)
        if (clipped.isEmpty()) return false
        val published = dispatchFeedback(
            date = date,
            hall = hall,
            meal = meal,
            dishID = dishID,
            dishName = dishName,
            text = clipped,
            authorID = authorID,
            updatedAt = updatedAt,
        )
        if (published) return true
        queue?.enqueue(
            OutboundIngestItem(
                kind = OutboundIngestItem.KIND_FEEDBACK,
                date = date,
                hall = hall,
                meal = meal,
                dishID = dishID,
                dishName = dishName,
                reason = DishReportReason.OTHER,
                text = clipped,
                authorID = authorID,
                updatedAt = updatedAt,
            ),
        )
        return false
    }

    suspend fun dispatchReport(
        date: String,
        hall: String,
        meal: String,
        dishID: String,
        dishName: String,
        reason: String,
        authorID: String,
        updatedAt: String,
    ): Boolean {
        val authToken = token.trim()
        if (authToken.isEmpty()) return false
        val body = buildJsonObject {
            put("event_type", JsonPrimitive("dish-report"))
            put(
                "client_payload",
                buildJsonObject {
                    put("date", JsonPrimitive(date))
                    put("hall", JsonPrimitive(hall))
                    put("meal", JsonPrimitive(meal))
                    put("dishID", JsonPrimitive(dishID))
                    put("dishName", JsonPrimitive(dishName))
                    put("reason", JsonPrimitive(reason))
                    put("authorID", JsonPrimitive(authorID))
                    put("updatedAt", JsonPrimitive(updatedAt))
                },
            )
        }.toString()
        val result = send("POST", INGEST_URL, githubHeaders(authToken) + ("Content-Type" to "application/json"), body)
        return result.first in 200..299
    }

    suspend fun dispatchFeedback(
        date: String,
        hall: String,
        meal: String,
        dishID: String,
        dishName: String,
        text: String,
        authorID: String,
        updatedAt: String,
    ): Boolean {
        val authToken = token.trim()
        if (authToken.isEmpty()) return false
        val body = buildJsonObject {
            put("event_type", JsonPrimitive("dish-feedback"))
            put(
                "client_payload",
                buildJsonObject {
                    put("date", JsonPrimitive(date))
                    put("hall", JsonPrimitive(hall))
                    put("meal", JsonPrimitive(meal))
                    put("dishID", JsonPrimitive(dishID))
                    put("dishName", JsonPrimitive(dishName))
                    put("reason", JsonPrimitive(DishReportReason.OTHER))
                    put("text", JsonPrimitive(text))
                    put("authorID", JsonPrimitive(authorID))
                    put("updatedAt", JsonPrimitive(updatedAt))
                },
            )
        }.toString()
        val result = send("POST", INGEST_URL, githubHeaders(authToken) + ("Content-Type" to "application/json"), body)
        return result.first in 200..299
    }

    companion object {
        const val FEED_URL =
            "https://raw.githubusercontent.com/atharvgups/zoteats/main/apple/community-dish-reports.json"
        const val INGEST_URL = "https://api.github.com/repos/atharvgups/zoteats/dispatches"

        fun encode(reports: List<DishReport>): String {
            val rows = reports.sortedByDescending { it.updatedAt }.map { report ->
                JsonObject(
                    mapOf(
                        "date" to JsonPrimitive(report.date),
                        "hall" to JsonPrimitive(report.hall),
                        "meal" to JsonPrimitive(report.meal),
                        "dishID" to JsonPrimitive(report.dishID),
                        "dishName" to JsonPrimitive(report.dishName),
                        "reason" to JsonPrimitive(report.reason),
                        "authorID" to JsonPrimitive(report.authorID),
                        "updatedAt" to JsonPrimitive(report.updatedAt),
                    ),
                )
            }
            return JsonObject(mapOf("reports" to JsonArray(rows))).toString()
        }

        fun decode(raw: String): List<DishReport> {
            val root = runCatching { Json.parseToJsonElement(raw) }.getOrNull() ?: return emptyList()
            val rows: JsonArray = when (root) {
                is JsonObject -> root["reports"]?.jsonArray ?: JsonArray(emptyList())
                is JsonArray -> root
                else -> JsonArray(emptyList())
            }
            return rows.mapNotNull { el ->
                val obj = el as? JsonObject ?: return@mapNotNull null
                DishReport(
                    date = obj.string("date") ?: return@mapNotNull null,
                    hall = obj.string("hall") ?: return@mapNotNull null,
                    meal = obj.string("meal") ?: return@mapNotNull null,
                    dishID = obj.string("dishID") ?: return@mapNotNull null,
                    dishName = obj.string("dishName").orEmpty(),
                    reason = obj.string("reason") ?: return@mapNotNull null,
                    authorID = obj.string("authorID") ?: return@mapNotNull null,
                    updatedAt = obj.string("updatedAt").orEmpty(),
                )
            }
        }

        fun merge(cached: List<DishReport>, remote: List<DishReport>): List<DishReport> {
            val byID = linkedMapOf<String, DishReport>()
            for (report in cached + remote) {
                val existing = byID[report.id]
                if (existing != null && existing.updatedAt > report.updatedAt) continue
                byID[report.id] = report
            }
            return byID.values.sortedByDescending { it.updatedAt }
        }

        private fun githubHeaders(token: String) = mapOf(
            "Accept" to "application/vnd.github+json",
            "Authorization" to "Bearer $token",
            "X-GitHub-Api-Version" to "2022-11-28",
        )

        private suspend fun http(
            urlString: String,
            method: String,
            headers: Map<String, String>,
            body: String?,
        ): Pair<Int, String> = withContext(Dispatchers.IO) {
            val conn = (URL(urlString).openConnection() as HttpURLConnection).apply {
                connectTimeout = 15_000
                readTimeout = 20_000
                requestMethod = method
                doInput = true
                setRequestProperty("User-Agent", "Anteats/1.0 (UCI student utility)")
                headers.forEach { (key, value) -> setRequestProperty(key, value) }
                if (body != null) {
                    doOutput = true
                    outputStream.use { it.write(body.toByteArray(StandardCharsets.UTF_8)) }
                }
            }
            try {
                val code = conn.responseCode
                val stream = if (code in 200..299) conn.inputStream else conn.errorStream
                val text = stream?.bufferedReader(StandardCharsets.UTF_8)?.use { it.readText() }.orEmpty()
                code to text
            } finally {
                conn.disconnect()
            }
        }

        private fun JsonObject.string(key: String): String? =
            this[key]?.jsonPrimitive?.contentOrNull
    }
}

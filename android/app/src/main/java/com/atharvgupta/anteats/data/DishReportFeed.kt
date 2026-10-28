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
import java.util.Base64

class DishReportFeed(
    private val token: String = System.getenv("ZOTEATS_REVIEWS_TOKEN").orEmpty(),
    private val get: suspend (url: String, headers: Map<String, String>) -> Pair<Int, String> =
        { url, headers -> http(url, "GET", headers, null) },
    private val send: suspend (method: String, url: String, headers: Map<String, String>, body: String?) -> Pair<Int, String> =
        { method, url, headers, body -> http(url, method, headers, body) },
) {
    suspend fun fetch(): List<DishReport> {
        val (code, body) = get(FEED_URL, emptyMap())
        if (code == 404 || body.isBlank()) return emptyList()
        if (code !in 200..299) return emptyList()
        return decode(body)
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
    ): List<DishReport> {
        val remote = runCatching { fetch() }.getOrDefault(existing)
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
        val payload = encode(next)
        val putLive = send(
            "PUT",
            FEED_URL,
            mapOf("Content-Type" to "application/json", "Accept" to "application/json"),
            payload,
        )
        if (putLive.first in 200..299) return next
        if (putGitHubContents(payload)) return next
        if (dispatchIngest(date, hall, meal, dishID, dishName, reason, authorID, updatedAt)) return next
        return existing
    }

    private suspend fun putGitHubContents(payload: String): Boolean {
        val authToken = token.trim()
        if (authToken.isEmpty()) return false
        val auth = githubHeaders(authToken)
        val meta = get(GITHUB_CONTENTS_URL, auth)
        val sha = if (meta.first in 200..299) {
            runCatching {
                Json.parseToJsonElement(meta.second).jsonObject["sha"]?.jsonPrimitive?.contentOrNull
            }.getOrNull()
        } else {
            null
        }
        val body = buildJsonObject {
            put("message", JsonPrimitive("chore(reports): publish community dish flag"))
            put("content", JsonPrimitive(Base64.getEncoder().encodeToString(payload.toByteArray(StandardCharsets.UTF_8))))
            put("branch", JsonPrimitive("main"))
            if (!sha.isNullOrBlank()) put("sha", JsonPrimitive(sha))
        }.toString()
        val result = send("PUT", GITHUB_CONTENTS_URL, auth + ("Content-Type" to "application/json"), body)
        return result.first in 200..299
    }

    private suspend fun dispatchIngest(
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

    companion object {
        const val FEED_URL =
            "https://raw.githubusercontent.com/atharvgups/zoteats/main/apple/community-dish-reports.json"
        const val GITHUB_CONTENTS_URL =
            "https://api.github.com/repos/atharvgups/zoteats/contents/apple/community-dish-reports.json"
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

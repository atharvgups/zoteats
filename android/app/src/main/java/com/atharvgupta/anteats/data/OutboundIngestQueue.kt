package com.atharvgupta.anteats.data

import kotlinx.serialization.json.JsonObject
import kotlinx.serialization.json.JsonPrimitive
import kotlinx.serialization.json.contentOrNull
import kotlinx.serialization.json.jsonPrimitive
import java.util.UUID

data class OutboundIngestItem(
    val id: String = UUID.randomUUID().toString(),
    val kind: String,
    val date: String = "",
    val hall: String = "",
    val meal: String = "",
    val dishID: String = "",
    val dishName: String = "",
    val reason: String = "",
    val text: String = "",
    val authorID: String = "",
    val stars: Int = 0,
    val updatedAt: String = "",
    val attempts: Int = 0,
) {
    val dedupeKey: String
        get() = when (kind) {
            KIND_REPORT -> "dishReport|${DishReportLogic.reportID(date, hall, meal, dishID, dishName, authorID)}"
            KIND_FEEDBACK -> "dishFeedback|${DishReportLogic.listingKey(date, hall, meal, dishID, dishName)}|$authorID"
            else -> "$kind|$dishName|$authorID"
        }

    companion object {
        const val KIND_REPORT = "dishReport"
        const val KIND_FEEDBACK = "dishFeedback"
    }
}

data class OutboundIngestFlushResult(val sent: Int, val remaining: Int)

class OutboundIngestQueue(
    private val load: () -> List<OutboundIngestItem>,
    private val save: (List<OutboundIngestItem>) -> Unit,
) {
    fun enqueue(item: OutboundIngestItem) {
        val next = load().filterNot { it.dedupeKey == item.dedupeKey } + item
        save(next)
    }

    fun pending(): List<OutboundIngestItem> = load()

    suspend fun flush(feed: DishReportFeed): OutboundIngestFlushResult {
        val pending = load()
        if (pending.isEmpty()) return OutboundIngestFlushResult(0, 0)
        val remaining = mutableListOf<OutboundIngestItem>()
        var sent = 0
        var reports = feed.cached()
        for (item in pending) {
            val ok = when (item.kind) {
                OutboundIngestItem.KIND_REPORT -> feed.dispatchReport(
                    date = item.date,
                    hall = item.hall,
                    meal = item.meal,
                    dishID = item.dishID,
                    dishName = item.dishName,
                    reason = item.reason,
                    authorID = item.authorID,
                    updatedAt = item.updatedAt,
                )
                OutboundIngestItem.KIND_FEEDBACK -> feed.dispatchFeedback(
                    date = item.date,
                    hall = item.hall,
                    meal = item.meal,
                    dishID = item.dishID,
                    dishName = item.dishName,
                    text = item.text,
                    authorID = item.authorID,
                    updatedAt = item.updatedAt,
                )
                else -> false
            }
            if (ok) {
                sent += 1
                if (item.kind == OutboundIngestItem.KIND_REPORT) {
                    reports = DishReportLogic.upsert(
                        existing = reports,
                        date = item.date,
                        hall = item.hall,
                        meal = item.meal,
                        dishID = item.dishID,
                        dishName = item.dishName,
                        reason = item.reason,
                        authorID = item.authorID,
                        updatedAt = item.updatedAt,
                    )
                }
            } else {
                remaining += item.copy(attempts = item.attempts + 1)
            }
        }
        save(remaining)
        if (sent > 0) feed.replaceCache(reports)
        return OutboundIngestFlushResult(sent, remaining.size)
    }

    companion object {
        fun encode(items: List<OutboundIngestItem>): String {
            val rows = items.map { item ->
                JsonObject(
                    mapOf(
                        "id" to JsonPrimitive(item.id),
                        "kind" to JsonPrimitive(item.kind),
                        "date" to JsonPrimitive(item.date),
                        "hall" to JsonPrimitive(item.hall),
                        "meal" to JsonPrimitive(item.meal),
                        "dishID" to JsonPrimitive(item.dishID),
                        "dishName" to JsonPrimitive(item.dishName),
                        "reason" to JsonPrimitive(item.reason),
                        "text" to JsonPrimitive(item.text),
                        "authorID" to JsonPrimitive(item.authorID),
                        "stars" to JsonPrimitive(item.stars),
                        "updatedAt" to JsonPrimitive(item.updatedAt),
                        "attempts" to JsonPrimitive(item.attempts),
                    ),
                )
            }
            return JsonObject(mapOf("items" to kotlinx.serialization.json.JsonArray(rows))).toString()
        }

        fun decode(raw: String): List<OutboundIngestItem> {
            val root = runCatching {
                kotlinx.serialization.json.Json.parseToJsonElement(raw)
            }.getOrNull() as? JsonObject ?: return emptyList()
            val rows = root["items"]?.let { it as? kotlinx.serialization.json.JsonArray }
                ?: return emptyList()
            return rows.mapNotNull { el ->
                val obj = el as? JsonObject ?: return@mapNotNull null
                OutboundIngestItem(
                    id = obj.string("id") ?: UUID.randomUUID().toString(),
                    kind = obj.string("kind") ?: return@mapNotNull null,
                    date = obj.string("date").orEmpty(),
                    hall = obj.string("hall").orEmpty(),
                    meal = obj.string("meal").orEmpty(),
                    dishID = obj.string("dishID").orEmpty(),
                    dishName = obj.string("dishName").orEmpty(),
                    reason = obj.string("reason").orEmpty(),
                    text = obj.string("text").orEmpty(),
                    authorID = obj.string("authorID").orEmpty(),
                    stars = obj["stars"]?.jsonPrimitive?.contentOrNull?.toIntOrNull() ?: 0,
                    updatedAt = obj.string("updatedAt").orEmpty(),
                    attempts = obj["attempts"]?.jsonPrimitive?.contentOrNull?.toIntOrNull() ?: 0,
                )
            }
        }

        private fun JsonObject.string(key: String): String? =
            this[key]?.jsonPrimitive?.contentOrNull
    }
}

data class DishReportSubmitResult(
    val reports: List<DishReport>,
    val published: Boolean,
)

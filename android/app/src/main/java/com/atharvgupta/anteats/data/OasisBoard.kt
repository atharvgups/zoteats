package com.atharvgupta.anteats.data

object OasisBoard {
    data class StationMeta(val id: String, val name: String, val position: Int)

    data class PostedBoard(val stationsByPeriod: Map<String, List<MenuStation>>) {
        val availablePeriods: List<String>
            get() = servedPeriodNames.filter { period ->
                stationsByPeriod[period].orEmpty().isNotEmpty()
            }

        fun stations(period: String): List<MenuStation> = stationsByPeriod[period].orEmpty()
    }

    val publishedStations = listOf(
        StationMeta("306552", "Main", 1),
        StationMeta("306555", "Salad & Soup", 2),
        StationMeta("306558", "Grill/Deli", 3),
        StationMeta("306561", "Desserts", 4),
        StationMeta("306564", "Pizza", 5),
        StationMeta("306567", "Saute", 6),
    )

    val servedPeriodNames = listOf("Lunch", "Dinner")
    const val kioskOrderOnlyLabel = "Kiosk order only"
    const val grabAndGoLabel = "Grab and go"

    fun directory(live: List<StationMeta> = emptyList()): Map<String, StationMeta> {
        val map = publishedStations.associateBy { it.id }.toMutableMap()
        for (row in live) {
            val id = row.id.trim()
            val name = row.name.trim()
            if (id.isEmpty() || name.isEmpty()) continue
            val position = if (row.position > 0) row.position else map[id]?.position ?: row.position
            map[id] = StationMeta(id, name, position)
        }
        return map
    }

    /** UCI Serve-Up Kiosks are pizzas and deli sandwiches. Other Hub Oasis stations are grab and go. */
    fun serviceLabel(stationName: String): String? {
        val lowered = DiningLogic.collapsedStationName(stationName)
        if (lowered.isEmpty()) return null
        if ("pizza" in lowered || "deli" in lowered) return kioskOrderOnlyLabel
        return grabAndGoLabel
    }

    fun isHotLineStation(name: String): Boolean {
        val lowered = DiningLogic.collapsedStationName(name)
        return lowered == "main" || lowered == "saute" || lowered == "sauté"
    }

    fun stationsForPeriod(
        periodSKUs: List<String>,
        stationSKUs: List<Pair<String, List<String>>>,
        directory: Map<String, StationMeta>,
        products: Map<String, MenuItem>,
    ): List<MenuStation> {
        val periodSet = periodSKUs.filter { it.isNotEmpty() }.toSet()
        if (periodSet.isEmpty()) return emptyList()
        val grouped = if (stationSKUs.isEmpty()) {
            fallbackGroups(periodSet, directory, products)
        } else {
            stationSKUs.mapNotNull { (id, skus) ->
                val meta = directory[id.trim()] ?: return@mapNotNull null
                meta to uniqueItems(skus.filter { it in periodSet }.mapNotNull { products[it] }, meta.id)
            }
        }
        return grouped.mapNotNull { (meta, items) ->
            if (items.isEmpty()) return@mapNotNull null
            if (isHotLineStation(meta.name) && items.all { DiningLogic.isStationStaple(it.name) }) {
                return@mapNotNull null
            }
            MenuStation(meta.name, items, meta.id, serviceLabel(meta.name))
        }.sortedWith(
            compareBy<MenuStation> { directory[it.stationID]?.position ?: Int.MAX_VALUE }
                .thenBy { it.name.lowercase() },
        )
    }

    fun postedBoard(
        mealPeriodSKUs: List<Pair<String, List<String>>>,
        stationSKUs: List<Pair<String, List<String>>>,
        directory: Map<String, StationMeta>,
        products: Map<String, MenuItem>,
    ): PostedBoard {
        val map = linkedMapOf<String, List<MenuStation>>()
        for ((rawName, skus) in mealPeriodSKUs) {
            val name = rawName.trim()
            val canonical = servedPeriodNames.firstOrNull { it.equals(name, true) } ?: continue
            val stations = stationsForPeriod(skus, stationSKUs, directory, products)
            if (stations.isNotEmpty()) map[canonical] = stations
        }
        return PostedBoard(map)
    }

    private fun fallbackGroups(
        periodSet: Set<String>,
        directory: Map<String, StationMeta>,
        products: Map<String, MenuItem>,
    ): List<Pair<StationMeta, List<MenuItem>>> {
        val buckets = linkedMapOf<String, MutableList<MenuItem>>()
        for (sku in periodSet) {
            val item = products[sku] ?: continue
            val sid = item.stationID?.takeIf { it in directory } ?: continue
            buckets.getOrPut(sid) { mutableListOf() }.add(item)
        }
        return buckets.mapNotNull { (sid, items) ->
            val meta = directory[sid] ?: return@mapNotNull null
            meta to uniqueItems(items, sid)
        }
    }

    private fun uniqueItems(items: List<MenuItem>, stationID: String): List<MenuItem> {
        val seen = mutableSetOf<String>()
        val out = mutableListOf<MenuItem>()
        for (item in items) {
            val key = DiningLogic.collapsedStationName(item.name)
            if (key.isEmpty() || !seen.add(key)) continue
            out += if (item.stationID == stationID) item else item.copy(stationID = stationID)
        }
        return out
    }
}

package com.atharvgupta.anteats.data

import kotlinx.coroutines.runBlocking
import org.junit.Assert.assertEquals
import org.junit.Assert.assertTrue
import org.junit.Test

class DiningRepositoryFixtureTest {
    private fun fixtureRepo(): DiningRepository = DiningRepository(
        hubStations = { _, _ -> emptyList() },
        menuOverrides = { MenuOverridePayload() },
    ) { path ->
        if ("/events" in path) {
            200 to """{"ok":true,"data":[]}"""
        } else {
            val name = when {
                "/restaurants" in path -> "restaurants.json"
                "/restaurantToday" in path -> "restaurant_today.json"
                "/dishes/batch" in path -> "dishes_batch.json"
                "/dateRange" in path -> "date_range.json"
                else -> error("unexpected path $path")
            }
            200 to checkNotNull(javaClass.getResource("/fixtures/$name")).readText()
        }
    }

    @Test
    fun locationsAreAnteateryBrandywineOasis() = runBlocking {
        val locations = fixtureRepo().locations()
        assertEquals(listOf("anteatery", "brandywine", "oasis"), locations.map { it.id })
        assertTrue(locations.last().isComingSoon)
        assertEquals("The Anteatery", locations.first().name)
    }

    @Test
    fun lunchPinsTwistedRootAndFoldsAllDay() = runBlocking {
        val menu = fixtureRepo().menu("anteatery", "Lunch", "2026-07-09")
        assertEquals("Lunch", menu.period)
        assertTrue(menu.stations.isNotEmpty())
        assertEquals("The Twisted Root", menu.stations.first().name)
        assertTrue(menu.stations.first().items.all { it.dietaryTags.contains("Vegan") })
        assertTrue(menu.stations.any { it.name == "Available all day" })
        val names = menu.stations.map { it.name }
        if (names.any { DiningLogic.isStandingBurger(it) }) {
            assertTrue(DiningLogic.isStandingBurger(names.last()))
        }
        val bakeryIdx = names.indexOfFirst { DiningLogic.isDessertStation(it) }
        val burgerIdx = names.indexOfFirst { DiningLogic.isStandingBurger(it) }
        if (bakeryIdx >= 0 && burgerIdx >= 0) {
            assertTrue(bakeryIdx < burgerIdx)
        }
        assertEquals(listOf("Breakfast", "Lunch"), menu.twistedRootMeals)
        assertTrue(menu.stations.flatMap { it.items }.any { it.calories != null })
    }

    @Test
    fun unpublishedDayIsEmptyNotAnError() = runBlocking {
        val full = DiningRepository(
            hubStations = { _, _ -> emptyList() },
            menuOverrides = { MenuOverridePayload() },
        ) { path ->
            when {
                "/restaurantToday" in path -> 404 to """{"ok":false}"""
                "/restaurants" in path -> 200 to javaClass.getResource("/fixtures/restaurants.json")!!.readText()
                "/dateRange" in path -> 200 to javaClass.getResource("/fixtures/date_range.json")!!.readText()
                else -> 200 to """{"ok":true,"data":[]}"""
            }
        }
        val menu = full.menu("brandywine", "Dinner", "2026-08-03")
        assertTrue(menu.stations.isEmpty())
        assertEquals("2026-08-03", menu.date)
    }

    @Test
    fun weekendMealsKeepTheirOwnPeriodDishes() = runBlocking {
        val weekend = """
            {"ok":true,"data":{"id":"anteatery","periods":{
              "breakfast":{"name":"Breakfast","startTime":"09:00:00","endTime":"11:00:00","stationToDishes":{"1929":["hash"],"1932":["eggs"]}},
              "brunch":{"name":"Brunch","startTime":"11:00:00","endTime":"16:30:00","stationToDishes":{"1929":["hash"],"1932":["eggs"],"1935":["burger"]}},
              "lunch":{"name":"Lunch","startTime":null,"endTime":null,"stationToDishes":{"1935":["burger"]}},
              "allday":{"name":"All Day","startTime":null,"endTime":null,"stationToDishes":{"1935":["burger"]}},
              "dinner":{"name":"Dinner","startTime":"16:30:00","endTime":"20:00:00","stationToDishes":{"1935":["burger"],"1941":["pasta"]}}
            }}}
        """.trimIndent()
        val brunchOnly = """
            {"ok":true,"data":{"id":"anteatery","periods":{
              "brunch":{"name":"Brunch","startTime":"11:00:00","endTime":"16:30:00","stationToDishes":{"1929":["hash"],"1932":["eggs"],"1935":["burger"]}},
              "dinner":{"name":"Dinner","startTime":"16:30:00","endTime":"20:00:00","stationToDishes":{"1935":["burger"],"1941":["pasta"]}}
            }}}
        """.trimIndent()
        val dishes = """
            {"ok":true,"data":[
              {"id":"hash","stationId":"1929","name":"Tofu-Potato Hash","dietRestriction":{"isVegan":true},"nutritionInfo":{"calories":180}},
              {"id":"eggs","stationId":"1932","name":"Judy's BBQ Eggs","nutritionInfo":{"calories":140}},
              {"id":"burger","stationId":"1935","name":"Cheeseburger","nutritionInfo":{"calories":400}},
              {"id":"pasta","stationId":"1941","name":"Cavatappi Alfredo","nutritionInfo":{"calories":410}}
            ]}
        """.trimIndent()
        val restaurants = """
            {"ok":true,"data":[{"id":"anteatery","stations":[
              {"id":"1929","name":"The Twisted Root"},
              {"id":"1932","name":"Home"},
              {"id":"1935","name":"Sizzle Grill"},
              {"id":"1941","name":"Oven"}
            ]}]}
        """.trimIndent()
        fun repo(today: String) = DiningRepository(
            hubStations = { _, _ -> emptyList() },
            menuOverrides = { MenuOverridePayload() },
        ) { path ->
            when {
                "/restaurants" in path -> 200 to restaurants
                "/restaurantToday" in path -> 200 to today
                "/dishes/batch" in path -> 200 to dishes
                "/dateRange" in path -> 200 to """{"ok":true,"data":{"earliest":"2026-10-01","latest":"2026-10-31"}}"""
                "/events" in path -> 200 to """{"ok":true,"data":[]}"""
                else -> error("unexpected path $path")
            }
        }
        fun timedNames(menu: DiningMenu) = menu.stations
            .filter { !DiningLogic.isAvailableAllDayStation(it.name) }
            .flatMap { it.items }
            .map { it.name }
            .toSet()

        val full = repo(weekend)
        val breakfast = full.menu("anteatery", "Breakfast", "2026-10-25")
        val lunch = full.menu("anteatery", "Lunch", "2026-10-25")
        val dinner = full.menu("anteatery", "Dinner", "2026-10-25")
        assertEquals(setOf("Tofu-Potato Hash", "Judy's BBQ Eggs"), timedNames(breakfast))
        assertEquals(setOf("Cheeseburger"), timedNames(lunch))
        assertEquals(setOf("Cheeseburger", "Cavatappi Alfredo"), timedNames(dinner))
        assertTrue(timedNames(breakfast) != timedNames(lunch))
        assertTrue(breakfast.stations.none { DiningLogic.isAvailableAllDayStation(it.name) })

        val onlyBrunch = repo(brunchOnly)
        val brunchBreakfast = onlyBrunch.menu("anteatery", "Breakfast", "2026-10-31")
        val brunchLunch = onlyBrunch.menu("anteatery", "Lunch", "2026-10-31")
        assertEquals(setOf("Tofu-Potato Hash", "Judy's BBQ Eggs", "Cheeseburger"), timedNames(brunchBreakfast))
        assertTrue(brunchLunch.stations.isEmpty())
    }

    @Test
    fun dateRangeComesFromFeed() = runBlocking {
        val range = fixtureRepo().publishedDateRange()
        assertEquals("2026-02-22", range?.earliest)
        assertEquals("2026-07-12", range?.latest)
        assertTrue(range!!.contains("2026-07-10"))
        assertTrue(!range.contains("2026-07-13"))
    }
}

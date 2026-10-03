package com.atharvgupta.anteats.data

import kotlinx.coroutines.runBlocking
import org.junit.Assert.assertEquals
import org.junit.Assert.assertTrue
import org.junit.Test

class DiningRepositoryFixtureTest {
    private fun fixtureRepo(): DiningRepository = DiningRepository { path ->
        val name = when {
            "/restaurants" in path -> "restaurants.json"
            "/restaurantToday" in path -> "restaurant_today.json"
            "/dishes/batch" in path -> "dishes_batch.json"
            "/dateRange" in path -> "date_range.json"
            else -> error("unexpected path $path")
        }
        val body = checkNotNull(javaClass.getResource("/fixtures/$name")).readText()
        200 to body
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
        assertEquals(listOf("Breakfast", "Lunch"), menu.twistedRootMeals)
        assertTrue(menu.stations.flatMap { it.items }.any { it.calories != null })
    }

    @Test
    fun unpublishedDayIsEmptyNotAnError() = runBlocking {
        val full = DiningRepository { path ->
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
    fun dateRangeComesFromFeed() = runBlocking {
        val range = fixtureRepo().publishedDateRange()
        assertEquals("2026-02-22", range?.earliest)
        assertEquals("2026-07-12", range?.latest)
        assertTrue(range!!.contains("2026-07-10"))
        assertTrue(!range.contains("2026-07-13"))
    }
}

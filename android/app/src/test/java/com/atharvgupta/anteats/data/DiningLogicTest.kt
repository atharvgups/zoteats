package com.atharvgupta.anteats.data

import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Test

class DiningLogicTest {
    @Test
    fun pillsAreBreakfastLunchDinnerOnly() {
        assertEquals(
            listOf("Breakfast", "Lunch", "Afternoon Snack", "Dinner", "Late Night"),
            DiningLogic.mealSelectorPills,
        )
        val available = listOf("Breakfast", "Brunch", "Lunch", "Dinner", "All Day")
        assertEquals(listOf("Breakfast", "Lunch", "Dinner"), DiningLogic.primaryPeriods(available))
        assertEquals(listOf("Breakfast", "Dinner"), DiningLogic.primaryPeriods(listOf("Brunch", "Dinner", "All Day")))
        assertTrue(DiningLogic.primaryPeriods(listOf("All Day")).isEmpty())
        assertEquals(
            listOf("Breakfast", "Lunch", "Afternoon Snack", "Dinner", "Late Night"),
            DiningLogic.primaryPeriods(
                listOf("Breakfast", "Lunch", "Afternoon Snack", "Dinner", "Evening Snack"),
            ),
        )
        assertEquals(
            listOf("Breakfast", "Afternoon Snack", "Late Night"),
            DiningLogic.primaryPeriods(listOf("Breakfast", "Afternoon Snack", "Evening Snack")),
        )
        assertEquals("Evening Snack", DiningLogic.resolvePeriod("Late Night", listOf("Dinner", "Evening Snack")))
        assertEquals("Overnight", DiningLogic.resolvePeriod("Late Night", listOf("Overnight")))
        assertTrue(DiningLogic.pillIsPosted("Late Night", listOf("Evening Snack")))
        assertFalse(DiningLogic.pillIsPosted("Late Night", listOf("Lunch", "Dinner")))
    }

    @Test
    fun brunchMapsOntoBreakfastAndLunch() {
        assertEquals("Brunch", DiningLogic.resolvePeriod("Breakfast", listOf("Brunch", "Dinner")))
        assertEquals("Brunch", DiningLogic.resolvePeriod("Lunch", listOf("Brunch", "Dinner")))
        val weekend = listOf("Breakfast", "Brunch", "Lunch", "Dinner", "All Day")
        assertEquals(listOf("Lunch", "Brunch"), DiningLogic.menuPeriodNames("Lunch", weekend))
        assertEquals(listOf("Breakfast"), DiningLogic.menuPeriodNames("Breakfast", weekend))
        assertFalse(DiningLogic.menuPeriodNames("Lunch", weekend).any { it.contains("All Day", true) })
    }

    @Test
    fun mergeKeepsHallTwistedRootIdsSeparate() {
        val tofu = MenuItem("a", "Tofu", null, 100, null, emptyList(), emptyList())
        val rice = MenuItem("b", "Rice", null, 120, null, emptyList(), emptyList())
        val merged = DiningLogic.mergeStations(
            listOf(
                listOf(MenuStation("Menu", listOf(tofu), "1929")),
                listOf(MenuStation("Menu", listOf(rice), "1932")),
            ),
        )
        assertEquals(2, merged.size)
        assertEquals(setOf("1929", "1932"), merged.mapNotNull { it.stationID }.toSet())
    }

    @Test
    fun lunchUnionsBrunchTacosWithoutDuplicatingBurgers() {
        val taco = MenuItem("taco", "Sesame Shrimp Taco", null, 320, null, emptyList(), emptyList())
        val burger = MenuItem("burger", "Cheeseburger", null, 400, null, emptyList(), emptyList())
        val merged = DiningLogic.mergeStations(
            listOf(
                listOf(MenuStation("Ember", listOf(burger))),
                listOf(MenuStation("Ember", listOf(burger)), MenuStation("Crossroads", listOf(taco))),
            ),
        )
        assertTrue(merged.any { it.name == "Crossroads" && it.items.any { item -> item.name == "Sesame Shrimp Taco" } })
        assertEquals(1, merged.first { it.name == "Ember" }.items.size)
    }

    @Test
    fun twistedRootLeadsAndGetsVeganTags() {
        val dish = MenuItem("x", "Mystery Tofu", null, 200, null, listOf("Soy"), emptyList())
        val tagged = DiningLogic.applyStationTags(listOf(dish), "Menu", "1929")[0]
        assertTrue(tagged.dietaryTags.contains("Vegan"))
        assertTrue(tagged.dietaryTags.contains("Vegetarian"))
        assertFalse(DiningLogic.applyStationTags(listOf(dish), "Sizzle Grill")[0].dietaryTags.contains("Vegan"))
        val stations = listOf(
            MenuStation("Sizzle Grill", listOf(dish)),
            MenuStation("The Twisted Root", listOf(dish), "1929"),
            MenuStation("Home", listOf(dish)),
            MenuStation("Available all day", listOf(dish)),
        )
        assertEquals(
            listOf("The Twisted Root", "Sizzle Grill", "Home", "Available all day"),
            DiningLogic.pinTwistedRootFirst(stations).map { it.name },
        )
        val withEmber = listOf(
            MenuStation("Ember", listOf(dish), "1878"),
            MenuStation("Sizzle Grill", listOf(dish)),
            MenuStation("The Twisted Root", listOf(dish), "1929"),
            MenuStation("Home", listOf(dish)),
            MenuStation("Available all day", listOf(dish)),
        )
        assertEquals(
            listOf("The Twisted Root", "Sizzle Grill", "Home", "Available all day", "Ember"),
            DiningLogic.pinTwistedRootFirst(withEmber).map { it.name },
        )
        assertTrue(DiningLogic.isEmber("Menu", "1878"))
        assertFalse(DiningLogic.isEmber("September Grill"))
        assertEquals("The Twisted Root", DiningLogic.displayStationName(null, "1929"))
        assertEquals("The Twisted Root", DiningLogic.displayStationName(null, "1893"))
    }

    @Test
    fun clockAndWeekendBrunchSnap() {
        assertEquals("Breakfast", DiningLogic.clockPill(10 * 60 + 30))
        assertEquals("Lunch", DiningLogic.clockPill(12 * 60))
        assertEquals("Dinner", DiningLogic.clockPill(16 * 60))
        val brunch = listOf(MealPeriodWindow("Brunch", 11 * 60, 16 * 60 + 30))
        assertEquals("Lunch", DiningLogic.autoPill(brunch, 12 * 60))
        assertEquals("Dinner", DiningLogic.autoPill(brunch, 15 * 60))
        val weekday = listOf(
            MealPeriodWindow("Lunch", 11 * 60, 14 * 60 + 30),
            MealPeriodWindow("Afternoon Snack", 14 * 60 + 30, 16 * 60 + 30),
            MealPeriodWindow("Dinner", 16 * 60 + 30, 20 * 60),
            MealPeriodWindow("Evening Snack", 20 * 60, 23 * 60),
        )
        assertEquals("Afternoon Snack", DiningLogic.autoPill(weekday, 15 * 60))
        assertEquals("Dinner", DiningLogic.autoPill(weekday, 18 * 60))
        assertEquals("Late Night", DiningLogic.autoPill(weekday, 21 * 60))
        val untimedSnack = listOf(
            MealPeriodWindow("Lunch", 11 * 60, 14 * 60 + 30),
            MealPeriodWindow("Afternoon Snack", null, null),
            MealPeriodWindow("Dinner", 16 * 60 + 30, 20 * 60),
        )
        assertEquals(
            "Afternoon Snack",
            DiningLogic.autoPill(untimedSnack, 15 * 60, listOf("Lunch", "Afternoon Snack", "Dinner")),
        )
        assertEquals("Dinner", DiningLogic.autoPill(brunch, 15 * 60, listOf("Breakfast", "Brunch", "Lunch", "Dinner")))
        assertEquals("Late Night", DiningLogic.canonicalPill("Evening Snack"))
        assertEquals("Afternoon Snack", DiningLogic.canonicalPill("Afternoon Snack"))
    }

    @Test
    fun servingSizeExpandsBareFl() {
        assertEquals("4 fl oz", DiningLogic.servingSize("4", "fl"))
        assertEquals("1 cup", DiningLogic.servingSize("1", "cup"))
    }

    @Test
    fun whitespaceAndChunks() {
        assertEquals("Banana Berry Smoothie", DiningLogic.collapseWhitespace("Banana  Berry Smoothie"))
        assertEquals(listOf(listOf("a", "b"), listOf("c", "d")), DiningLogic.chunks(listOf("a", "b", "c", "d"), 2))
        assertTrue(DiningLogic.chunks(emptyList(), 8).isEmpty())
    }

    @Test
    fun eatHallsAreThreeTilesWithOasisComingSoon() {
        val halls = DiningLogic.eatHalls(
            listOf(
                DiningLocation("brandywine", "Brandywine", "Brandywine", "Middle Earth", false, null, emptyList(), emptyList()),
                DiningLocation("anteatery", "The Anteatery", "Anteatery", "Mesa Court", true, "7:15 AM to 8:00 PM", listOf("Lunch"), emptyList()),
            ),
        )
        assertEquals(listOf("anteatery", "brandywine", "oasis"), halls.map { it.id })
        assertTrue(halls.last().isComingSoon)
        assertEquals("Oasis", halls.last().compactName)
    }

    @Test
    fun emptyCopyHasNoEmDash() {
        val copy = DiningLogic.emptyMenuCopy("Dinner", browsingFuture = false, comingSoon = false)
        assertFalse(copy.contains("\u2014") || copy.contains("\u2013"))
        assertTrue(copy.contains("dinner"))
    }
}

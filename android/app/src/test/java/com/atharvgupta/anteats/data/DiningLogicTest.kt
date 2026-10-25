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
        assertEquals(listOf("Lunch"), DiningLogic.menuPeriodNames("Lunch", weekend))
        assertEquals(listOf("Breakfast"), DiningLogic.menuPeriodNames("Breakfast", weekend))
        assertTrue(DiningLogic.menuPeriodNames("Lunch", listOf("Brunch", "Dinner")).isEmpty())
        assertFalse(DiningLogic.menuPeriodNames("Lunch", weekend).any { it.contains("All Day", true) })
        assertEquals("Brunch", DiningLogic.mealPillLabel("Breakfast", listOf("Brunch", "Dinner")))
        assertEquals("Lunch", DiningLogic.mealPillLabel("Lunch", listOf("Brunch", "Dinner")))
        assertEquals("Lunch", DiningLogic.mealPillLabel("Lunch", weekend))
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
            listOf("The Twisted Root", "Home", "Available all day", "Sizzle Grill"),
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
            listOf("The Twisted Root", "Home", "Available all day", "Ember", "Sizzle Grill"),
            DiningLogic.pinTwistedRootFirst(withEmber).map { it.name },
        )
        assertTrue(DiningLogic.isEmber("Menu", "1878"))
        assertTrue(DiningLogic.isStandingBurger("Menu", "1935"))
        assertTrue(DiningLogic.isStandingBurger("Sizzle Grill"))
        assertFalse(DiningLogic.isEmber("September Grill"))
        assertFalse(DiningLogic.isStandingBurger("September Grill"))
        assertEquals("The Twisted Root", DiningLogic.displayStationName(null, "1929"))
        assertEquals("The Twisted Root", DiningLogic.displayStationName(null, "1893"))
    }

    @Test
    fun ordersRotatingStationsBeforeDessertsAndStandingBurgers() {
        val dish = MenuItem("x", "Tofu", null, 200, null, emptyList(), listOf("Vegan"))
        val pizza = MenuItem("p", "Pepperoni Pizza", null, 300, null, emptyList(), emptyList())
        val flatbread = MenuItem("f", "Margherita Flatbread", null, 280, null, emptyList(), emptyList())
        fun station(name: String, id: String? = null, items: List<MenuItem> = listOf(dish)) =
            MenuStation(name, items, id)
        val anteateryLunch = listOf(
            station("Fire and Ice", "1926"),
            station("The Twisted Root", "1929"),
            station("Sizzle Grill", "1935"),
            station("Bakery", "1938"),
            station("Oven", "1941", listOf(pizza)),
            station("Soups", "1944"),
            station("Farmer's Market", "1947"),
            station("Noodle Bar", "1953"),
        )
        assertEquals(
            listOf(
                "The Twisted Root",
                "Fire and Ice",
                "Noodle Bar",
                "Soups",
                "Farmer's Market",
                "Bakery",
                "Oven",
                "Sizzle Grill",
            ),
            DiningLogic.pinTwistedRootFirst(anteateryLunch).map { it.name },
        )
        val brandywineLunch = listOf(
            station("Honeycakes", "1872"),
            station("Ember", "1878"),
            station("Grubb", "1881"),
            station("Hearth", "1884", listOf(pizza, flatbread)),
            station("Compass", "1887"),
            station("Crossroads", "1890"),
            station("The Twisted Root", "1893"),
            station("Soups", "1896"),
            station("Saute", "1899"),
        )
        assertEquals(
            listOf(
                "The Twisted Root",
                "Grubb",
                "Compass",
                "Crossroads",
                "Saute",
                "Soups",
                "Honeycakes",
                "Hearth",
                "Ember",
            ),
            DiningLogic.pinTwistedRootFirst(brandywineLunch).map { it.name },
        )
        val oasis = listOf(
            station("Oasis Wok"),
            station("Burger Bar"),
            station("Pizza"),
            station("Sweets"),
            station("The Twisted Root"),
            station("The Farm Stand- Salad"),
        )
        assertEquals(
            listOf(
                "The Twisted Root",
                "Oasis Wok",
                "The Farm Stand- Salad",
                "Sweets",
                "Pizza",
                "Burger Bar",
            ),
            DiningLogic.pinTwistedRootFirst(oasis).map { it.name },
        )
        assertEquals(DiningLogic.StationLane.SIDES, DiningLogic.stationLane("Deli"))
        assertEquals(DiningLogic.StationLane.DESSERT, DiningLogic.stationLane("Bakery", "1938"))
        assertEquals(DiningLogic.StationLane.STANDING_BURGER, DiningLogic.stationLane("Menu", "1878"))
        assertEquals(DiningLogic.StationLane.HOT_ENTREE, DiningLogic.stationLane("September Grill"))
        assertEquals(
            DiningLogic.StationLane.PIZZA,
            DiningLogic.stationLane("Oven", "1941", listOf(pizza)),
        )
        assertEquals(
            DiningLogic.StationLane.HOT_ENTREE,
            DiningLogic.stationLane("Oven", "1941", listOf(dish)),
        )
        assertTrue(DiningLogic.isPizzaStation("Pizza"))
        assertFalse(DiningLogic.isPizzaStation("Oven", "1941", listOf(dish)))
    }

    @Test
    fun clockAndWeekendBrunchSnap() {
        assertEquals("Breakfast", DiningLogic.clockPill(10 * 60 + 30))
        assertEquals("Lunch", DiningLogic.clockPill(12 * 60))
        assertEquals("Dinner", DiningLogic.clockPill(16 * 60))
        val brunch = listOf(MealPeriodWindow("Brunch", 11 * 60, 16 * 60 + 30))
        assertEquals("Lunch", DiningLogic.autoPill(brunch, 12 * 60))
        assertEquals("Breakfast", DiningLogic.autoPill(brunch, 12 * 60, listOf("Brunch", "Dinner")))
        assertEquals(
            "Lunch",
            DiningLogic.autoPill(
                listOf(MealPeriodWindow("Breakfast", 7 * 60 + 15, 11 * 60)),
                11 * 60 + 40,
                listOf("Breakfast"),
            ),
        )
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
        assertEquals("Menu not posted", halls.last().comingSoonSubtitle)
        assertEquals("Oasis", halls.last().compactName)
    }

    @Test
    fun eatHallsKeepAnteaterApiOasisWhenItHasAMenu() {
        val liveOasis = DiningLocation(
            "oasis",
            "The Oasis",
            "Oasis",
            "Mesa Court",
            true,
            "11:00 AM to 2:30 PM",
            listOf("Lunch"),
            listOf(MealPeriodWindow("Lunch", 11 * 60, 14 * 60 + 30)),
        )
        val halls = DiningLogic.eatHalls(
            listOf(
                DiningLocation("anteatery", "The Anteatery", "Anteatery", "Mesa Court", true, null, listOf("Lunch"), emptyList()),
                DiningLocation("brandywine", "Brandywine", "Brandywine", "Middle Earth", false, null, listOf("Lunch"), emptyList()),
                liveOasis,
            ),
        )
        assertEquals(listOf("anteatery", "brandywine", "oasis"), halls.map { it.id })
        assertFalse(halls.last().isComingSoon)
        assertEquals(listOf("Lunch"), halls.last().availablePeriods)
    }

    @Test
    fun emptyCopyHasNoEmDash() {
        val copy = DiningLogic.emptyMenuCopy("Dinner", browsingFuture = false, comingSoon = false)
        assertFalse(copy.contains("\u2014") || copy.contains("\u2013"))
        assertTrue(copy.contains("dinner"))
        val closed = DiningLogic.emptyMenuCopy("Lunch", browsingFuture = false, comingSoon = true)
        assertTrue(closed.contains("menu not posted") || closed.contains("UCI has not posted a menu") || closed.contains("Closed today"))
        assertFalse(closed.contains("Oct"))
        assertFalse(closed.contains("Coming Soon", ignoreCase = true))
        assertFalse(closed.contains("\u2014") || closed.contains("\u2013"))
    }

    @Test
    fun lunchFavoritesSkipBrunchTwistedRootPancakes() {
        val pancakes = MenuItem("p", "Home-Style Pancakes", null, 320, null, emptyList(), emptyList(), stationID = "1893")
        val scramble = MenuItem("s", "Turmeric Tofu Scramble", null, 180, null, emptyList(), emptyList(), stationID = "1893")
        val tofu = MenuItem("t", "General Tso's Tofu", null, 400, null, emptyList(), emptyList(), stationID = "1893")
        val burger = MenuItem("b", "Cheeseburger", null, 500, null, emptyList(), emptyList(), stationID = "1878")
        val stations = listOf(
            MenuStation("The Twisted Root", listOf(pancakes, scramble, tofu), "1893"),
            MenuStation("Ember", listOf(burger), "1878"),
        )
        val served = DiningLogic.favoriteItemsOnBoard(
            stations,
            listOf("Home-Style Pancakes", "General Tso's Tofu", "Cheeseburger"),
            "Lunch",
        )
        assertEquals(listOf("General Tso's Tofu", "Cheeseburger"), served.map { it.name })
        assertTrue(
            DiningLogic.favoriteItemsOnBoard(stations, listOf("Home-Style Pancakes"), "Lunch").isEmpty(),
        )
        assertEquals(
            listOf("Home-Style Pancakes"),
            DiningLogic.favoriteItemsOnBoard(stations, listOf("Home-Style Pancakes"), "Breakfast").map { it.name },
        )
        assertEquals("Favorites today", DiningLogic.favoritesSectionTitle("2026-10-17", "2026-10-17"))
        assertEquals("Favorites on Sunday", DiningLogic.favoritesSectionTitle("2026-10-18", "2026-10-17"))
    }

    @Test
    fun lunchFavoritesSkipBreakfastOnlyAllDay() {
        val eggs = MenuItem("eggs", "Scrambled Eggs", null, 140, null, emptyList(), emptyList())
        val bowl = MenuItem("bowl", "Teriyaki Bowl", null, 520, null, emptyList(), emptyList())
        val fries = MenuItem("fries", "Seasoned Fries", null, 280, null, emptyList(), emptyList())
        val stations = listOf(
            MenuStation("Grill", listOf(bowl)),
            MenuStation("Available all day", listOf(eggs, fries)),
        )
        val served = DiningLogic.favoriteItemsOnBoard(
            stations,
            listOf("Scrambled Eggs", "Teriyaki Bowl", "Seasoned Fries"),
        )
        assertEquals(listOf("Teriyaki Bowl"), served.map { it.name })
    }

    @Test
    fun lunchDropsBreakfastOnlyBrunchDishes() {
        val eggs = MenuItem("eggs", "Judy's BBQ Eggs", null, 140, null, emptyList(), emptyList())
        val oatmeal = MenuItem("oats", "Oatmeal", null, 150, null, emptyList(), emptyList())
        val burger = MenuItem("burger", "Cheeseburger", null, 400, null, emptyList(), emptyList())
        val taco = MenuItem("taco", "Sesame Shrimp Taco", null, 320, null, emptyList(), emptyList())
        val breakfast = listOf(MenuStation("Home", listOf(eggs, oatmeal)))
        val lunch = listOf(MenuStation("Ember", listOf(burger)))
        val brunch = listOf(
            MenuStation("Home", listOf(eggs, oatmeal)),
            MenuStation("Ember", listOf(burger)),
            MenuStation("Crossroads", listOf(taco)),
        )
        val filtered = DiningLogic.subtractingBreakfastOnlyBrunchDishes(
            from = DiningLogic.mergeStations(listOf(lunch, brunch)),
            lunch = lunch,
            breakfast = breakfast,
        )
        val names = filtered.flatMap { it.items }.map { it.name }
        assertTrue(names.contains("Sesame Shrimp Taco"))
        assertTrue(names.contains("Cheeseburger"))
        assertFalse(names.contains("Judy's BBQ Eggs"))
        assertFalse(names.contains("Oatmeal"))
    }
}

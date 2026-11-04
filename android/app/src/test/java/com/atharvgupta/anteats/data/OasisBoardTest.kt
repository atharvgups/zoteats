package com.atharvgupta.anteats.data

import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertNull
import org.junit.Assert.assertTrue
import org.junit.Test

class OasisBoardTest {
    private fun item(id: String, name: String, stationID: String? = null) = MenuItem(
        id, name, null, 100, null, emptyList(), emptyList(), stationID = stationID,
    )

    @Test
    fun groupsHubSkusUnderRealStationNames() {
        val products = mapOf(
            "chicken" to item("chicken", "Mesquite Chicken", "306552"),
            "mac" to item("mac", "Mac & Cheese", "306552"),
            "peas" to item("peas", "Steamed Green Peas", "306552"),
            "pizza" to item("pizza", "Pepperoni Pizza", "306564"),
            "sandwich" to item("sandwich", "Grilled Chicken Sandwich", "306558"),
            "lettuce" to item("lettuce", "Green Leaf Lettuce", "306558"),
            "soup" to item("soup", "Tomato Basil Soup", "306555"),
            "cookie" to item("cookie", "Sugar Cookie", "306561"),
            "ravioli" to item("ravioli", "Baked Cheese Ravioli", "306567"),
        )
        val board = OasisBoard.postedBoard(
            listOf(
                "Lunch" to products.keys.toList(),
                "Dinner" to listOf("chicken", "pizza", "sandwich"),
                "All Day" to products.keys.toList(),
                "Brunch" to products.keys.toList(),
            ),
            listOf(
                "306552" to listOf("chicken", "mac", "peas"),
                "306555" to listOf("soup"),
                "306558" to listOf("sandwich", "lettuce", "lettuce"),
                "306561" to listOf("cookie"),
                "306564" to listOf("pizza"),
                "306567" to listOf("ravioli"),
            ),
            OasisBoard.directory(),
            products,
        )
        assertEquals(listOf("Lunch", "Dinner"), board.availablePeriods)
        assertFalse(board.stationsByPeriod.containsKey("Brunch"))
        val lunch = board.stations("Lunch")
        assertEquals(
            listOf("Main", "Salad & Soup", "Grill/Deli", "Desserts", "Pizza", "Saute"),
            lunch.map { it.name },
        )
        assertEquals(listOf("Mesquite Chicken", "Mac & Cheese", "Steamed Green Peas"), lunch[0].items.map { it.name })
        assertEquals("Kiosk order only", lunch.first { it.name == "Pizza" }.serviceLabel)
        assertEquals("Kiosk order only", lunch.first { it.name == "Grill/Deli" }.serviceLabel)
        assertEquals("Grab and go", lunch.first { it.name == "Main" }.serviceLabel)
        assertEquals("Grab and go", lunch.first { it.name == "Salad & Soup" }.serviceLabel)
        assertEquals("Grab and go", lunch.first { it.name == "Desserts" }.serviceLabel)
        assertEquals("Grab and go", lunch.first { it.name == "Saute" }.serviceLabel)
        assertEquals(listOf("Main", "Grill/Deli", "Pizza"), board.stations("Dinner").map { it.name })
    }

    @Test
    fun dropsPeasOnlyHotLine() {
        val stations = OasisBoard.stationsForPeriod(
            listOf("peas", "pizza"),
            listOf("306552" to listOf("peas"), "306564" to listOf("pizza")),
            OasisBoard.directory(),
            mapOf(
                "peas" to item("peas", "Steamed Green Peas", "306552"),
                "pizza" to item("pizza", "Classic Cheese Pizza", "306564"),
            ),
        )
        assertEquals(listOf("Pizza"), stations.map { it.name })
    }

    @Test
    fun hoursSkipFridayDinnerWeekendsAndVeteransDay() {
        assertEquals(listOf("Lunch", "Dinner"), OasisSchedule.mealWindows("2026-11-04", "Thursday").map { it.name })
        assertEquals(listOf("Lunch"), OasisSchedule.mealWindows("2026-11-06", "Friday").map { it.name })
        assertTrue(OasisSchedule.mealWindows("2026-11-07", "Saturday").isEmpty())
        assertTrue(OasisSchedule.mealWindows("2026-11-11", "Wednesday").isEmpty())
        assertEquals(
            "11:00 AM to 2:00 PM, 4:30 PM to 8:00 PM",
            OasisSchedule.todayHours("2026-11-04", "Thursday"),
        )
        assertEquals(
            listOf("Lunch"),
            OasisSchedule.servingPeriods(listOf("Lunch", "Dinner", "Brunch"), "2026-11-06", "Friday"),
        )
    }

    @Test
    fun anteateryStationOrderUnchanged() {
        val anteatery = listOf(
            MenuStation("Sizzle Grill", listOf(item("b", "Burger")), "1935"),
            MenuStation("The Twisted Root", listOf(item("t", "Tofu")), "1929"),
            MenuStation("Oven", listOf(item("p", "Cheese Pizza")), "1941"),
        )
        assertEquals(
            listOf("The Twisted Root", "Oven", "Sizzle Grill"),
            DiningLogic.orderedStations(anteatery, "anteatery").map { it.name },
        )
        val oasis = listOf(
            MenuStation("Main", listOf(item("c", "Chicken")), "306552", "Grab and go"),
            MenuStation("Pizza", listOf(item("p", "Pepperoni Pizza")), "306564", "Kiosk order only"),
        )
        assertEquals(listOf("Main", "Pizza"), DiningLogic.orderedStations(oasis, "oasis").map { it.name })

        val hubOrder = listOf(
            MenuStation("Main", listOf(item("c", "Chicken")), "306552", "Grab and go"),
            MenuStation("Salad & Soup", listOf(item("s", "Soup")), "306555", "Grab and go"),
            MenuStation("Grill/Deli", listOf(item("g", "Sandwich")), "306558", "Kiosk order only"),
            MenuStation("Desserts", listOf(item("d", "Cookie")), "306561", "Grab and go"),
            MenuStation("Pizza", listOf(item("p", "Pepperoni Pizza")), "306564", "Kiosk order only"),
            MenuStation("Saute", listOf(item("r", "Ravioli")), "306567", "Grab and go"),
        )
        assertEquals(hubOrder.map { it.name }, DiningLogic.orderedStations(hubOrder, "oasis").map { it.name })
        assertTrue(DiningLogic.pinTwistedRootFirst(hubOrder).map { it.name } != hubOrder.map { it.name })
        assertEquals("Kiosk order only", OasisBoard.serviceLabel("Pizza"))
        assertEquals("Kiosk order only", OasisBoard.serviceLabel("Grill/Deli"))
        assertEquals("Grab and go", OasisBoard.serviceLabel("Main"))
        assertNull(OasisBoard.serviceLabel(""))
        assertNull(MenuStation("Deli", listOf(item("t", "Turkey")), "1950").serviceLabel)
    }
}

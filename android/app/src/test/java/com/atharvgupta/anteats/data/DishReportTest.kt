package com.atharvgupta.anteats.data

import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Test

class DishReportTest {
    @Test
    fun keysByDateHallMealAndDishID() {
        val first = DishReportLogic.upsert(
            existing = emptyList(),
            date = "2026-10-28",
            hall = "anteatery",
            meal = "Lunch",
            dishID = "1923_linguine",
            dishName = "Thai Curry Plant-Based Chicken Linguine",
            reason = DishReportReason.NOT_AT_HALL,
            authorID = "a",
            updatedAt = "2026-10-28T19:00:00Z",
        )
        val otherHall = DishReportLogic.upsert(
            existing = first,
            date = "2026-10-28",
            hall = "brandywine",
            meal = "Lunch",
            dishID = "1923_linguine",
            dishName = "Thai Curry Plant-Based Chicken Linguine",
            reason = DishReportReason.NOT_AT_HALL,
            authorID = "a",
            updatedAt = "2026-10-28T19:01:00Z",
        )
        assertEquals(2, otherHall.size)
        assertFalse(
            DishReportLogic.isReportedMissing(
                otherHall,
                "2026-10-28",
                "anteatery",
                "Lunch",
                "1923_linguine",
            ),
        )
    }

    @Test
    fun twoAuthorsTriggerReportedMissing() {
        var reports = DishReportLogic.upsert(
            existing = emptyList(),
            date = "2026-10-28",
            hall = "The-Anteatery",
            meal = "lunch",
            dishID = "sku-1",
            dishName = "Jasmine Rice",
            reason = DishReportReason.NOT_SERVED,
            authorID = "one",
            updatedAt = "1",
        )
        assertFalse(
            DishReportLogic.isReportedMissing(reports, "2026-10-28", "anteatery", "Lunch", "sku-1"),
        )
        reports = DishReportLogic.upsert(
            existing = reports,
            date = "2026-10-28",
            hall = "anteatery",
            meal = "Lunch",
            dishID = "sku-1",
            dishName = "Jasmine Rice",
            reason = DishReportReason.WRONG_STATION,
            authorID = "two",
            updatedAt = "2",
        )
        assertTrue(
            DishReportLogic.isReportedMissing(
                reports,
                "2026-10-28",
                "anteatery",
                "Lunch",
                "sku-1",
                "Jasmine Rice",
            ),
        )
        assertEquals(2, DishReportLogic.uniqueAuthorCount(reports, "2026-10-28", "anteatery", "Lunch", "sku-1"))
    }

    @Test
    fun sameAuthorUpsertsReasonWithoutRaisingCount() {
        var reports = DishReportLogic.upsert(
            existing = emptyList(),
            date = "2026-10-28",
            hall = "brandywine",
            meal = "Lunch",
            dishID = "1821_122168_M21043_1_18410",
            dishName = "Thai Curry Plant-Based Chicken Linguine",
            reason = DishReportReason.NOT_AT_HALL,
            authorID = "me",
            updatedAt = "1",
        )
        reports = DishReportLogic.upsert(
            existing = reports,
            date = "2026-10-28",
            hall = "brandywine",
            meal = "Lunch",
            dishID = "1821_122168_M21043_1_18410",
            dishName = "Thai Curry Plant-Based Chicken Linguine",
            reason = DishReportReason.WRONG_STATION,
            authorID = "me",
            updatedAt = "2",
        )
        assertEquals(1, reports.size)
        assertEquals(DishReportReason.WRONG_STATION, reports[0].reason)
        assertFalse(
            DishReportLogic.isReportedMissing(
                reports,
                "2026-10-28",
                "brandywine",
                "Lunch",
                "1821_122168_M21043_1_18410",
            ),
        )
    }

    @Test
    fun leavingMenuUnchangedNeverMovesDishes() {
        val linguine = MenuItem(
            "1821_122168_M21043_1_18410",
            "Thai Curry Plant-Based Chicken Linguine",
            null,
            400,
            null,
            emptyList(),
            listOf("Vegan"),
            stationID = "1893",
        )
        val rice = MenuItem(
            "1923_101628_M9650_1_11343",
            "Jasmine Rice",
            null,
            150,
            null,
            emptyList(),
            listOf("Vegan"),
            stationID = "1929",
        )
        val brandywine = DiningMenu(
            "brandywine",
            "2026-10-28",
            "Lunch",
            listOf(MenuStation("The Twisted Root", listOf(linguine), "1893")),
        )
        val anteatery = DiningMenu(
            "anteatery",
            "2026-10-28",
            "Lunch",
            listOf(MenuStation("The Twisted Root", listOf(rice), "1929")),
        )
        assertEquals(brandywine, DishReportLogic.leavingMenuUnchanged(brandywine))
        assertEquals(anteatery, DishReportLogic.leavingMenuUnchanged(anteatery))
        assertEquals(listOf("Thai Curry Plant-Based Chicken Linguine"), brandywine.stations[0].items.map { it.name })
        assertEquals(listOf("Jasmine Rice"), anteatery.stations[0].items.map { it.name })
    }

    @Test
    fun copyHasNoEmDashes() {
        val copy = listOf(
            DishReportCopy.rowTitle,
            DishReportCopy.sheetTitle,
            DishReportCopy.notAtHall,
            DishReportCopy.notServed,
            DishReportCopy.wrongStation,
            DishReportCopy.thanks,
            DishReportCopy.missingNote,
            DishReportCopy.cancel,
        ).joinToString("")
        assertFalse(copy.contains("\u2014"))
        assertFalse(copy.contains("\u2013"))
        assertEquals("Thanks, noted", DishReportCopy.thanks)
        assertEquals("Report an issue", DishReportCopy.rowTitle)
        assertEquals(2, DishReportLogic.missingThreshold)
        assertEquals("oasis", DishReportLogic.canonicalHall("the-oasis-dining-hall"))
        assertEquals("Late Night", DishReportLogic.canonicalMeal("Evening Snack"))
    }

    @Test
    fun encodeRoundTripKeepsListingKey() {
        val reports = DishReportLogic.upsert(
            existing = emptyList(),
            date = "2026-10-28",
            hall = "anteatery",
            meal = "Lunch",
            dishID = "rice",
            dishName = "Jasmine Rice",
            reason = DishReportReason.NOT_SERVED,
            authorID = "a",
            updatedAt = "2026-10-28T19:00:00Z",
        )
        val decoded = DishReportFeed.decode(DishReportFeed.encode(reports))
        assertEquals(1, decoded.size)
        assertEquals("rice", decoded[0].dishID)
        assertEquals("a", decoded[0].authorID)
    }
}

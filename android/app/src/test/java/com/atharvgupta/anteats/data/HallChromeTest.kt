package com.atharvgupta.anteats.data

import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Test

class HallChromeTest {
    @Test
    fun openHallSaysUntilClock() {
        val hall = DiningLocation(
            id = "anteatery",
            name = "The Anteatery",
            compactName = "Anteatery",
            area = "Mesa Court",
            openNow = true,
            todayHours = "7:15 AM to 8:00 PM",
            availablePeriods = listOf("Lunch"),
            periods = listOf(MealPeriodWindow("Lunch", 11 * 60, 20 * 60)),
        )
        val status = HallChrome.status(hall, nowMinutes = 12 * 60, todayISO = "2026-10-01")
        assertEquals("until 8 PM", status.primary)
        assertEquals(HallTone.Open, status.tone)
    }

    @Test
    fun closedHallSaysOpensClock() {
        val hall = DiningLocation(
            id = "brandywine",
            name = "Brandywine",
            compactName = "Brandywine",
            area = "Middle Earth",
            openNow = false,
            todayHours = null,
            availablePeriods = listOf("Dinner"),
            periods = listOf(MealPeriodWindow("Dinner", 16 * 60 + 30, 20 * 60)),
        )
        val status = HallChrome.status(hall, nowMinutes = 10 * 60, todayISO = "2026-10-01")
        assertEquals("opens 4:30 PM", status.primary)
        assertEquals(HallTone.Muted, status.tone)
    }

    @Test
    fun oasisPlaceholderDinnerSaysMenuNotPosted() {
        val hall = OasisSchedule.comingSoonLocation("2026-10-22", nowMinutes = 16 * 60 + 56)
        val status = HallChrome.status(hall, nowMinutes = 16 * 60 + 56, todayISO = "2026-10-22")
        assertEquals("Menu not posted", status.primary)
        assertEquals(HallTone.Open, status.tone)
        assertEquals("Menu not posted", hall.comingSoonSubtitle)
        assertTrue(hall.openNow)
        assertTrue(hall.periods.map { it.name }.containsAll(listOf("Lunch", "Afternoon Snack", "Dinner")))
        assertFalse(status.primary.contains("Oct"))
        assertFalse(status.primary.contains("Coming Soon", ignoreCase = true))
        assertFalse(status.primary.contains("\u2014") || status.primary.contains("\u2013"))
        assertEquals("Open, menu not posted.", OasisSchedule.selectedLine("2026-10-22", "Thursday", 16 * 60 + 56))
    }

    @Test
    fun oasisPlaceholderBeforeLunchSaysOpens() {
        val hall = OasisSchedule.comingSoonLocation("2026-10-22", nowMinutes = 10 * 60)
        val status = HallChrome.status(hall, nowMinutes = 10 * 60, todayISO = "2026-10-22")
        assertEquals("opens 11 AM", status.primary)
        assertEquals(HallTone.Muted, status.tone)
        assertFalse(hall.openNow)
    }

    @Test
    fun oasisFromApiWithMenuShowsUntilClock() {
        val hall = DiningLocation(
            id = "oasis",
            name = "The Oasis",
            compactName = "Oasis",
            area = "Mesa Court",
            openNow = true,
            todayHours = "11:00 AM to 2:30 PM",
            availablePeriods = listOf("Lunch"),
            periods = listOf(MealPeriodWindow("Lunch", 11 * 60, 14 * 60 + 30)),
        )
        val status = HallChrome.status(hall, nowMinutes = 12 * 60, todayISO = "2026-10-16")
        assertEquals("until 2:30 PM", status.primary)
        assertEquals(HallTone.Open, status.tone)
    }
}

class CampusCategorizeTest {
    @Test
    fun coffeeFoodAndMarkets() {
        val repo = CampusRepository()
        assertEquals("Coffee & Cafes", repo.categorize("Starbucks at the Student Center"))
        assertEquals("Markets", repo.categorize("Zot n Go"))
        assertEquals("Restaurants & Pubs", repo.categorize("Anthill Pub"))
        assertEquals("Food Courts", repo.categorize("Panda Express"))
        assertEquals(true, repo.typeMatches("Coffee", "Coffee & Cafes"))
        assertEquals(true, repo.typeMatches("Food", "Food Courts"))
        assertEquals(false, repo.typeMatches("Markets", "Coffee & Cafes"))
    }
}

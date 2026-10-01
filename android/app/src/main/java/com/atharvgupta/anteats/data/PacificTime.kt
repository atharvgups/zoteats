package com.atharvgupta.anteats.data

import java.time.LocalDate
import java.time.ZoneId
import java.time.ZonedDateTime
import java.time.format.DateTimeFormatter
import java.util.Locale

object PacificTime {
    val zone: ZoneId = ZoneId.of("America/Los_Angeles")
    private val isoDay: DateTimeFormatter = DateTimeFormatter.ISO_LOCAL_DATE
    private val weekday: DateTimeFormatter = DateTimeFormatter.ofPattern("EEEE", Locale.US)
    private val weekdayShort: DateTimeFormatter = DateTimeFormatter.ofPattern("EEE", Locale.US)
    private val monthDay: DateTimeFormatter = DateTimeFormatter.ofPattern("MMM d", Locale.US)
    private val compactChip: DateTimeFormatter = DateTimeFormatter.ofPattern("EEE d", Locale.US)

    fun now(): ZonedDateTime = ZonedDateTime.now(zone)

    fun todayISO(now: ZonedDateTime = now()): String = now.toLocalDate().format(isoDay)

    fun nowMinutes(now: ZonedDateTime = now()): Int = now.hour * 60 + now.minute

    fun parseISO(iso: String): LocalDate? = runCatching { LocalDate.parse(iso, isoDay) }.getOrNull()

    fun addDays(iso: String, days: Int): String? =
        parseISO(iso)?.plusDays(days.toLong())?.format(isoDay)

    fun weekdayName(iso: String): String? = parseISO(iso)?.format(weekday)

    fun weekdayShort(iso: String): String? = parseISO(iso)?.format(weekdayShort)

    fun monthDay(iso: String): String? = parseISO(iso)?.format(monthDay)

    fun compactChip(iso: String): String? = parseISO(iso)?.format(compactChip)

    fun upcomingDays(count: Int, todayISO: String = todayISO()): List<String> {
        val start = parseISO(todayISO) ?: return emptyList()
        return (0 until count).map { start.plusDays(it.toLong()).format(isoDay) }
    }

    fun parseMinutes(time: String?): Int? {
        if (time.isNullOrBlank()) return null
        val parts = time.split(':').mapNotNull { it.toIntOrNull() }
        val hours = parts.firstOrNull() ?: return null
        val minutes = if (parts.size > 1) parts[1] else 0
        return hours * 60 + minutes
    }

    fun formatMinutes(mins: Int): String {
        val hour = mins / 60
        val minute = mins % 60
        val period = if (hour < 12 || hour == 24) "AM" else "PM"
        val display = if (hour % 12 == 0) 12 else hour % 12
        return if (minute == 0) "$display:00 $period" else "$display:${minute.toString().padStart(2, '0')} $period"
    }
}

object EatPostedDays {
    fun chipLabel(isoDate: String, todayISO: String): String {
        if (isoDate == todayISO) return "Today"
        if (PacificTime.addDays(todayISO, 1) == isoDate) return "Tomorrow"
        return PacificTime.compactChip(isoDate) ?: isoDate
    }

    fun visible(todayISO: String, horizon: Int = 14, latest: String? = null): List<EatPostedDay> {
        return PacificTime.upcomingDays(horizon, todayISO)
            .filter { latest == null || it <= latest }
            .map { EatPostedDay(isoDate = it, label = chipLabel(it, todayISO)) }
    }
}

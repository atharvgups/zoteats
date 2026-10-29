package com.atharvgupta.anteats.data

enum class HallTone { Open, Muted }

data class HallStatus(val primary: String, val tone: HallTone)

object HallChrome {
    fun compactClock(minutes: Int): String =
        PacificTime.formatMinutes(minutes % (24 * 60)).replace(":00 ", " ")

    fun status(location: DiningLocation, nowMinutes: Int, todayISO: String): HallStatus {
        if (location.isComingSoon) {
            return unpostedStatus(location, nowMinutes, todayISO)
        }
        val timed = location.periods.filter { it.startMinutes != null && it.endMinutes != null }
        val live = timed.firstOrNull {
            nowMinutes >= it.startMinutes!! && nowMinutes < it.endMinutes!!
        }
        if (live != null) {
            val clock = compactClock(live.endMinutes!!)
            return HallStatus("until $clock", HallTone.Open)
        }
        val upcoming = timed.filter { it.startMinutes!! > nowMinutes }.minByOrNull { it.startMinutes!! }
        if (upcoming != null) {
            return HallStatus("opens ${compactClock(upcoming.startMinutes!!)}", HallTone.Muted)
        }
        if (timed.isNotEmpty()) return HallStatus("Closed", HallTone.Muted)
        return HallStatus("Not posted", HallTone.Muted)
    }

    private fun unpostedStatus(location: DiningLocation, nowMinutes: Int, todayISO: String): HallStatus {
        val timed = location.periods.filter { it.startMinutes != null && it.endMinutes != null }
        val live = timed.firstOrNull {
            nowMinutes >= it.startMinutes!! && nowMinutes < it.endMinutes!!
        }
        if (live != null) {
            return HallStatus(OasisSchedule.unpostedCard, HallTone.Open)
        }
        val upcoming = timed.filter { it.startMinutes!! > nowMinutes }.minByOrNull { it.startMinutes!! }
        if (upcoming != null) {
            return HallStatus("opens ${compactClock(upcoming.startMinutes!!)}", HallTone.Muted)
        }
        val weekday = PacificTime.weekdayName(todayISO).orEmpty()
        if (OasisSchedule.mealWindows(todayISO, weekday).isEmpty()) {
            return HallStatus("Closed", HallTone.Muted)
        }
        return HallStatus(OasisSchedule.unpostedCard, HallTone.Muted)
    }
}

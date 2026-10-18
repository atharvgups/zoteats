package com.atharvgupta.anteats.data

enum class HallTone { Open, Muted }

data class HallStatus(val primary: String, val tone: HallTone)

object HallChrome {
    fun compactClock(minutes: Int): String =
        PacificTime.formatMinutes(minutes % (24 * 60)).replace(":00 ", " ")

    fun status(location: DiningLocation, nowMinutes: Int, todayISO: String): HallStatus {
        if (location.isComingSoon && todayISO < OasisSchedule.firstServiceISO) {
            return HallStatus(OasisSchedule.opensLine(), HallTone.Muted)
        }
        if (location.isComingSoon) {
            return HallStatus("Lunch & Dinner", HallTone.Muted)
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
}

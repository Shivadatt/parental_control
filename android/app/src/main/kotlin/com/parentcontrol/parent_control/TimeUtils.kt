package com.parentcontrol.parent_control

import java.text.SimpleDateFormat
import java.util.Calendar
import java.util.Date
import java.util.Locale
import java.util.TimeZone

/**
 * ISO-8601 helpers that work on API 24 (java.time is not available below API 26).
 * All values returned to Dart are UTC ISO strings or local day strings.
 */
object TimeUtils {
    private val isoPatterns = listOf(
        "yyyy-MM-dd'T'HH:mm:ss.SSSXXX",
        "yyyy-MM-dd'T'HH:mm:ssXXX",
        "yyyy-MM-dd'T'HH:mm:ss.SSS'Z'",
        "yyyy-MM-dd'T'HH:mm:ss'Z'",
        "yyyy-MM-dd'T'HH:mm:ss.SSS",
        "yyyy-MM-dd HH:mm:ss"
    )

    fun nowIso(): String {
        val format = SimpleDateFormat("yyyy-MM-dd'T'HH:mm:ss.SSS'Z'", Locale.US)
        format.timeZone = TimeZone.getTimeZone("UTC")
        return format.format(Date())
    }

    fun isoFromMillis(millis: Long): String {
        val format = SimpleDateFormat("yyyy-MM-dd'T'HH:mm:ss.SSS'Z'", Locale.US)
        format.timeZone = TimeZone.getTimeZone("UTC")
        return format.format(Date(millis))
    }

    /**
     * Accepts ISO-8601 timestamps from PostgREST, whose fractional seconds may
     * have more than three digits. SimpleDateFormat only understands exactly
     * three, so the fraction is normalized first instead of silently failing.
     */
    fun parseIso(value: String?): Long? {
        if (value.isNullOrBlank()) return null
        val normalized = normalizeFraction(value.trim())
        for (pattern in isoPatterns) {
            try {
                val format = SimpleDateFormat(pattern, Locale.US)
                format.isLenient = false
                val parsed = format.parse(normalized) ?: continue
                return parsed.time
            } catch (_: Exception) {
                // Try the next accepted representation.
            }
        }
        return null
    }

    private fun normalizeFraction(value: String): String {
        val start = value.indexOf('.')
        if (start < 0) return value
        var end = start + 1
        while (end < value.length && value[end].isDigit()) {
            end += 1
        }
        if (end == start + 1) return value
        val fraction = value.substring(start + 1, end)
        val millis = fraction.padEnd(3, '0').substring(0, 3)
        return value.substring(0, start + 1) + millis + value.substring(end)
    }

    fun localDayString(millis: Long): String {
        val format = SimpleDateFormat("yyyy-MM-dd", Locale.US)
        return format.format(Date(millis))
    }

    fun startOfLocalDay(millis: Long): Long {
        val calendar = Calendar.getInstance()
        calendar.timeInMillis = millis
        calendar.set(Calendar.HOUR_OF_DAY, 0)
        calendar.set(Calendar.MINUTE, 0)
        calendar.set(Calendar.SECOND, 0)
        calendar.set(Calendar.MILLISECOND, 0)
        return calendar.timeInMillis
    }

    fun addDays(millis: Long, days: Int): Long {
        val calendar = Calendar.getInstance()
        calendar.timeInMillis = millis
        calendar.add(Calendar.DAY_OF_YEAR, days)
        return calendar.timeInMillis
    }

    /** ISO weekday: Monday = 1 … Sunday = 7. */
    fun isoDayOfWeek(calendar: Calendar): Int = when (calendar.get(Calendar.DAY_OF_WEEK)) {
        Calendar.MONDAY -> 1
        Calendar.TUESDAY -> 2
        Calendar.WEDNESDAY -> 3
        Calendar.THURSDAY -> 4
        Calendar.FRIDAY -> 5
        Calendar.SATURDAY -> 6
        else -> 7
    }

    fun minuteOfDay(calendar: Calendar): Int =
        calendar.get(Calendar.HOUR_OF_DAY) * 60 + calendar.get(Calendar.MINUTE)
}

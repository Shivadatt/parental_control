package com.parentcontrol.parent_control

import android.app.usage.UsageStatsManager
import android.content.Context

class UsageAccessDeniedException : Exception("Usage access is not granted.")

data class UsageRow(
    val day: String,
    val packageName: String,
    val label: String,
    val totalMs: Long,
    val lastUsedAtMillis: Long?
)

/** Real UsageStatsManager data only; never fabricates values. */
object UsageReporter {
    fun hasAccess(context: Context): Boolean = NativePermissions.hasUsageAccess(context)

    @Throws(UsageAccessDeniedException::class)
    fun query(context: Context, startMillis: Long, endMillis: Long): List<UsageRow> {
        if (!hasAccess(context)) throw UsageAccessDeniedException()
        if (endMillis <= startMillis) return emptyList()
        val usageStatsManager = try {
            context.getSystemService(Context.USAGE_STATS_SERVICE) as UsageStatsManager
        } catch (_: Exception) {
            throw UsageAccessDeniedException()
        }

        data class Aggregate(
            val day: String,
            val packageName: String,
            var totalMs: Long,
            var lastUsedAt: Long?
        )

        val aggregates = LinkedHashMap<String, Aggregate>()
        var dayStart = TimeUtils.startOfLocalDay(startMillis)
        var iterations = 0
        while (dayStart < endMillis && iterations < 400) {
            val dayEnd = minOf(TimeUtils.addDays(dayStart, 1), endMillis)
            val stats = try {
                usageStatsManager.queryUsageStats(UsageStatsManager.INTERVAL_DAILY, dayStart, dayEnd)
            } catch (_: SecurityException) {
                throw UsageAccessDeniedException()
            } catch (_: Exception) {
                emptyList()
            }
            val day = TimeUtils.localDayString(dayStart)
            for (entry in stats ?: emptyList()) {
                val packageName = entry.packageName ?: continue
                val total = entry.totalTimeInForeground
                if (total <= 0L) continue
                val key = "$day|$packageName"
                val existing = aggregates[key]
                if (existing == null) {
                    val lastUsed = entry.lastTimeUsed.takeIf { it > 0L }
                    aggregates[key] = Aggregate(day, packageName, total, lastUsed)
                } else {
                    existing.totalMs += total
                    val lastUsed = entry.lastTimeUsed
                    if (lastUsed > 0L && (existing.lastUsedAt == null || lastUsed > existing.lastUsedAt!!)) {
                        existing.lastUsedAt = lastUsed
                    }
                }
            }
            dayStart = dayEnd
            iterations += 1
        }

        val labelCache = HashMap<String, String>()
        return aggregates.values
            .map { aggregate ->
                val label = labelCache.getOrPut(aggregate.packageName) {
                    appLabel(context, aggregate.packageName)
                }
                UsageRow(
                    day = aggregate.day,
                    packageName = aggregate.packageName,
                    label = label,
                    totalMs = aggregate.totalMs,
                    lastUsedAtMillis = aggregate.lastUsedAt
                )
            }
            .sortedWith(compareByDescending<UsageRow> { it.totalMs }.thenBy { it.packageName })
    }

    private fun appLabel(context: Context, packageName: String): String {
        return try {
            val packageManager = context.packageManager
            val info = packageManager.getApplicationInfo(packageName, 0)
            packageManager.getApplicationLabel(info).toString().ifBlank { packageName }
        } catch (_: Exception) {
            packageName
        }
    }
}

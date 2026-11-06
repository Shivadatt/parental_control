package com.parentcontrol.parent_control.policy

import com.parentcontrol.parent_control.EnforcementMode
import com.parentcontrol.parent_control.InstalledPackage
import com.parentcontrol.parent_control.UsageRow

/**
 * Outcome of one daily screen-time quota evaluation, carrying every field the
 * policy ack's `result.quota` object needs.
 */
data class QuotaDecision(
    val configured: Boolean = false,
    val usageAvailable: Boolean = false,
    val usageMinutes: Int? = null,
    val limitMinutes: Int? = null,
    val dayBucket: String? = null,
    val limitReached: Boolean = false,
    val action: String = QuotaEvaluator.ACTION_NONE,
    val targets: Set<String> = emptySet(),
    val applied: Set<String> = emptySet(),
    val desiredCount: Int = 0,
    val appliedCount: Int = 0,
    val failedCount: Int = 0,
    val enforcementSupported: Boolean = false,
    val enforcementMode: String = QuotaEvaluator.MODE_NONE,
    val reason: String? = null,
    val quotaActive: Boolean = false
)

/**
 * Pure daily screen-time quota decisions (DEC-12 D1-B), covered by JVM unit
 * tests. The day boundary is the device-local calendar day because that is the
 * bucket UsageReporter already measures; no family timezone reaches this
 * process. `totalTimeInForeground` remains the measurement primitive, so
 * split-screen, picture-in-picture and background audio attribution
 * (DEC-12 3.2.5) is still an open product question.
 */
object QuotaEvaluator {
    /** Server-side validator bound: `readInteger(..., 1, 1440)`. */
    const val MIN_LIMIT_MINUTES = 1
    const val MAX_LIMIT_MINUTES = 1440

    const val ACTION_NONE = "none"
    const val ACTION_ADVISORY = "advisory"
    const val ACTION_SUSPENDED = "suspended"
    const val ACTION_SUSPEND_FAILED = "suspend_failed"

    const val REASON_NOT_CONFIGURED = "quota_not_configured"
    const val REASON_USAGE_UNAVAILABLE = "quota_usage_unavailable"
    const val REASON_BELOW_LIMIT = "quota_below_limit"
    const val REASON_ADVISORY_ONLY = "quota_advisory_only"
    const val REASON_CONFIRMATION_MISSING = "quota_confirmation_missing"
    const val REASON_SUSPEND_FAILED = "quota_suspend_failed"

    const val MODE_DEVICE_OWNER = "device_owner"
    const val MODE_NONE = "none"

    private const val MILLIS_PER_MINUTE = 60_000L

    /** A limit outside 1..1440 is invalid and reported as not configured. */
    fun limitMinutes(limit: Int?): Int? =
        if (limit != null && limit in MIN_LIMIT_MINUTES..MAX_LIMIT_MINUTES) limit else null

    /**
     * Summed foreground minutes for one device-local day bucket. Saturates
     * instead of wrapping: a negative total would silently read as "below the
     * limit" and release a suspension. Null only when no day is known.
     */
    fun totalUsageMinutesToday(rows: List<UsageRow>, dayBucket: String): Int? {
        if (dayBucket.isBlank()) return null
        var totalMs = 0L
        for (row in rows) {
            if (row.day != dayBucket) continue
            val delta = row.totalMs
            if (delta <= 0L) continue
            totalMs = if (Long.MAX_VALUE - totalMs < delta) Long.MAX_VALUE else totalMs + delta
        }
        val minutes = totalMs / MILLIS_PER_MINUTE
        return if (minutes > Int.MAX_VALUE) Int.MAX_VALUE else minutes.toInt()
    }

    /** DEC-12 4.2 "all non-critical candidate packages". */
    fun quotaTargetPackages(
        installed: List<InstalledPackage>,
        ownPackage: String,
        protectedHome: String? = null,
        protectedIme: String? = null
    ): Set<String> {
        val targets = LinkedHashSet<String>()
        for (item in installed) {
            val packageName = item.packageName
            if (packageName.isBlank()) continue
            if (item.isSystem) continue
            if (PolicyGuard.isProtectedPackage(packageName, ownPackage, protectedHome, protectedIme)) {
                continue
            }
            targets.add(packageName)
        }
        return targets
    }

    /** At the limit already counts as reached. */
    fun isLimitReached(usageMinutes: Int?, limitMinutes: Int?): Boolean {
        if (usageMinutes == null || limitMinutes == null) return false
        return usageMinutes >= limitMinutes
    }

    /**
     * Only a strictly forward ISO date is a new local day. An equal or earlier
     * bucket must never re-arm or double-count the daily counter, which is what
     * keeps a DST shift, a timezone change or a clock rollback from handing out
     * extra screen time.
     */
    fun advanceDayBucket(previousBucket: String?, currentBucket: String): Boolean {
        if (previousBucket.isNullOrBlank()) return false
        if (currentBucket.isBlank()) return false
        return currentBucket > previousBucket
    }

    /**
     * The local day a quota suspension is recorded for. While a quota is active
     * the recorded day only ever moves forward.
     */
    fun resolvedDayBucket(
        persistedDayBucket: String?,
        currentDayBucket: String,
        quotaActive: Boolean
    ): String? {
        if (!quotaActive) return null
        if (!advanceDayBucket(persistedDayBucket, currentDayBucket)) {
            return persistedDayBucket ?: currentDayBucket.takeIf { it.isNotBlank() }
        }
        return currentDayBucket
    }

    /**
     * Packages the quota wants suspended for this evaluation. Empty in Standard
     * Mode: an advisory verdict must never reach the suspension machinery.
     */
    fun quotaSuspensionTargets(
        configured: Boolean,
        usageAvailable: Boolean,
        usageMinutes: Int?,
        limitMinutes: Int?,
        isManaged: Boolean,
        targetPackages: Set<String>
    ): Set<String> {
        if (!configured || !usageAvailable || !isManaged) return emptySet()
        val validatedLimit = QuotaEvaluator.limitMinutes(limitMinutes) ?: return emptySet()
        if (!isLimitReached(usageMinutes, validatedLimit)) return emptySet()
        return targetPackages
    }

    fun decide(
        configured: Boolean,
        usageAvailable: Boolean,
        usageMinutes: Int?,
        limitMinutes: Int?,
        dayBucket: String,
        isManaged: Boolean,
        targetPackages: Set<String>,
        alreadySuspended: (String) -> Boolean,
        persistedDayBucket: String? = null,
        confirmationAvailable: Boolean = true
    ): QuotaDecision {
        val validatedLimit = QuotaEvaluator.limitMinutes(limitMinutes)
        val effectiveConfigured = configured && validatedLimit != null
        val effectiveLimit = if (effectiveConfigured) validatedLimit else null
        val reached = effectiveConfigured && usageAvailable &&
            isLimitReached(usageMinutes, effectiveLimit)
        val targets = if (effectiveConfigured && usageAvailable && isManaged && reached) {
            targetPackages
        } else {
            emptySet()
        }
        val applied = if (targets.isEmpty()) emptySet() else targets.filter(alreadySuspended).toSet()
        val desiredCount = targets.size
        val appliedCount = applied.size
        val failedCount = (desiredCount - appliedCount).coerceAtLeast(0)
        val quotaActive = effectiveConfigured && reached
        val enforcementSupported = isManaged && confirmationAvailable && appliedCount == desiredCount
        val enforcementMode = quotaEnforcementMode(isManaged)

        var action = ACTION_NONE
        var reason: String? = when {
            !effectiveConfigured -> REASON_NOT_CONFIGURED
            !usageAvailable -> REASON_USAGE_UNAVAILABLE
            !reached -> REASON_BELOW_LIMIT
            else -> null
        }
        if (quotaActive) {
            when {
                !isManaged -> {
                    action = ACTION_ADVISORY
                    reason = REASON_ADVISORY_ONLY
                }
                !confirmationAvailable -> {
                    action = ACTION_SUSPEND_FAILED
                    reason = REASON_CONFIRMATION_MISSING
                }
                appliedCount == desiredCount && desiredCount > 0 -> {
                    action = ACTION_SUSPENDED
                    reason = null
                }
                else -> {
                    action = ACTION_SUSPEND_FAILED
                    // Zero eligible packages is not a provable success either.
                    reason = if (appliedCount > 0) {
                        "quota_suspended $appliedCount of $desiredCount"
                    } else {
                        REASON_SUSPEND_FAILED
                    }
                }
            }
        }

        return QuotaDecision(
            configured = effectiveConfigured,
            usageAvailable = usageAvailable,
            usageMinutes = if (usageAvailable) usageMinutes else null,
            limitMinutes = effectiveLimit,
            dayBucket = resolvedDayBucket(persistedDayBucket, dayBucket, quotaActive) ?: dayBucket.takeIf {
                it.isNotBlank()
            },
            limitReached = reached,
            action = action,
            targets = targets,
            applied = applied,
            desiredCount = desiredCount,
            appliedCount = appliedCount,
            failedCount = failedCount,
            enforcementSupported = enforcementSupported,
            enforcementMode = enforcementMode,
            reason = reason,
            quotaActive = quotaActive
        )
    }

    /** Verdict for acks built without a quota evaluation, e.g. policy restore. */
    fun notConfigured(isManaged: Boolean, dayBucket: String?): QuotaDecision = QuotaDecision(
        configured = false,
        usageAvailable = false,
        dayBucket = dayBucket,
        action = ACTION_NONE,
        enforcementSupported = false,
        enforcementMode = quotaEnforcementMode(isManaged),
        reason = REASON_NOT_CONFIGURED,
        quotaActive = false
    )

    /**
     * Quota suspension only exists under Device Owner, so the quota verdict
     * reports the two contract values `device_owner`/`none`; an active Device
     * Admin alone is not a quota capability.
     */
    fun quotaEnforcementMode(isManaged: Boolean): String = EnforcementMode.of(isManaged, false)
}

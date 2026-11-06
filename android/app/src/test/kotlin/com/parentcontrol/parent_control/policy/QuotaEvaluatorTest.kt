package com.parentcontrol.parent_control.policy

import com.parentcontrol.parent_control.InstalledPackage
import com.parentcontrol.parent_control.UsageRow
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertNotNull
import org.junit.Assert.assertNull
import org.junit.Assert.assertTrue
import org.junit.Test

/**
 * JVM tests for [QuotaEvaluator], the pure daily screen-time quota core wired
 * into `PolicyApplier`. The day boundary is the device-local bucket
 * `UsageReporter` already produces, and suspension only ever happens through
 * the existing Device Owner differential.
 */
class QuotaEvaluatorTest {
    private val ownPackage = "com.parentcontrol.parent_control"
    private val today = "2026-11-05"
    private val yesterday = "2026-11-04"
    private val tomorrow = "2026-11-06"
    private val quotaTargets = setOf("com.example.game", "com.example.social")

    private fun evaluate(
        usageMinutes: Int?,
        limitMinutes: Int?,
        isManaged: Boolean,
        suspended: Set<String> = quotaTargets,
        persistedDayBucket: String? = null,
        confirmationAvailable: Boolean = true,
        targetPackages: Set<String> = quotaTargets
    ): QuotaDecision = QuotaEvaluator.decide(
        configured = limitMinutes != null,
        usageAvailable = usageMinutes != null,
        usageMinutes = usageMinutes,
        limitMinutes = limitMinutes,
        dayBucket = today,
        isManaged = isManaged,
        targetPackages = targetPackages,
        alreadySuspended = { packageName -> packageName in suspended },
        persistedDayBucket = persistedDayBucket,
        confirmationAvailable = confirmationAvailable
    )

    private fun usageRow(day: String, packageName: String, minutes: Int) = UsageRow(
        day = day,
        packageName = packageName,
        label = packageName,
        totalMs = minutes * 60_000L,
        lastUsedAtMillis = null
    )

    private fun installedPackage(packageName: String, isSystem: Boolean = false) = InstalledPackage(
        packageName = packageName,
        label = packageName,
        isSystem = isSystem,
        versionName = "1.0"
    )

    /** Case 1: no daily limit configured. */
    @Test
    fun noDailyLimitConfiguredSuspendsNothingAndIsNotReportedAsAnActiveQuota() {
        assertNull(QuotaEvaluator.limitMinutes(null))
        // Defensive rejection of values a compliant server never sends.
        assertNull(QuotaEvaluator.limitMinutes(0))
        assertNull(QuotaEvaluator.limitMinutes(-120))
        assertNull(QuotaEvaluator.limitMinutes(1441))
        assertEquals(1, QuotaEvaluator.limitMinutes(1))
        assertEquals(1440, QuotaEvaluator.limitMinutes(1440))

        val decision = evaluate(usageMinutes = 300, limitMinutes = null, isManaged = true)
        assertFalse(decision.configured)
        assertFalse(decision.limitReached)
        assertFalse(decision.quotaActive)
        assertEquals(QuotaEvaluator.ACTION_NONE, decision.action)
        assertEquals(QuotaEvaluator.REASON_NOT_CONFIGURED, decision.reason)
        assertEquals(0, decision.desiredCount)
        assertTrue(decision.targets.isEmpty())

        // A raw 0 reaching the core must never suspend the device, even if the
        // server-side validator is bypassed by a hand-built policy payload.
        val zeroLimit = evaluate(usageMinutes = 300, limitMinutes = 0, isManaged = true)
        assertFalse(zeroLimit.configured)
        assertFalse(zeroLimit.limitReached)
        assertEquals(QuotaEvaluator.ACTION_NONE, zeroLimit.action)
        assertEquals(QuotaEvaluator.REASON_NOT_CONFIGURED, zeroLimit.reason)
        assertTrue(zeroLimit.targets.isEmpty())
        assertTrue(
            QuotaEvaluator.quotaSuspensionTargets(
                configured = true,
                usageAvailable = true,
                usageMinutes = 300,
                limitMinutes = 0,
                isManaged = true,
                targetPackages = quotaTargets
            ).isEmpty()
        )
    }

    /** Case 2: positive limit with usage below the threshold. */
    @Test
    fun positiveLimitWithUsageBelowThresholdDoesNotSuspend() {
        val decision = evaluate(usageMinutes = 119, limitMinutes = 120, isManaged = true)
        assertTrue(decision.configured)
        assertEquals(120, decision.limitMinutes)
        assertEquals(119, decision.usageMinutes)
        assertFalse(decision.limitReached)
        assertEquals(QuotaEvaluator.ACTION_NONE, decision.action)
        assertEquals(QuotaEvaluator.REASON_BELOW_LIMIT, decision.reason)
        assertTrue(decision.targets.isEmpty())
    }

    /** Case 3: usage exactly equals the limit. */
    @Test
    fun usageExactlyEqualToTheLimitReachesTheLimit() {
        assertTrue(QuotaEvaluator.isLimitReached(120, 120))
        val decision = evaluate(usageMinutes = 120, limitMinutes = 120, isManaged = true)
        assertTrue(decision.limitReached)
        assertEquals(QuotaEvaluator.ACTION_SUSPENDED, decision.action)
        assertEquals(quotaTargets, decision.targets)
    }

    /** Case 4: usage exceeds the limit. */
    @Test
    fun usageAboveTheLimitReachesTheLimit() {
        assertTrue(QuotaEvaluator.isLimitReached(121, 120))
        assertFalse(QuotaEvaluator.isLimitReached(121, null))
        assertFalse(QuotaEvaluator.isLimitReached(null, 120))
        val decision = evaluate(usageMinutes = 121, limitMinutes = 120, isManaged = true)
        assertTrue(decision.limitReached)
        assertEquals(QuotaEvaluator.ACTION_SUSPENDED, decision.action)
        assertNull(decision.reason)
    }

    /** Case 5: Standard Mode reaches the threshold and does not suspend. */
    @Test
    fun standardModeAtTheLimitIsAdvisoryAndSuspendsNothing() {
        val decision = evaluate(usageMinutes = 130, limitMinutes = 120, isManaged = false)
        assertTrue(decision.limitReached)
        assertEquals(QuotaEvaluator.ACTION_ADVISORY, decision.action)
        assertEquals(QuotaEvaluator.REASON_ADVISORY_ONLY, decision.reason)
        assertEquals(QuotaEvaluator.MODE_NONE, decision.enforcementMode)
        assertFalse(decision.enforcementSupported)
        assertTrue(decision.targets.isEmpty())
        assertEquals(0, decision.desiredCount)
        assertEquals(0, decision.appliedCount)
    }

    /** Case 6: Managed Mode suspends at the threshold. */
    @Test
    fun managedModeAtTheLimitSuspendsEveryQuotaTarget() {
        val decision = evaluate(usageMinutes = 120, limitMinutes = 120, isManaged = true)
        assertEquals(QuotaEvaluator.ACTION_SUSPENDED, decision.action)
        assertEquals(QuotaEvaluator.MODE_DEVICE_OWNER, decision.enforcementMode)
        assertTrue(decision.enforcementSupported)
        assertEquals(quotaTargets, decision.targets)
        assertEquals(quotaTargets, decision.applied)
        assertEquals(2, decision.desiredCount)
        assertEquals(2, decision.appliedCount)
        assertEquals(0, decision.failedCount)
        assertNull(decision.reason)
        assertEquals(today, decision.dayBucket)
    }

    /** Case 7: suspension is idempotent - confirmed packages are not re-suspended. */
    @Test
    fun alreadyConfirmedPackagesAreNotSuspendedAgain() {
        val decision = evaluate(
            usageMinutes = 200,
            limitMinutes = 120,
            isManaged = true,
            suspended = quotaTargets,
            persistedDayBucket = today
        )
        assertEquals(QuotaEvaluator.ACTION_SUSPENDED, decision.action)
        assertEquals(decision.desiredCount, decision.appliedCount)
        assertEquals(0, decision.failedCount)
        // The applier suspends only desired - previous, so a confirmed set has
        // nothing left to re-issue.
        val toSuspend = decision.targets - decision.applied
        assertTrue(toSuspend.isEmpty())
        val merged = LinkedHashSet<String>()
        merged.addAll(decision.targets)
        assertTrue(PolicyEvaluator.restoreList(merged, decision.targets).isEmpty())
    }

    /** Case 8: usage unavailable / permission missing. */
    @Test
    fun unavailableUsageNeverClaimsASuspension() {
        val decision = evaluate(usageMinutes = null, limitMinutes = 120, isManaged = true)
        assertTrue(decision.configured)
        assertFalse(decision.usageAvailable)
        assertFalse(decision.limitReached)
        assertNull(decision.usageMinutes)
        assertEquals(QuotaEvaluator.ACTION_NONE, decision.action)
        assertEquals(QuotaEvaluator.REASON_USAGE_UNAVAILABLE, decision.reason)
        assertTrue(decision.targets.isEmpty())
        assertFalse(decision.quotaActive)

        val notConfiguredAndNoAccess = QuotaEvaluator.decide(
            configured = false,
            usageAvailable = false,
            usageMinutes = null,
            limitMinutes = null,
            dayBucket = today,
            isManaged = true,
            targetPackages = quotaTargets,
            alreadySuspended = { false }
        )
        assertEquals(QuotaEvaluator.REASON_NOT_CONFIGURED, notConfiguredAndNoAccess.reason)
    }

    /** Case 9: a process restart reproduces the same verdict from the persisted day. */
    @Test
    fun processRestartPreservesTheCorrectDailyUsage() {
        val rows = listOf(
            usageRow(today, "com.example.game", 70),
            usageRow(today, "com.example.social", 60),
            usageRow(yesterday, "com.example.game", 500)
        )
        val minutes = QuotaEvaluator.totalUsageMinutesToday(rows, today)
        assertEquals(130, minutes)

        val beforeRestart = evaluate(usageMinutes = minutes, limitMinutes = 120, isManaged = true)
        // The new process only has the persisted bucket plus the system store.
        val afterRestart = evaluate(
            usageMinutes = minutes,
            limitMinutes = 120,
            isManaged = true,
            persistedDayBucket = beforeRestart.dayBucket
        )
        assertEquals(beforeRestart.action, afterRestart.action)
        assertEquals(beforeRestart.targets, afterRestart.targets)
        assertEquals(today, afterRestart.dayBucket)
        assertEquals(QuotaEvaluator.ACTION_SUSPENDED, afterRestart.action)
    }

    /** Case 10: a reboot does not reset the quota incorrectly. */
    @Test
    fun rebootDoesNotResetTheQuotaDay() {
        val rows = listOf(usageRow(today, "com.example.game", 200))
        val minutes = QuotaEvaluator.totalUsageMinutesToday(rows, today)
        val decision = evaluate(
            usageMinutes = minutes,
            limitMinutes = 120,
            isManaged = true,
            persistedDayBucket = today
        )
        assertTrue(decision.quotaActive)
        assertEquals(today, decision.dayBucket)
        assertEquals(quotaTargets, decision.targets)
        assertEquals(QuotaEvaluator.ACTION_SUSPENDED, decision.action)
        // The day is not re-armed: only a strictly later bucket replaces it.
        assertFalse(QuotaEvaluator.advanceDayBucket(today, today))
        assertEquals(today, QuotaEvaluator.resolvedDayBucket(today, today, true))
        assertEquals(2, decision.desiredCount)
        assertEquals(2, decision.appliedCount)
        assertEquals(0, decision.failedCount)
    }

    /** Case 11: local midnight resets the daily counter correctly. */
    @Test
    fun localMidnightResetsTheDailyCounterAndRestoresPackages() {
        assertTrue(QuotaEvaluator.advanceDayBucket(today, tomorrow))
        val rows = listOf(usageRow(today, "com.example.game", 200))
        assertEquals(0, QuotaEvaluator.totalUsageMinutesToday(rows, tomorrow))

        val newDay = evaluate(usageMinutes = 0, limitMinutes = 120, isManaged = true)
        assertFalse(newDay.limitReached)
        assertEquals(QuotaEvaluator.ACTION_NONE, newDay.action)
        assertEquals(QuotaEvaluator.REASON_BELOW_LIMIT, newDay.reason)
        // The quota leaves the desired set, so the existing differential restores.
        val previous = LinkedHashSet(quotaTargets)
        previous.add("com.example.blocked")
        val appDesired = setOf("com.example.blocked")
        assertEquals(quotaTargets, PolicyEvaluator.restoreList(previous, appDesired))
    }

    /** Case 12: a timezone change does not double-count or re-arm the day. */
    @Test
    fun timezoneChangeDoesNotDoubleCountTheDay() {
        assertFalse(QuotaEvaluator.advanceDayBucket(tomorrow, today))
        assertFalse(QuotaEvaluator.advanceDayBucket(null, today))
        // An earlier bucket never replaces the recorded one.
        assertEquals(tomorrow, QuotaEvaluator.resolvedDayBucket(tomorrow, today, true))
        assertEquals(today, QuotaEvaluator.resolvedDayBucket(null, today, true))

        val rows = listOf(
            usageRow(today, "com.example.game", 80),
            usageRow(today, "com.example.social", 60)
        )
        val minutes = QuotaEvaluator.totalUsageMinutesToday(rows, today)
        assertEquals(140, minutes)
        val decision = evaluate(
            usageMinutes = minutes,
            limitMinutes = 120,
            isManaged = true,
            persistedDayBucket = tomorrow
        )
        assertTrue(decision.limitReached)
        assertEquals(tomorrow, decision.dayBucket)
    }

    /** Case 13: the limit is increased after suspension, so packages are restored. */
    @Test
    fun increasedLimitAfterSuspensionRestoresPackages() {
        val suspendedForOldLimit = evaluate(usageMinutes = 130, limitMinutes = 120, isManaged = true)
        assertEquals(quotaTargets, suspendedForOldLimit.targets)

        // The same measured usage is now below the raised limit.
        val raised = evaluate(
            usageMinutes = 130,
            limitMinutes = 240,
            isManaged = true,
            persistedDayBucket = today
        )
        assertFalse(raised.limitReached)
        assertTrue(raised.targets.isEmpty())
        assertEquals(
            quotaTargets,
            PolicyEvaluator.restoreList(suspendedForOldLimit.targets, raised.targets)
        )
    }

    /** Case 14: the limit is removed after suspension, so packages are restored. */
    @Test
    fun removedLimitAfterSuspensionRestoresPackages() {
        val suspended = evaluate(usageMinutes = 130, limitMinutes = 120, isManaged = true)
        val cleared = evaluate(
            usageMinutes = 130,
            limitMinutes = null,
            isManaged = true,
            persistedDayBucket = today
        )
        assertFalse(cleared.quotaActive)
        assertTrue(cleared.targets.isEmpty())
        assertEquals(
            quotaTargets,
            PolicyEvaluator.restoreList(suspended.targets, cleared.targets)
        )
    }

    /** Case 15: existing app restrictions stay intact alongside the quota union. */
    @Test
    fun quotaUnionKeepsExistingAppRestrictionsAndProtectsCriticalApps() {
        val installed = listOf(
            installedPackage("com.example.game"),
            installedPackage("com.example.social"),
            installedPackage("com.android.settings", isSystem = true),
            installedPackage("com.google.android.gms"),
            installedPackage(ownPackage),
            // Eligible because Android classifies it as a user app and it is not
            // on the guard list — protection is never decided by the name.
            installedPackage("com.example.freeapp"),
            installedPackage("com.example.launcher"),
            installedPackage("com.example.ime")
        )
        val targets = QuotaEvaluator.quotaTargetPackages(
            installed,
            ownPackage,
            protectedHome = "com.example.launcher",
            protectedIme = "com.example.ime"
        )
        assertEquals(setOf("com.example.game", "com.example.social", "com.example.freeapp"), targets)

        val appDesired = setOf("com.example.blocked", "com.example.social")
        val union = LinkedHashSet(appDesired)
        union.addAll(targets)
        // A quota suspension never removes an independently configured app rule.
        assertTrue(union.containsAll(appDesired))
        val previous = LinkedHashSet(appDesired)
        previous.addAll(targets)
        assertTrue(PolicyEvaluator.restoreList(previous, union).isEmpty())
        assertFalse(union.contains(ownPackage))
        assertFalse(union.contains("com.android.settings"))
        assertFalse(union.contains("com.google.android.gms"))
    }

    /** Case 16: a non-Device-Owner device never reports quota suspension. */
    @Test
    fun nonDeviceOwnerDeviceNeverReportsQuotaSuspension() {
        val decision = evaluate(
            usageMinutes = 600,
            limitMinutes = 120,
            isManaged = false,
            suspended = quotaTargets
        )
        assertFalse(decision.targets.isEmpty() && decision.action == QuotaEvaluator.ACTION_SUSPENDED)
        assertEquals(QuotaEvaluator.ACTION_ADVISORY, decision.action)
        assertEquals(QuotaEvaluator.MODE_NONE, decision.enforcementMode)
        assertFalse(decision.enforcementSupported)
        assertEquals(0, decision.desiredCount)
        assertEquals(0, decision.appliedCount)
        assertTrue(decision.applied.isEmpty())

        val belowLimit = evaluate(usageMinutes = 10, limitMinutes = 120, isManaged = false)
        assertEquals(QuotaEvaluator.ACTION_NONE, belowLimit.action)
        assertFalse(belowLimit.quotaActive)
    }

    /** Case 17: a failed or partial suspension yields suspend_failed, never success. */
    @Test
    fun partialSuspensionReportsSuspendFailedAndNeverSuccess() {
        val partial = evaluate(
            usageMinutes = 300,
            limitMinutes = 120,
            isManaged = true,
            suspended = setOf("com.example.game")
        )
        assertEquals(QuotaEvaluator.ACTION_SUSPEND_FAILED, partial.action)
        assertEquals("quota_suspended 1 of 2", partial.reason)
        assertEquals(2, partial.desiredCount)
        assertEquals(1, partial.appliedCount)
        assertEquals(1, partial.failedCount)
        assertFalse(partial.enforcementSupported)

        val nothingConfirmed = evaluate(
            usageMinutes = 300,
            limitMinutes = 120,
            isManaged = true,
            suspended = emptySet()
        )
        assertEquals(QuotaEvaluator.ACTION_SUSPEND_FAILED, nothingConfirmed.action)
        assertEquals(QuotaEvaluator.REASON_SUSPEND_FAILED, nothingConfirmed.reason)
        assertEquals(2, nothingConfirmed.failedCount)

        val noEligibleTarget = evaluate(
            usageMinutes = 300,
            limitMinutes = 120,
            isManaged = true,
            targetPackages = emptySet()
        )
        assertEquals(QuotaEvaluator.ACTION_SUSPEND_FAILED, noEligibleTarget.action)
        assertNotEqualsSuspended(noEligibleTarget.action)

        val unconfirmable = evaluate(
            usageMinutes = 300,
            limitMinutes = 120,
            isManaged = true,
            confirmationAvailable = false
        )
        assertEquals(QuotaEvaluator.ACTION_SUSPEND_FAILED, unconfirmable.action)
        assertEquals(QuotaEvaluator.REASON_CONFIRMATION_MISSING, unconfirmable.reason)
        assertFalse(unconfirmable.enforcementSupported)
    }

    /** Case 18: an old acknowledgement without a quota object differs from a quota-active one. */
    @Test
    fun absentQuotaObjectIsDistinguishableFromAQuotaActiveOne() {
        // What an ack built without any quota evaluation degenerates to.
        val legacy = QuotaEvaluator.notConfigured(isManaged = true, dayBucket = today)
        assertFalse(legacy.configured)
        assertFalse(legacy.quotaActive)
        assertFalse(legacy.limitReached)
        assertEquals(QuotaEvaluator.ACTION_NONE, legacy.action)
        assertEquals(QuotaEvaluator.REASON_NOT_CONFIGURED, legacy.reason)
        assertEquals(0, legacy.desiredCount)

        val active = evaluate(
            usageMinutes = 180,
            limitMinutes = 120,
            isManaged = true,
            suspended = quotaTargets,
            persistedDayBucket = today
        )
        assertTrue(active.quotaActive)
        assertEquals(QuotaEvaluator.ACTION_SUSPENDED, active.action)
        assertNull(active.reason)
        assertNotNull(active.dayBucket)
        assertTrue(active.desiredCount > 0)
        assertEquals(today, active.dayBucket)
    }

    private fun assertNotEqualsSuspended(action: String) {
        assertFalse(action == QuotaEvaluator.ACTION_SUSPENDED)
    }
}

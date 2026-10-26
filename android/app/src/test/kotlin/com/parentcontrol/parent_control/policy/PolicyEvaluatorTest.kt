package com.parentcontrol.parent_control.policy

import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Test

/** JVM tests for the pure policy decisions used by PolicyApplier. */
class PolicyEvaluatorTest {
    private val ownPackage = "com.parentcontrol.parent_control"

    @Test
    fun windowInsideSameDay() {
        val window = PolicyWindow(
            daysOfWeek = setOf(1, 2),
            startMinutes = 8 * 60,
            endMinutes = 10 * 60
        )
        assertTrue(window.isActiveAt(1, 8 * 60))
        assertTrue(window.isActiveAt(2, 9 * 60 + 59))
        assertFalse(window.isActiveAt(2, 10 * 60))
        assertFalse(window.isActiveAt(1, 7 * 60 + 59))
        assertFalse(window.isActiveAt(3, 9 * 60))
    }

    @Test
    fun windowSpanningMidnightUsesPreviousDay() {
        // Friday 22:00 until Saturday 06:00.
        val window = PolicyWindow(
            daysOfWeek = setOf(5),
            startMinutes = 22 * 60,
            endMinutes = 6 * 60
        )
        assertTrue(window.isActiveAt(5, 22 * 60))
        assertTrue(window.isActiveAt(5, 23 * 60 + 59))
        assertTrue(window.isActiveAt(6, 0))
        assertTrue(window.isActiveAt(6, 5 * 60 + 59))
        assertFalse(window.isActiveAt(6, 6 * 60))
        assertFalse(window.isActiveAt(5, 6 * 60))
        assertFalse(window.isActiveAt(4, 23 * 60))
    }

    @Test
    fun emptyOrZeroLengthWindowIsInactive() {
        assertFalse(PolicyWindow(emptySet(), 0, 60).isActiveAt(1, 30))
        assertFalse(PolicyWindow(setOf(1), 600, 600).isActiveAt(1, 600))
    }

    @Test
    fun appRuleWinsOverPackageLists() {
        val policy = ChildPolicy(
            blockedPackages = setOf("com.instagram.android"),
            appRules = listOf(
                PolicyAppRule(
                    packageName = "com.instagram.android",
                    label = "Instagram",
                    blocked = false,
                    windows = emptyList()
                )
            )
        )
        assertFalse(policy.isPackageBlockedNow("com.instagram.android", 1, 600))
    }

    @Test
    fun appRuleWindowOnlyBlocksInsideWindow() {
        val policy = ChildPolicy(
            appRules = listOf(
                PolicyAppRule(
                    packageName = "com.instagram.android",
                    label = "Instagram",
                    blocked = true,
                    windows = listOf(
                        PolicyWindow(setOf(1), 18 * 60, 20 * 60)
                    )
                )
            )
        )
        assertTrue(policy.isPackageBlockedNow("com.instagram.android", 1, 19 * 60))
        assertFalse(policy.isPackageBlockedNow("com.instagram.android", 1, 21 * 60))
    }

    @Test
    fun blockAllExceptAllowedBlocksUnlistedApps() {
        val policy = ChildPolicy(
            blockAllExceptAllowed = true,
            allowedPackages = setOf("com.whatsapp")
        )
        assertFalse(policy.isPackageBlockedNow("com.whatsapp", 1, 600))
        assertTrue(policy.isPackageBlockedNow("com.example.game", 1, 600))
    }

    @Test
    fun allowedPackageOverridesBlockedListOnlyWhenBlockAllIsSet() {
        val withBlockAll = ChildPolicy(
            blockAllExceptAllowed = true,
            blockedPackages = setOf("com.example.app"),
            allowedPackages = setOf("com.example.app")
        )
        assertFalse(withBlockAll.isPackageBlockedNow("com.example.app", 1, 600))

        val withoutBlockAll = ChildPolicy(
            blockAllExceptAllowed = false,
            blockedPackages = setOf("com.example.app"),
            allowedPackages = setOf("com.example.app")
        )
        assertTrue(withoutBlockAll.isPackageBlockedNow("com.example.app", 1, 600))
    }

    @Test
    fun disabledEnforcementBlocksNothing() {
        val policy = ChildPolicy(
            enforceAppBlocks = false,
            blockAllExceptAllowed = true,
            blockedPackages = setOf("com.example.app")
        )
        assertFalse(policy.isPackageBlockedNow("com.example.app", 1, 600))
        assertTrue(PolicyEvaluator.explicitBlockedNow(policy, 1, 600).isEmpty())
    }

    @Test
    fun restoreListContainsOnlyPreviouslySuspendedPackages() {
        assertEquals(
            setOf("com.a"),
            PolicyEvaluator.restoreList(setOf("com.a", "com.b"), setOf("com.b", "com.c"))
        )
        assertTrue(PolicyEvaluator.restoreList(emptySet(), setOf("com.a")).isEmpty())
        assertEquals(
            setOf("com.a", "com.b"),
            PolicyEvaluator.restoreList(setOf("com.a", "com.b"), emptySet())
        )
    }

    @Test
    fun explicitBlockedNowHonoursRulesAndLists() {
        val policy = ChildPolicy(
            blockedPackages = setOf("com.blocked", "com.ruled"),
            appRules = listOf(
                PolicyAppRule(
                    packageName = "com.ruled",
                    label = "Ruled",
                    blocked = true,
                    windows = listOf(PolicyWindow(setOf(2), 0, 60))
                )
            )
        )
        assertEquals(setOf("com.blocked"), PolicyEvaluator.explicitBlockedNow(policy, 1, 30))
        assertEquals(
            setOf("com.blocked", "com.ruled"),
            PolicyEvaluator.explicitBlockedNow(policy, 2, 30)
        )
    }

    @Test
    fun criticalAndDynamicPackagesAreProtected() {
        assertTrue(
            PolicyGuard.isProtectedPackage("com.android.systemui", ownPackage)
        )
        assertTrue(PolicyGuard.isProtectedPackage("com.android.settings", ownPackage))
        assertTrue(PolicyGuard.isProtectedPackage("com.android.phone", ownPackage))
        assertTrue(PolicyGuard.isProtectedPackage(ownPackage, ownPackage))
        assertTrue(
            PolicyGuard.isProtectedPackage(
                "com.example.launcher",
                ownPackage,
                defaultHomePackage = "com.example.launcher"
            )
        )
        assertTrue(
            PolicyGuard.isProtectedPackage(
                "com.example.ime",
                ownPackage,
                defaultInputMethodPackage = "com.example.ime"
            )
        )
        assertTrue(PolicyGuard.isProtectedPackage("", ownPackage))
        assertFalse(
            PolicyGuard.isProtectedPackage("com.instagram.android", ownPackage)
        )
    }

    @Test
    fun bedtimeSpanningMidnight() {
        val policy = ChildPolicy(
            bedtimeStartMinutes = 22 * 60,
            bedtimeEndMinutes = 7 * 60
        )
        assertTrue(policy.hasBedtime)
        assertTrue(policy.isWithinBedtime(23 * 60))
        assertTrue(policy.isWithinBedtime(0))
        assertTrue(policy.isWithinBedtime(6 * 60 + 59))
        assertFalse(policy.isWithinBedtime(7 * 60))
        assertFalse(policy.isWithinBedtime(12 * 60))
    }

    @Test
    fun noBedtimeWhenUnsetOrEqual() {
        assertFalse(ChildPolicy().hasBedtime)
        assertFalse(
            ChildPolicy(
                bedtimeStartMinutes = 60,
                bedtimeEndMinutes = 60
            ).hasBedtime
        )
    }
}

package com.parentcontrol.parent_control

import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Test

/**
 * JVM tests for [EnforcementMode], the single source of truth behind the
 * `enforcement_mode` value reported in the policy ack (`result`) and in the
 * heartbeat (`capabilities`).
 *
 * Before this extraction the identical three-branch rule lived twice on the
 * Android side (PolicyApplier and GuardianService) with no test at all, so the
 * two copies could drift apart silently. These tests pin all four capability
 * combinations and the Device Owner precedence.
 */
class EnforcementModeTest {
    /** The vocabulary the backend column accepts (`core.sql:101`). */
    private val wireVocabulary = setOf("none", "device_admin", "device_owner")

    @Test
    fun deviceOwnerBeatsActiveAdminWhenBothAreTrue() {
        val mode = EnforcementMode.of(isDeviceOwner = true, isAdminActive = true)
        assertEquals("device_owner", mode)
        // Precedence: the device_admin branch must never win for a Device Owner.
        assertFalse(mode == "device_admin")
    }

    @Test
    fun deviceOwnerWithoutActiveAdminReportsDeviceOwner() {
        val mode = EnforcementMode.of(isDeviceOwner = true, isAdminActive = false)
        assertEquals("device_owner", mode)
        assertFalse(mode == "none")
    }

    @Test
    fun activeAdminWithoutDeviceOwnerReportsDeviceAdmin() {
        val mode = EnforcementMode.of(isDeviceOwner = false, isAdminActive = true)
        assertEquals("device_admin", mode)
        // An admin alone never claims the Device Owner suspension capability.
        assertFalse(mode == "device_owner")
    }

    @Test
    fun noCapabilityReportsNoneAndEveryValueStaysInTheWireVocabulary() {
        val mode = EnforcementMode.of(isDeviceOwner = false, isAdminActive = false)
        assertEquals("none", mode)
        // The strings are byte-identical to the reported contract values.
        assertTrue(wireVocabulary.contains(mode))
        assertTrue(wireVocabulary.contains(EnforcementMode.of(isDeviceOwner = true, isAdminActive = true)))
        assertTrue(wireVocabulary.contains(EnforcementMode.of(isDeviceOwner = true, isAdminActive = false)))
        assertTrue(wireVocabulary.contains(EnforcementMode.of(isDeviceOwner = false, isAdminActive = true)))
    }
}

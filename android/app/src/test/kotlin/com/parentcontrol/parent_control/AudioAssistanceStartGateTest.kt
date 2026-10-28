package com.parentcontrol.parent_control

import org.junit.Assert.assertEquals
import org.junit.Assert.assertNull
import org.junit.Test

/**
 * JVM tests for the pure start gate of AudioAssistanceService.
 *
 * Only the side-effect free decision is covered here; the Android service
 * lifecycle itself needs an instrumented (or Robolectric) test, and this
 * module has no such dependency.
 */
class AudioAssistanceStartGateTest {
    @Test
    fun missingMicrophoneBlocksWithPermissionDenied() {
        assertEquals(
            AudioAssistanceService.REASON_PERMISSION_DENIED,
            AudioAssistanceService.startBlockReason(
                sdkInt = 36,
                microphoneGranted = false,
                notificationsGranted = true
            )
        )
        // The microphone check wins so the child is asked for the permission
        // that actually gates capture.
        assertEquals(
            AudioAssistanceService.REASON_PERMISSION_DENIED,
            AudioAssistanceService.startBlockReason(
                sdkInt = 33,
                microphoneGranted = false,
                notificationsGranted = false
            )
        )
    }

    @Test
    fun api33AndAboveRequireNotificationPermission() {
        assertEquals(
            AudioAssistanceService.REASON_NOTIFICATION_PERMISSION_REQUIRED,
            AudioAssistanceService.startBlockReason(33, true, false)
        )
        assertEquals(
            AudioAssistanceService.REASON_NOTIFICATION_PERMISSION_REQUIRED,
            AudioAssistanceService.startBlockReason(34, true, false)
        )
        assertEquals(
            AudioAssistanceService.REASON_NOTIFICATION_PERMISSION_REQUIRED,
            AudioAssistanceService.startBlockReason(36, true, false)
        )
    }

    @Test
    fun legacyVersionsDoNotRequireNotificationPermission() {
        assertNull(AudioAssistanceService.startBlockReason(29, true, false))
        assertNull(AudioAssistanceService.startBlockReason(30, true, false))
        assertNull(AudioAssistanceService.startBlockReason(32, true, false))
    }

    @Test
    fun fullyGrantedStartIsAllowedOnEverySupportedVersion() {
        assertNull(AudioAssistanceService.startBlockReason(23, true, false))
        assertNull(AudioAssistanceService.startBlockReason(30, true, true))
        assertNull(AudioAssistanceService.startBlockReason(33, true, true))
        assertNull(AudioAssistanceService.startBlockReason(36, true, true))
    }
}

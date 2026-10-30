package com.parentcontrol.parent_control

import org.junit.Assert.assertEquals
import org.junit.Assert.assertTrue
import org.junit.Test

/**
 * JVM tests for the pure decisions that keep an authorized audio session alive
 * across Activity recreation and separate it from a second session.
 *
 * The real service lifecycle needs an instrumented test; here only the
 * side-effect free mapping used by `onStartCommand` / the capture watchdog is
 * covered.
 */
class AudioAssistanceRecreationTest {
    private val start = AudioAssistanceService.StartDisposition.START
    private val already = AudioAssistanceService.StartDisposition.ALREADY_RUNNING
    private val busy = AudioAssistanceService.StartDisposition.BUSY_OTHER_SESSION
    private val keep = AudioAssistanceService.WatchdogDecision.KEEP_RUNNING
    private val stop = AudioAssistanceService.WatchdogDecision.STOP

    @Test
    fun aStoppedServiceAcceptsAnyStart() {
        assertEquals(start, AudioAssistanceService.startDisposition(false, null, "s-1"))
        assertEquals(start, AudioAssistanceService.startDisposition(false, "s-old", "s-1"))
        assertEquals(start, AudioAssistanceService.startDisposition(false, null, null))
    }

    @Test
    fun recreatingTheActivityForTheSameSessionDoesNotStartASecondCapture() {
        assertEquals(already, AudioAssistanceService.startDisposition(true, "s-1", "s-1"))
        // The engine restore may replay the request without an id; treating it
        // as "already running" is what prevents duplicate capture/tracks.
        assertEquals(already, AudioAssistanceService.startDisposition(true, "s-1", null))
        assertEquals(already, AudioAssistanceService.startDisposition(true, "s-1", "   "))
        assertEquals(already, AudioAssistanceService.startDisposition(true, null, "s-1"))
        assertEquals(already, AudioAssistanceService.startDisposition(true, " s-1 ", "s-1"))
    }

    @Test
    fun aDifferentSessionIsRefusedWithoutTearingDownTheLiveOne() {
        assertEquals(busy, AudioAssistanceService.startDisposition(true, "s-1", "s-2"))
    }

    @Test
    fun aFreshHeartbeatKeepsCaptureRunning() {
        val now = 1_000_000L
        assertEquals(keep, AudioAssistanceService.captureWatchdogAction(true, now, now))
        assertEquals(
            keep,
            AudioAssistanceService.captureWatchdogAction(
                true,
                now,
                now + AudioAssistanceService.CAPTURE_HEARTBEAT_TIMEOUT_MS
            )
        )
    }

    @Test
    fun aStaleHeartbeatStopsTheMicrophoneService() {
        val now = 1_000_000L
        assertEquals(
            stop,
            AudioAssistanceService.captureWatchdogAction(
                true,
                now,
                now + AudioAssistanceService.CAPTURE_HEARTBEAT_TIMEOUT_MS + 1L
            )
        )
    }

    @Test
    fun aServiceThatIsNotRunningOrHasNoHeartbeatIsLeftToTheSessionWatchdog() {
        // Staleness alone is not evidence of lost capture: a service that is
        // starting up, or one that never received a heartbeat, is governed by
        // the permission and session watchdogs instead.
        assertEquals(keep, AudioAssistanceService.captureWatchdogAction(false, 0L, 9_999_999L))
        assertEquals(keep, AudioAssistanceService.captureWatchdogAction(true, 0L, 9_999_999L))
    }

    @Test
    fun captureHeartbeatTimeoutStaysWellBelowTheSessionWatchdog() {
        // Dart confirms every 10 s; the timeout must tolerate several missed
        // confirmations without ending an authorized session on one hiccup.
        assertTrue(AudioAssistanceService.CAPTURE_HEARTBEAT_TIMEOUT_MS >= 30_000L)
        assertTrue(AudioAssistanceService.CAPTURE_HEARTBEAT_TIMEOUT_MS <= 120_000L)
    }

    @Test
    fun startAndCaptureReasonsAreStable() {
        // Dart maps these strings to user-visible messages; renaming breaks it.
        assertEquals("permission_denied", AudioAssistanceService.REASON_PERMISSION_DENIED)
        assertEquals(
            "notification_permission_required",
            AudioAssistanceService.REASON_NOTIFICATION_PERMISSION_REQUIRED
        )
        assertEquals(
            "start_foreground_failed",
            AudioAssistanceService.REASON_START_FOREGROUND_FAILED
        )
        assertEquals(
            "start_foreground_service_failed",
            AudioAssistanceService.REASON_START_FOREGROUND_SERVICE_FAILED
        )
        assertEquals("session_mismatch", AudioAssistanceService.REASON_SESSION_MISMATCH)
        assertEquals("capture_lost", AudioAssistanceService.REASON_CAPTURE_LOST)
    }
}

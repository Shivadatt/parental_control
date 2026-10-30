package com.parentcontrol.parent_control

import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Test

/**
 * JVM tests for the pure session-watchdog decision of AudioAssistanceService.
 *
 * The HTTP round trip and the Android lifecycle need an instrumented test, so
 * only the side-effect free mapping from a backend session status to "keep
 * running / stop" is covered here.
 */
class AudioAssistanceSessionWatchdogTest {
    private val keep = AudioAssistanceService.WatchdogDecision.KEEP_RUNNING
    private val stop = AudioAssistanceService.WatchdogDecision.STOP

    @Test
    fun openStatusesKeepRunning() {
        assertEquals(keep, AudioAssistanceService.sessionWatchdogAction("requested"))
        assertEquals(keep, AudioAssistanceService.sessionWatchdogAction("accepted"))
        assertEquals(keep, AudioAssistanceService.sessionWatchdogAction("active"))
    }

    @Test
    fun openStatusesAreCaseAndWhitespaceInsensitive() {
        assertEquals(keep, AudioAssistanceService.sessionWatchdogAction(" ACTIVE "))
        assertEquals(keep, AudioAssistanceService.sessionWatchdogAction("Accepted"))
        assertEquals(keep, AudioAssistanceService.sessionWatchdogAction("\trequested\n"))
    }

    @Test
    fun terminalStatusesStop() {
        assertEquals(stop, AudioAssistanceService.sessionWatchdogAction("ended"))
        assertEquals(stop, AudioAssistanceService.sessionWatchdogAction("stopped"))
        assertEquals(stop, AudioAssistanceService.sessionWatchdogAction("completed"))
        assertEquals(stop, AudioAssistanceService.sessionWatchdogAction("declined"))
        assertEquals(stop, AudioAssistanceService.sessionWatchdogAction("cancelled"))
        assertEquals(stop, AudioAssistanceService.sessionWatchdogAction("canceled"))
        assertEquals(stop, AudioAssistanceService.sessionWatchdogAction("expired"))
    }

    @Test
    fun anyOtherNonBlankStatusStops() {
        // The backend only guarantees the three open states; anything else is
        // treated as the parent having ended the session.
        assertEquals(stop, AudioAssistanceService.sessionWatchdogAction("ENDED "))
        assertEquals(stop, AudioAssistanceService.sessionWatchdogAction("something_new"))
    }

    @Test
    fun missingOrBlankStatusKeepsRunning() {
        // An unusable answer is not proof that the session ended.
        assertEquals(keep, AudioAssistanceService.sessionWatchdogAction(null))
        assertEquals(keep, AudioAssistanceService.sessionWatchdogAction(""))
        assertEquals(keep, AudioAssistanceService.sessionWatchdogAction("   "))
    }

    @Test
    fun shouldStopMatchesTheDecision() {
        assertFalse(AudioAssistanceService.shouldStopForSessionStatus("active"))
        assertFalse(AudioAssistanceService.shouldStopForSessionStatus("requested"))
        assertFalse(AudioAssistanceService.shouldStopForSessionStatus(""))
        assertTrue(AudioAssistanceService.shouldStopForSessionStatus("ended"))
        assertTrue(AudioAssistanceService.shouldStopForSessionStatus("stopped"))
    }

    @Test
    fun newEventReasonsAreStable() {
        // Dart keys on these strings; changing them is a breaking change.
        assertEquals("task_removed_active", AudioAssistanceService.REASON_TASK_REMOVED_ACTIVE)
        assertEquals(
            "session_ended_by_parent",
            AudioAssistanceService.REASON_SESSION_ENDED_BY_PARENT
        )
    }
}

package com.parentcontrol.parent_control

import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Test

/**
 * JVM tests for the pure decision that keeps a stale "Stop" intent from tearing
 * down the audio session that replaced it.
 *
 * The real `onStartCommand`/`stopSelf(startId)` behaviour needs an instrumented
 * test; here only the side-effect free guard is covered.
 */
class AudioAssistanceStopIdempotenceTest {
    @Test
    fun aStopForTheRunningSessionIsApplied() {
        assertFalse(AudioAssistanceService.stopTargetsOtherSession("s-1", "s-1"))
        assertFalse(AudioAssistanceService.stopTargetsOtherSession(" s-1 ", "s-1"))
    }

    @Test
    fun aQueuedStopForAReplacedSessionIsIgnored() {
        assertTrue(AudioAssistanceService.stopTargetsOtherSession("s-new", "s-old"))
    }

    @Test
    fun aStopWithoutComparableIdsIsTreatedAsCurrent() {
        // An older build's notification carries no session id; it must still be
        // able to stop the session it was shown for.
        assertFalse(AudioAssistanceService.stopTargetsOtherSession("s-1", null))
        assertFalse(AudioAssistanceService.stopTargetsOtherSession("s-1", "  "))
        assertFalse(AudioAssistanceService.stopTargetsOtherSession(null, "s-1"))
        assertFalse(AudioAssistanceService.stopTargetsOtherSession(null, null))
    }
}
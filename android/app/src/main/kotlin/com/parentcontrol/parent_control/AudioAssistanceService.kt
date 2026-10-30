package com.parentcontrol.parent_control

import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.app.Service
import android.content.Context
import android.content.Intent
import android.content.pm.ServiceInfo
import android.os.Build
import android.os.Handler
import android.os.IBinder
import android.os.Looper
import android.os.PowerManager
import androidx.core.app.NotificationCompat
import androidx.core.content.ContextCompat
import org.json.JSONObject
import java.util.Locale
import java.util.concurrent.Executors
import java.util.concurrent.ScheduledExecutorService
import java.util.concurrent.TimeUnit

/**
 * Android Foreground Service of type MICROPHONE.
 *
 * Runs exclusively during active, child-consented audio assistance sessions.
 * Displays a persistent, non-dismissible notification informing the child that
 * the microphone is active and providing an immediate "Stop" action.
 *
 * This allows Android 11+ and Android 12+ (e.g. realme RMX2161) to continue
 * microphone capture and WebRTC transmission while the app is in the background
 * or the screen is locked, in full compliance with Android foreground service
 * security and privacy requirements.
 *
 * The service never records audio. It does not own the capture itself either:
 * the WebRTC microphone track belongs to the process-scoped FlutterEngine
 * hosted by [MainActivity]. The service's job is to keep that process
 * foreground-eligible and to present the microphone notification while Dart
 * confirms, every 10 s, that capture is still running. Without confirmations
 * for [CAPTURE_HEARTBEAT_TIMEOUT_MS] the service stops with
 * `capture_lost` instead of leaving a microphone notification that claims
 * audio is active after the media engine died.
 *
 * Lifetime policy (approved):
 * - Swiping the task from Recents does NOT end an already consented, active
 *   session on supported devices: `stopWithTask=false` plus [onTaskRemoved]
 *   keep the service, wake lock, notification (with its Stop action) and the
 *   cached FlutterEngine alive, and the UI is told the session is detached via
 *   `audio_assistance_detached`.
 * - The child can still stop at any time through the notification action or
 *   the UI, which ends local capture immediately.
 * - While running, a 15 s watchdog asks the backend whether the session is
 *   still open; when the parent has ended it the service stops itself with
 *   `audio_assistance_stopped` / `session_ended_by_parent`.
 * - A revoked microphone permission ends the session from the permission
 *   watchdog; consent, not the notification, is what keeps capture alive.
 * - This service does NOT survive an OS force-stop, a device reboot, an OEM
 *   task-manager "clean", or the system killing the process for memory. Those
 *   paths end local capture, and the session can only be rejoined through the
 *   visible Reconnect action once the app is reopened.
 *
 * Startup is confirmed to Dart with `audio_assistance_started`; every failure
 * to start inside the service emits `audio_assistance_start_failed` with a
 * machine-readable reason and leaves [isRunning] false. When [start] can reject
 * the request up front it returns false and only records [lastError].
 */
class AudioAssistanceService : Service() {
    /** Pure outcome of one session-state poll, unit-testable on the JVM. */
    enum class WatchdogDecision { KEEP_RUNNING, STOP }

    /** Pure outcome of a start request against the service that is running. */
    enum class StartDisposition { START, ALREADY_RUNNING, BUSY_OTHER_SESSION }

    companion object {
        const val CHANNEL_ID = "audio_assistance_channel"
        const val NOTIFICATION_ID = 4303
        const val ACTION_STOP = "com.parentcontrol.parent_control.ACTION_STOP_AUDIO_ASSISTANCE"
        const val EXTRA_SESSION_ID = "sessionId"

        /** Machine-readable reasons reported through [NativeEventBus]. */
        const val REASON_PERMISSION_DENIED = "permission_denied"
        const val REASON_NOTIFICATION_PERMISSION_REQUIRED = "notification_permission_required"
        const val REASON_START_FOREGROUND_FAILED = "start_foreground_failed"
        const val REASON_START_FOREGROUND_SERVICE_FAILED = "start_foreground_service_failed"
        const val REASON_SESSION_MISMATCH = "session_mismatch"

        /**
         * Dart stopped confirming microphone capture for this session. The
         * service stops so the microphone notification never outlives the
         * capture it claims to keep alive.
         */
        const val REASON_CAPTURE_LOST = "capture_lost"

        /** The UI went away (Recents swipe) while the consented session lives on. */
        const val REASON_TASK_REMOVED_ACTIVE = "task_removed_active"

        /** The 15 s session watchdog observed that the parent ended the session. */
        const val REASON_SESSION_ENDED_BY_PARENT = "session_ended_by_parent"

        // Android 13 (API 33) requires POST_NOTIFICATIONS before a foreground
        // service notification can be shown. Kept as a literal so the pure
        // gate below stays unit-testable on the JVM.
        private const val NOTIFICATION_PERMISSION_API = 33

        private const val WAKE_LOCK_TAG = "parentcontrol:audio_assistance"
        private const val PERMISSION_CHECK_INTERVAL_MS = 5_000L
        private const val SESSION_WATCHDOG_INTERVAL_MS = 15_000L
        private const val CAPTURE_WATCH_INTERVAL_MS = 15_000L

        /**
         * The Dart isolate confirms live microphone capture every 10 s. Missing
         * confirmations for this long means the WebRTC engine or its capture is
         * gone, so the foreground service (and its microphone notification)
         * must stop instead of claiming that audio still runs.
         */
        const val CAPTURE_HEARTBEAT_TIMEOUT_MS = 45_000L
        private const val SESSION_STATE_FUNCTION = "remote-session"

        // Session states in which the backend still considers the session open.
        private val OPEN_SESSION_STATUSES = setOf("requested", "accepted", "active")

        @Volatile
        var isRunning: Boolean = false
            private set

        @Volatile
        var activeSessionId: String? = null
            private set

        /** Machine-readable reason of the last failed start, cleared on success. */
        @Volatile
        var lastError: String? = null
            private set

        /** elapsedRealtime of the newest Dart capture confirmation, 0 when none. */
        @Volatile
        var lastCaptureHeartbeatAt: Long = 0L
            private set

        /** True only while capture confirmations are fresh. */
        val isCaptureHealthy: Boolean
            get() {
                val last = lastCaptureHeartbeatAt
                return isRunning &&
                    last > 0L &&
                    android.os.SystemClock.elapsedRealtime() - last <=
                    CAPTURE_HEARTBEAT_TIMEOUT_MS
            }

        /** Age of the newest capture confirmation in ms, or null when none. */
        val captureHeartbeatAgeMs: Long?
            get() {
                val last = lastCaptureHeartbeatAt
                if (last <= 0L) return null
                return android.os.SystemClock.elapsedRealtime() - last
            }

        /**
         * Pure decision for a start request that reaches a service instance.
         *
         * - Nothing running: start normally.
         * - Same session (or one side has no id): do not restart capture or the
         *   watchdog; report the already-running service.
         * - A different session while running: refuse, never tear down the
         *   authorized session that is already live.
         */
        fun startDisposition(
            running: Boolean,
            currentSessionId: String?,
            requestedSessionId: String?
        ): StartDisposition {
            if (!running) return StartDisposition.START
            val current = currentSessionId?.trim().orEmpty()
            val requested = requestedSessionId?.trim().orEmpty()
            if (requested.isEmpty() || current.isEmpty()) {
                return StartDisposition.ALREADY_RUNNING
            }
            return if (current == requested) {
                StartDisposition.ALREADY_RUNNING
            } else {
                StartDisposition.BUSY_OTHER_SESSION
            }
        }

        /**
         * Pure decision for a stop intent that may have been queued behind a
         * newer start. A stop that names a different session than the one that
         * is running is stale ("stop the old session") and must never tear down
         * the session that replaced it. If either side has no id there is
         * nothing to compare, so the stop is treated as current.
         */
        fun stopTargetsOtherSession(
            currentSessionId: String?,
            stopSessionId: String?
        ): Boolean {
            val current = currentSessionId?.trim().orEmpty()
            val requested = stopSessionId?.trim().orEmpty()
            if (current.isEmpty() || requested.isEmpty()) return false
            return current != requested
        }

        /**
         * Pure capture-watchdog decision: stop only after a confirmation was
         * seen and then went stale. A service whose first heartbeat has not
         * arrived yet is covered by the same timeout measured from start.
         */
        fun captureWatchdogAction(
            running: Boolean,
            lastHeartbeatAt: Long,
            now: Long
        ): WatchdogDecision {
            if (!running || lastHeartbeatAt <= 0L) return WatchdogDecision.KEEP_RUNNING
            return if (now - lastHeartbeatAt > CAPTURE_HEARTBEAT_TIMEOUT_MS) {
                WatchdogDecision.STOP
            } else {
                WatchdogDecision.KEEP_RUNNING
            }
        }

        /**
         * Called by the Dart isolate while the WebRTC audio track is live.
         * Returns false when there is no matching running session, so the
         * caller learns that its confirmation was not accepted.
         */
        fun noteCaptureHeartbeat(sessionId: String?): Boolean {
            if (!isRunning) return false
            val active = activeSessionId
            val requested = sessionId?.trim().orEmpty()
            if (requested.isNotEmpty() && !active.isNullOrEmpty() && requested != active) {
                return false
            }
            lastCaptureHeartbeatAt = android.os.SystemClock.elapsedRealtime()
            return true
        }

        // True when the stop was deliberate (child, parent, permission
        // watchdog, or Dart) so onDestroy does not report "service_destroyed".
        @Volatile
        private var stopRequested: Boolean = false

        /**
         * Pure start gate shared by [start] and [onStartCommand].
         *
         * Returns the failure reason, or null when the service may start.
         * Extracted as a pure function so it can be covered by a JVM test.
         */
        fun startBlockReason(
            sdkInt: Int,
            microphoneGranted: Boolean,
            notificationsGranted: Boolean
        ): String? = when {
            !microphoneGranted -> REASON_PERMISSION_DENIED
            sdkInt >= NOTIFICATION_PERMISSION_API && !notificationsGranted ->
                REASON_NOTIFICATION_PERMISSION_REQUIRED
            else -> null
        }

        /**
         * Pure decision for one `remote-session` / `session_state` answer.
         *
         * - `requested`, `accepted`, `active` (case/whitespace insensitive) mean
         *   the session is still open: [WatchdogDecision.KEEP_RUNNING].
         * - Any other non-blank status is terminal (ended, declined, expired,
         *   cancelled, ...): [WatchdogDecision.STOP].
         * - A missing/blank status is an unusable answer, not proof that the
         *   session ended, so it keeps running. Transport errors never reach
         *   this function: the caller keeps running on any error as well.
         */
        fun sessionWatchdogAction(status: String?): WatchdogDecision {
            val normalized = status?.trim()?.lowercase(Locale.ROOT)
            if (normalized.isNullOrEmpty()) return WatchdogDecision.KEEP_RUNNING
            return if (normalized in OPEN_SESSION_STATUSES) {
                WatchdogDecision.KEEP_RUNNING
            } else {
                WatchdogDecision.STOP
            }
        }

        /** Convenience boolean form of [sessionWatchdogAction]. */
        fun shouldStopForSessionStatus(status: String): Boolean =
            sessionWatchdogAction(status) == WatchdogDecision.STOP

        /**
         * Requests the service. Returns true only when the system accepted the
         * request; the authoritative confirmation is the
         * `audio_assistance_started` event (or `audio_assistance_start_failed`).
         *
         * The permission/notification gate below runs first so Dart gets an
         * immediate false instead of starting a service that would have to stop
         * itself. Failures here are recorded in [lastError] and reported by the
         * return value; the running service is the only emitter of events.
         */
        fun start(context: Context, sessionId: String? = null): Boolean {
            val block = startBlockReason(
                Build.VERSION.SDK_INT,
                NativePermissions.hasMicrophone(context),
                NativePermissions.hasNotifications(context)
            )
            if (block != null) {
                lastError = block
                return false
            }
            return try {
                stopRequested = false
                val intent = Intent(context, AudioAssistanceService::class.java).apply {
                    if (sessionId != null) putExtra(EXTRA_SESSION_ID, sessionId)
                }
                ContextCompat.startForegroundService(context, intent)
                true
            } catch (error: Exception) {
                lastError = REASON_START_FOREGROUND_SERVICE_FAILED
                false
            }
        }

        /** Deliberate stop: suppresses the "service_destroyed" death report. */
        fun stop(context: Context) {
            stopRequested = true
            try {
                context.stopService(Intent(context, AudioAssistanceService::class.java))
            } catch (_: Exception) {
            }
        }
    }

    private val permissionHandler = Handler(Looper.getMainLooper())

    private var wakeLock: PowerManager.WakeLock? = null

    // Single background thread for the blocking session-state HTTP call.
    private var sessionWatchdog: ScheduledExecutorService? = null

    // Newest startId this instance received, used for startId-safe stops.
    private var lastStartId = 0

    /**
     * Watches RECORD_AUDIO for the whole session. A revoked permission is a
     * withdrawal of consent: report it and stop instead of silently keeping a
     * microphone foreground service alive.
     */
    private val permissionWatch = object : Runnable {
        override fun run() {
            if (!isRunning) return
            if (!NativePermissions.hasMicrophone(this@AudioAssistanceService)) {
                stopRequested = true
                isRunning = false
                activeSessionId = null
                lastCaptureHeartbeatAt = 0L
                lastError = REASON_PERMISSION_DENIED
                NativeEventBus.emitAudioAssistanceStopped(REASON_PERMISSION_DENIED)
                shutdown()
                return
            }
            permissionHandler.postDelayed(this, PERMISSION_CHECK_INTERVAL_MS)
        }
    }

    /**
     * Watches the Dart capture confirmations. The foreground service exists to
     * keep an actually running microphone capture alive; once capture is gone
     * (engine destroyed, track stopped, isolate frozen) the notification must
     * not keep claiming that the microphone is active.
     */
    private val captureWatch = object : Runnable {
        override fun run() {
            if (!isRunning) return
            if (captureWatchdogAction(
                    true,
                    lastCaptureHeartbeatAt,
                    android.os.SystemClock.elapsedRealtime()
                ) == WatchdogDecision.STOP
            ) {
                stopRequested = true
                isRunning = false
                activeSessionId = null
                lastCaptureHeartbeatAt = 0L
                NativeEventBus.emitAudioAssistanceStopped(REASON_CAPTURE_LOST)
                shutdown()
                return
            }
            permissionHandler.postDelayed(this, CAPTURE_WATCH_INTERVAL_MS)
        }
    }

    override fun onBind(intent: Intent?): IBinder? = null

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        // startId must never go backwards: a stale intent delivered late must
        // not shadow the newest start when a watchdog stops the service.
        lastStartId = maxOf(lastStartId, startId)
        val requestedSessionId = intent?.getStringExtra(EXTRA_SESSION_ID)

        if (intent?.action == ACTION_STOP) {
            // A stop for a session that has already been replaced is stale. It
            // must not clear the new session's state or stop its service.
            if (stopTargetsOtherSession(activeSessionId, requestedSessionId)) {
                return START_NOT_STICKY
            }
            stopRequested = true
            isRunning = false
            activeSessionId = null
            lastCaptureHeartbeatAt = 0L
            NativeEventBus.emitAudioAssistanceStopped("child_stopped")
            // stopSelf(startId) is a no-op when a newer start request was
            // already delivered, so a queued stop cannot kill a new session.
            shutdown(stopStartId = startId)
            return START_NOT_STICKY
        }

        when (startDisposition(isRunning, activeSessionId, requestedSessionId)) {
            StartDisposition.ALREADY_RUNNING -> {
                // Idempotent start: recreation (Activity, UI route, isolate
                // restore) must not restart capture, reset watchdogs or stack
                // notification updates. Adopt the id if the service started
                // without one.
                if (activeSessionId.isNullOrEmpty()) {
                    activeSessionId = requestedSessionId
                }
                // A visible Join may be adopting a service that outlived its
                // Dart isolate. Give the handshake a fresh watchdog window;
                // capture heartbeats must still follow or the service stops.
                lastCaptureHeartbeatAt = android.os.SystemClock.elapsedRealtime()
                lastError = null
                NativeEventBus.emitAudioAssistanceStarted(activeSessionId)
                return START_NOT_STICKY
            }
            StartDisposition.BUSY_OTHER_SESSION -> {
                // Never tear down the authorized session that is already live.
                lastError = REASON_SESSION_MISMATCH
                NativeEventBus.emitAudioAssistanceStartFailed(REASON_SESSION_MISMATCH)
                return START_NOT_STICKY
            }
            StartDisposition.START -> Unit
        }

        // A fresh start clears a "deliberate stop" left by an earlier stop.
        stopRequested = false

        val block = startBlockReason(
            Build.VERSION.SDK_INT,
            NativePermissions.hasMicrophone(this),
            NativePermissions.hasNotifications(this)
        )
        if (block != null) {
            failStart(block)
            return START_NOT_STICKY
        }

        activeSessionId = requestedSessionId
        createChannel()
        if (!startAsForeground()) {
            failStart(REASON_START_FOREGROUND_FAILED)
            return START_NOT_STICKY
        }

        isRunning = true
        lastError = null
        // Grace period: capture confirmations start once the Dart side has
        // created its peer connection.
        lastCaptureHeartbeatAt = android.os.SystemClock.elapsedRealtime()
        acquireWakeLock()
        startPermissionWatch()
        startCaptureWatch()
        startSessionWatchdog()
        NativeEventBus.emitAudioAssistanceStarted(activeSessionId)

        return START_NOT_STICKY
    }

    override fun onDestroy() {
        stopPermissionWatch()
        stopCaptureWatch()
        stopSessionWatchdog()
        releaseWakeLock()
        isRunning = false
        activeSessionId = null
        lastCaptureHeartbeatAt = 0L
        stopForegroundCompat()
        val deathWasUnrequested = !stopRequested
        stopRequested = false
        if (deathWasUnrequested) {
            NativeEventBus.emitAudioAssistanceStopped("service_destroyed")
        }
        super.onDestroy()
    }

    /**
     * The task was swiped from Recents while a consented session is active.
     *
     * Approved policy: that is NOT a withdrawal of consent. The service keeps
     * running with [isRunning] and [activeSessionId] unchanged, the wake lock
     * stays held and the ongoing notification (with its Stop action) stays
     * visible, so capture continues until the child stops it, the parent ends
     * it, or the microphone permission is revoked. Dart is merely told that the
     * UI is detached, through the non-terminal `audio_assistance_detached`
     * event. Force-stop, reboot and OEM task cleaners still end the service.
     */
    override fun onTaskRemoved(rootIntent: Intent?) {
        if (isRunning) {
            NativeEventBus.emitAudioAssistanceDetached(
                REASON_TASK_REMOVED_ACTIVE,
                activeSessionId
            )
        }
        super.onTaskRemoved(rootIntent)
    }

    /**
     * Emits the failure event, updates the status snapshot, and tears the
     * service down without ever reporting a successful start.
     */
    private fun failStart(reason: String) {
        // The service is going away on purpose: do not also report
        // "service_destroyed" from onDestroy.
        stopRequested = true
        isRunning = false
        activeSessionId = null
        lastCaptureHeartbeatAt = 0L
        lastError = reason
        NativeEventBus.emitAudioAssistanceStartFailed(reason)
        stopPermissionWatch()
        stopCaptureWatch()
        stopSessionWatchdog()
        releaseWakeLock()
        stopForegroundCompat()
        shutdown()
    }

    /**
     * Stops this instance. With [useStartId] the newest start id is used, so a
     * newer start request (for example a recreated UI) is not stopped by a
     * watchdog decision that belonged to an older one. [stopStartId] pins the
     * id of a specific intent (the notification's Stop action), so a stop that
     * was queued before a newer start cannot stop it.
     */
    private fun shutdown(useStartId: Boolean = true, stopStartId: Int? = null) {
        stopPermissionWatch()
        stopCaptureWatch()
        stopSessionWatchdog()
        releaseWakeLock()
        stopForegroundCompat()
        if (!useStartId) {
            stopSelf()
            return
        }
        val id = stopStartId ?: lastStartId
        if (id > 0) {
            stopSelf(id)
        } else {
            stopSelf()
        }
    }

    private fun createChannel() {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.O) return
        val manager = getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
        val existing = manager.getNotificationChannel(CHANNEL_ID)
        if (existing != null) return

        val channel = NotificationChannel(
            CHANNEL_ID,
            getString(R.string.audio_assistance_channel_name),
            NotificationManager.IMPORTANCE_LOW
        ).apply {
            description = getString(R.string.audio_assistance_channel_description)
            setShowBadge(false)
        }
        manager.createNotificationChannel(channel)
    }

    private fun buildNotification(): Notification {
        val openIntent = Intent(this, MainActivity::class.java).apply {
            flags = Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_CLEAR_TOP
        }
        val openPendingIntent = PendingIntent.getActivity(
            this,
            0,
            openIntent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        )

        val stopIntent = Intent(this, AudioAssistanceService::class.java).apply {
            action = ACTION_STOP
            // Scope the stop to the session it was shown for: a queued stop
            // must not apply to a session that replaced it.
            activeSessionId?.let { putExtra(EXTRA_SESSION_ID, it) }
        }
        val stopPendingIntent = PendingIntent.getService(
            this,
            1,
            stopIntent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        )

        return NotificationCompat.Builder(this, CHANNEL_ID)
            .setContentTitle(getString(R.string.audio_assistance_notification_title))
            .setContentText(getString(R.string.audio_assistance_notification_text))
            .setSmallIcon(R.drawable.ic_stat_guardian)
            .setContentIntent(openPendingIntent)
            .addAction(
                android.R.drawable.ic_menu_close_clear_cancel,
                getString(R.string.audio_assistance_stop_action),
                stopPendingIntent
            )
            .setOngoing(true)
            .setOnlyAlertOnce(true)
            .setPriority(NotificationCompat.PRIORITY_LOW)
            .setCategory(NotificationCompat.CATEGORY_CALL)
            .build()
    }

    /**
     * Returns true only when startForeground actually succeeded. Never throws:
     * ForegroundServiceStartNotAllowedException, SecurityException and
     * MissingForegroundServiceTypeException are all reported as `false`.
     */
    private fun startAsForeground(): Boolean {
        return try {
            val notification = buildNotification()
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.R) {
                // FOREGROUND_SERVICE_TYPE_MICROPHONE only exists from API 30 (R).
                startForeground(
                    NOTIFICATION_ID,
                    notification,
                    ServiceInfo.FOREGROUND_SERVICE_TYPE_MICROPHONE
                )
            } else {
                startForeground(NOTIFICATION_ID, notification)
            }
            true
        } catch (error: Throwable) {
            // Catching Throwable also covers OEM-specific runtime failures.
            stopForegroundCompat()
            false
        }
    }

    private fun stopForegroundCompat() {
        try {
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.N) {
                stopForeground(STOP_FOREGROUND_REMOVE)
            } else {
                @Suppress("DEPRECATION")
                stopForeground(true)
            }
        } catch (_: Throwable) {
            // Not in the foreground state any more; nothing to remove.
        }
    }

    private fun acquireWakeLock() {
        if (wakeLock?.isHeld == true) return
        try {
            val manager = getSystemService(Context.POWER_SERVICE) as? PowerManager ?: return
            val lock = manager.newWakeLock(PowerManager.PARTIAL_WAKE_LOCK, WAKE_LOCK_TAG)
            lock.setReferenceCounted(false)
            lock.acquire()
            wakeLock = lock
        } catch (_: Throwable) {
            // Wake locks are best effort; the session continues without one.
            wakeLock = null
        }
    }

    private fun releaseWakeLock() {
        val lock = wakeLock ?: return
        wakeLock = null
        try {
            if (lock.isHeld) lock.release()
        } catch (_: Throwable) {
            // Already released by the system.
        }
    }

    private fun startPermissionWatch() {
        permissionHandler.removeCallbacks(permissionWatch)
        permissionHandler.postDelayed(permissionWatch, PERMISSION_CHECK_INTERVAL_MS)
    }

    private fun stopPermissionWatch() {
        permissionHandler.removeCallbacks(permissionWatch)
    }

    private fun startCaptureWatch() {
        permissionHandler.removeCallbacks(captureWatch)
        permissionHandler.postDelayed(captureWatch, CAPTURE_WATCH_INTERVAL_MS)
    }

    private fun stopCaptureWatch() {
        permissionHandler.removeCallbacks(captureWatch)
    }

    /**
     * Parent-termination watchdog. Every 15 s (and only while the service is
     * running) it asks `remote-session` whether [activeSessionId] is still open,
     * so an active session does not outlive a deliberate parent stop while the
     * child UI is gone.
     *
     * The blocking HTTPS call runs on its own single thread; the stop decision
     * is applied on the main thread through [permissionHandler].
     */
    private fun startSessionWatchdog() {
        stopSessionWatchdog()
        val executor = try {
            Executors.newSingleThreadScheduledExecutor()
        } catch (_: Throwable) {
            // Without the watchdog the session still runs; only the parent-end
            // detection is unavailable.
            return
        }
        sessionWatchdog = executor
        try {
            executor.scheduleWithFixedDelay(
                { runCatching { pollSessionState() } },
                SESSION_WATCHDOG_INTERVAL_MS,
                SESSION_WATCHDOG_INTERVAL_MS,
                TimeUnit.MILLISECONDS
            )
        } catch (_: Throwable) {
            stopSessionWatchdog()
        }
    }

    private fun stopSessionWatchdog() {
        val executor = sessionWatchdog ?: return
        sessionWatchdog = null
        try {
            executor.shutdownNow()
        } catch (_: Throwable) {
            // Already stopped.
        }
    }

    /**
     * One session-state round trip. Any failure (offline, 401/404 because the
     * hosted function does not know `session_state` yet, malformed body) is
     * treated as "unknown": the session keeps running and no error is surfaced,
     * because a transient network problem is not proof that the parent stopped.
     * Credentials are never logged.
     */
    private fun pollSessionState() {
        if (!isRunning) return
        val sessionId = activeSessionId ?: return
        val config = try {
            SecureStore.get(applicationContext).config()
        } catch (_: Throwable) {
            null
        } ?: return // Not configured: skip polling silently.
        val data = try {
            DeviceHttpClient(config).post(
                SESSION_STATE_FUNCTION,
                JSONObject()
                    .put("action", "session_state")
                    .put("session_id", sessionId)
            )
        } catch (_: Throwable) {
            return
        }
        val status = if (data.isNull("status")) null else data.optString("status", "")
        if (sessionWatchdogAction(status) != WatchdogDecision.STOP) return
        stopAfterParentEnded(sessionId)
    }

    /** Applies a terminal session status on the main thread, once. */
    private fun stopAfterParentEnded(observedSessionId: String) {
        permissionHandler.post {
            if (!isRunning) return@post
            // A response for a session that has since been replaced is stale.
            if (activeSessionId != observedSessionId) return@post
            stopRequested = true
            isRunning = false
            activeSessionId = null
            lastCaptureHeartbeatAt = 0L
            NativeEventBus.emitAudioAssistanceStopped(REASON_SESSION_ENDED_BY_PARENT)
            shutdown()
        }
    }
}

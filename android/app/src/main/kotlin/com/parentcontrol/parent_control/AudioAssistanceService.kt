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
 * The service never records audio. It only keeps the process eligible to use
 * the microphone through the ongoing WebRTC session, and it stops as soon as
 * the child withdraws consent, the task is removed, or the microphone
 * permission is revoked.
 *
 * Startup is confirmed to Dart with `audio_assistance_started`; every failure
 * to start inside the service emits `audio_assistance_start_failed` with a
 * machine-readable reason and leaves [isRunning] false. When [start] can reject
 * the request up front it returns false and only records [lastError].
 */
class AudioAssistanceService : Service() {
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

        // Android 13 (API 33) requires POST_NOTIFICATIONS before a foreground
        // service notification can be shown. Kept as a literal so the pure
        // gate below stays unit-testable on the JVM.
        private const val NOTIFICATION_PERMISSION_API = 33

        private const val WAKE_LOCK_TAG = "parentcontrol:audio_assistance"
        private const val PERMISSION_CHECK_INTERVAL_MS = 5_000L

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

        // True when the stop was deliberate (child, task removal, permission
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
                lastError = REASON_PERMISSION_DENIED
                NativeEventBus.emitAudioAssistanceStopped(REASON_PERMISSION_DENIED)
                shutdown()
                return
            }
            permissionHandler.postDelayed(this, PERMISSION_CHECK_INTERVAL_MS)
        }
    }

    override fun onBind(intent: Intent?): IBinder? = null

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        if (intent?.action == ACTION_STOP) {
            stopRequested = true
            isRunning = false
            activeSessionId = null
            NativeEventBus.emitAudioAssistanceStopped("child_stopped")
            shutdown()
            return START_NOT_STICKY
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

        activeSessionId = intent?.getStringExtra(EXTRA_SESSION_ID)
        createChannel()
        if (!startAsForeground()) {
            failStart(REASON_START_FOREGROUND_FAILED)
            return START_NOT_STICKY
        }

        isRunning = true
        lastError = null
        acquireWakeLock()
        startPermissionWatch()
        NativeEventBus.emitAudioAssistanceStarted(activeSessionId)

        return START_NOT_STICKY
    }

    override fun onDestroy() {
        stopPermissionWatch()
        releaseWakeLock()
        isRunning = false
        activeSessionId = null
        stopForegroundCompat()
        val deathWasUnrequested = !stopRequested
        stopRequested = false
        if (deathWasUnrequested) {
            NativeEventBus.emitAudioAssistanceStopped("service_destroyed")
        }
        super.onDestroy()
    }

    override fun onTaskRemoved(rootIntent: Intent?) {
        // Swiping the task away from Recents is treated as withdrawing consent.
        stopRequested = true
        isRunning = false
        activeSessionId = null
        NativeEventBus.emitAudioAssistanceStopped("task_removed")
        shutdown()
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
        lastError = reason
        NativeEventBus.emitAudioAssistanceStartFailed(reason)
        stopPermissionWatch()
        releaseWakeLock()
        stopForegroundCompat()
        stopSelf()
    }

    private fun shutdown() {
        stopPermissionWatch()
        releaseWakeLock()
        stopForegroundCompat()
        stopSelf()
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
}

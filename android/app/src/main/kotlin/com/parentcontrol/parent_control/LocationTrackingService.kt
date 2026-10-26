package com.parentcontrol.parent_control

import android.Manifest
import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.app.Service
import android.content.Context
import android.content.Intent
import android.content.pm.PackageManager
import android.content.pm.ServiceInfo
import android.location.Location
import android.location.LocationListener
import android.location.LocationManager
import android.os.Build
import android.os.Bundle
import android.os.IBinder
import android.os.Looper
import androidx.core.app.NotificationCompat
import androidx.core.content.ContextCompat

/**
 * Visible, permission-gated location sharing.
 *
 * It only runs after the child explicitly enables sharing in the app. Mock
 * fixes are forwarded with isMock=true instead of being treated as real
 * positions. No location is collected while this service is not running.
 */
class LocationTrackingService : Service(), LocationListener {
    companion object {
        const val EXTRA_INTERVAL_SECONDS = "intervalSeconds"
        private const val CHANNEL_ID = "location_sharing"
        private const val NOTIFICATION_ID = 4202
        private const val DEFAULT_INTERVAL_SECONDS = 60

        @Volatile
        var isRunning: Boolean = false
            private set

        fun start(context: Context, intervalSeconds: Int): Boolean {
            return try {
                val intent = Intent(context, LocationTrackingService::class.java)
                    .putExtra(EXTRA_INTERVAL_SECONDS, intervalSeconds)
                ContextCompat.startForegroundService(context, intent)
                true
            } catch (_: Exception) {
                false
            }
        }

        fun stop(context: Context) {
            context.stopService(Intent(context, LocationTrackingService::class.java))
        }
    }

    private var locationManager: LocationManager? = null
    private var intervalMs: Long = DEFAULT_INTERVAL_SECONDS * 1000L

    override fun onBind(intent: Intent?): IBinder? = null

    override fun onCreate() {
        super.onCreate()
        createChannel()
        if (!NativePermissions.hasFineLocation(this)) {
            stopSelf()
            return
        }
        if (!NativePermissions.hasNotifications(this)) {
            // A location foreground service must stay visible to the user.
            stopSelf()
            return
        }
        try {
            startAsForeground()
        } catch (_: Exception) {
            stopSelf()
            return
        }
        isRunning = true
    }

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        if (!isRunning) {
            stopSelf()
            return START_NOT_STICKY
        }
        val requested = intent?.getIntExtra(EXTRA_INTERVAL_SECONDS, DEFAULT_INTERVAL_SECONDS)
            ?: DEFAULT_INTERVAL_SECONDS
        intervalMs = requested.coerceIn(15, 3600) * 1000L
        if (!startUpdates()) {
            isRunning = false
            stopSelf()
            return START_NOT_STICKY
        }
        return START_STICKY
    }

    override fun onDestroy() {
        isRunning = false
        try {
            locationManager?.removeUpdates(this)
        } catch (_: Exception) {
            // Nothing else to release.
        }
        locationManager = null
        LiveState.clear()
        stopForegroundCompat()
        super.onDestroy()
    }

    private fun startUpdates(): Boolean {
        val manager = try {
            getSystemService(Context.LOCATION_SERVICE) as LocationManager
        } catch (_: Exception) {
            return false
        }
        locationManager = manager
        val providers = ArrayList<String>()
        try {
            if (manager.isProviderEnabled(LocationManager.GPS_PROVIDER)) {
                providers.add(LocationManager.GPS_PROVIDER)
            }
            if (manager.isProviderEnabled(LocationManager.NETWORK_PROVIDER)) {
                providers.add(LocationManager.NETWORK_PROVIDER)
            }
        } catch (_: Exception) {
            return false
        }
        if (providers.isEmpty()) return false

        // Seed the last known position so a fresh start is not blank, marked
        // with its real timestamp and mock flag.
        for (provider in providers) {
            val last = try {
                manager.getLastKnownLocation(provider)
            } catch (_: SecurityException) {
                null
            } catch (_: Exception) {
                null
            }
            if (last != null) {
                publish(last)
            }
        }

        var requested = false
        for (provider in providers) {
            try {
                manager.requestLocationUpdates(provider, intervalMs, 0f, this, Looper.getMainLooper())
                requested = true
            } catch (_: SecurityException) {
                return false
            } catch (_: Exception) {
                // Try the next provider; failure of all is reported below.
            }
        }
        if (requested) {
            LiveState.tracking = true
        }
        return requested
    }

    private fun publish(location: Location) {
        if (!isRunning) return
        val lat = location.latitude
        val lng = location.longitude
        if (lat.isNaN() || lng.isNaN() || lat < -90.0 || lat > 90.0 || lng < -180.0 || lng > 180.0) {
            return
        }
        val mock = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
            location.isMock
        } else {
            @Suppress("DEPRECATION")
            location.isFromMockProvider
        }
        val fix = LiveFix(
            lat = lat,
            lng = lng,
            accuracyM = location.accuracy.toDouble(),
            timestampMillis = location.time,
            isMock = mock,
            source = location.provider ?: "unknown"
        )
        LiveState.update(fix)
        NativeEventBus.emitLocation(fix)
    }

    override fun onLocationChanged(location: Location) {
        publish(location)
    }

    @Deprecated("Required by LocationListener on older Android versions")
    override fun onStatusChanged(provider: String?, status: Int, extras: Bundle?) {
        // No action: fixes are published when they arrive.
    }

    override fun onProviderEnabled(provider: String) {
        // The next tick or fix reflects the new provider state.
    }

    override fun onProviderDisabled(provider: String) {
        // Keep listening to other providers; the system may re-enable this one.
    }

    private fun createChannel() {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.O) return
        val manager = getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
        if (manager.getNotificationChannel(CHANNEL_ID) != null) return
        val channel = NotificationChannel(
            CHANNEL_ID,
            getString(R.string.location_channel_name),
            NotificationManager.IMPORTANCE_LOW
        ).apply {
            description = getString(R.string.location_channel_description)
            setShowBadge(false)
        }
        manager.createNotificationChannel(channel)
    }

    private fun buildNotification(): Notification {
        val intent = Intent(this, MainActivity::class.java).apply {
            flags = Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_CLEAR_TOP
        }
        val pendingIntent = PendingIntent.getActivity(
            this,
            0,
            intent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        )
        return NotificationCompat.Builder(this, CHANNEL_ID)
            .setContentTitle(getString(R.string.location_notification_title))
            .setContentText(getString(R.string.location_notification_text))
            .setSmallIcon(R.drawable.ic_stat_guardian)
            .setContentIntent(pendingIntent)
            .setOngoing(true)
            .setOnlyAlertOnce(true)
            .setPriority(NotificationCompat.PRIORITY_LOW)
            .build()
    }

    private fun startAsForeground() {
        val notification = buildNotification()
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
            startForeground(
                NOTIFICATION_ID,
                notification,
                ServiceInfo.FOREGROUND_SERVICE_TYPE_LOCATION
            )
        } else {
            startForeground(NOTIFICATION_ID, notification)
        }
    }

    private fun stopForegroundCompat() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.N) {
            stopForeground(STOP_FOREGROUND_REMOVE)
        } else {
            @Suppress("DEPRECATION")
            stopForeground(true)
        }
    }
}

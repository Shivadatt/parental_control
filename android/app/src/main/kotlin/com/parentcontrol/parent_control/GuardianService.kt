package com.parentcontrol.parent_control

import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.app.Service
import android.content.Context
import android.content.Intent
import android.content.pm.ServiceInfo
import android.os.BatteryManager
import android.os.Build
import android.os.IBinder
import android.net.ConnectivityManager
import android.net.NetworkCapabilities
import androidx.core.app.NotificationCompat
import androidx.core.content.ContextCompat
import org.json.JSONArray
import org.json.JSONObject
import java.net.HttpURLConnection
import java.util.concurrent.Executors
import java.util.concurrent.ScheduledExecutorService
import java.util.concurrent.TimeUnit

/**
 * Visible background sync service.
 *
 * Android limits are real: starting a dataSync foreground service from the
 * background is restricted on Android 12+, Android 15 blocks starting it from
 * BOOT_COMPLETED and caps dataSync runtime. When the system blocks a start the
 * error is stored and surfaced, never hidden.
 */
class GuardianService : Service() {
    companion object {
        private const val CHANNEL_ID = "guardian_status"
        private const val NOTIFICATION_ID = 4101
        private const val POLL_INTERVAL_MS = 20_000L
        private const val POLICY_TICK_MS = 60_000L
        private const val HEARTBEAT_MS = 5 * 60_000L
        private const val APPS_UPLOAD_MS = 30 * 60_000L
        private const val USAGE_UPLOAD_MS = 60 * 60_000L

        @Volatile
        var isRunning: Boolean = false
            private set

        @Volatile
        var pendingAcks: Int = 0

        @Volatile
        var lastError: String? = null

        fun start(context: Context): Boolean {
            return try {
                ContextCompat.startForegroundService(
                    context,
                    Intent(context, GuardianService::class.java)
                )
                true
            } catch (error: Exception) {
                SecureStore.get(context).setLastError(
                    "Android blocked the background service from starting. " +
                        "Open Parent Control and try again."
                )
                false
            }
        }

        fun stop(context: Context) {
            context.stopService(Intent(context, GuardianService::class.java))
        }
    }

    private data class BatteryState(val level: Int?, val charging: Boolean)

    private lateinit var store: SecureStore
    private lateinit var applier: PolicyApplier
    private lateinit var executor: ScheduledExecutorService
    private var nextPollAllowedAt = 0L
    private var pollBackoffMs = POLL_INTERVAL_MS
    private var lastHeartbeatAt = 0L
    private var lastAppsUploadAt = 0L
    private var lastUsageUploadAt = 0L
    private var lastPolicyTickAt = 0L
    private var lastLocationUploadMillis = 0L
    private var lastMockWarningMillis = 0L

    override fun onBind(intent: Intent?): IBinder? = null

    override fun onCreate() {
        super.onCreate()
        store = try {
            SecureStore.get(applicationContext)
        } catch (error: Exception) {
            lastError = "Encrypted storage could not be opened."
            stopSelf()
            return
        }
        applier = PolicyApplier(applicationContext, store)
        isRunning = true
        NativeEventBus.emitServiceStatus(true, store.lastError())
        createChannel()
        try {
            startAsForeground(getString(R.string.guardian_notification_text))
        } catch (error: Exception) {
            recordError("The background service notification could not be shown.")
            stopSelf()
            return
        }
        if (!store.hasConfig()) {
            recordError("Background sync is not configured on this device.")
            stopSelf()
            return
        }
        if (!NativePermissions.hasNotifications(this)) {
            recordError("Notification permission is required for visible background sync.")
            stopSelf()
            return
        }
        executor = Executors.newSingleThreadScheduledExecutor()
        executor.scheduleWithFixedDelay(
            { runCatching { tick() }.onFailure { recordError(it.message ?: "Background sync stopped unexpectedly.") } },
            0L,
            10L,
            TimeUnit.SECONDS
        )
    }

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        if (!::store.isInitialized || !store.hasConfig()) {
            stopSelf()
            return START_NOT_STICKY
        }
        return START_STICKY
    }

    override fun onDestroy() {
        isRunning = false
        pendingAcks = 0
        if (::executor.isInitialized) {
            executor.shutdownNow()
        }
        val error = if (::store.isInitialized) store.lastError() else lastError
        NativeEventBus.emitServiceStatus(false, error)
        super.onDestroy()
        stopForegroundCompat()
    }

    /**
     * Android 15+ enforces time limits on dataSync foreground services. The
     * system requires a prompt stop; the limitation is surfaced, not hidden.
     */
    override fun onTimeout(startId: Int) {
        handleServiceTimeout()
    }

    override fun onTimeout(startId: Int, fgsType: Int) {
        handleServiceTimeout()
    }

    private fun handleServiceTimeout() {
        recordError(
            "Android stopped background sync because its time limit was reached. " +
                "Open Parent Control to resume it."
        )
        stopSelf()
    }

    private fun tick() {
        if (!isRunning) return
        if (!store.shouldRunGuardian()) {
            stopSelf()
            return
        }
        val config = store.config()
        if (config == null) {
            recordError("Background sync is not configured on this device.")
            stopSelf()
            return
        }
        val client = DeviceHttpClient(config)
        val now = System.currentTimeMillis()

        if (now - lastPolicyTickAt >= POLICY_TICK_MS) {
            lastPolicyTickAt = now
            val result = applier.tick()
            if (result != null) {
                val errors = result.optJSONArray("errors")
                if (errors != null && errors.length() > 0) {
                    recordError(errorSummary(errors))
                }
            }
        }

        if (now >= nextPollAllowedAt) {
            try {
                pollCommands(client)
                pollBackoffMs = POLL_INTERVAL_MS
                nextPollAllowedAt = now + POLL_INTERVAL_MS
            } catch (error: Exception) {
                val status = (error as? DeviceHttpException)?.statusCode ?: 0
                val multiplier = when {
                    status == HttpURLConnection.HTTP_UNAUTHORIZED -> 6
                    status == HttpURLConnection.HTTP_FORBIDDEN -> 6
                    status == 429 -> 3
                    else -> 2
                }
                pollBackoffMs = (pollBackoffMs * multiplier).coerceAtMost(300_000L)
                nextPollAllowedAt = now + pollBackoffMs
                recordError("Background sync failed: ${error.message?.take(200) ?: "network error"}")
            }
        }

        if (now - lastHeartbeatAt >= HEARTBEAT_MS) {
            lastHeartbeatAt = if (sendHeartbeat(client)) now else now - HEARTBEAT_MS + 60_000L
        }
        if (now - lastAppsUploadAt >= APPS_UPLOAD_MS) {
            if (uploadApps(client)) lastAppsUploadAt = now
        }
        if (now - lastUsageUploadAt >= USAGE_UPLOAD_MS) {
            if (uploadUsage(client) > 0) lastUsageUploadAt = now
        }
        uploadPendingLocation(client)
    }

    private fun pollCommands(client: DeviceHttpClient) {
        val data = client.post(
            "device-command",
            JSONObject().put("action", "poll")
        )
        store.setLastPollAt(System.currentTimeMillis())
        clearError()
        val commands = data.optJSONArray("commands") ?: JSONArray()
        for (index in 0 until commands.length()) {
            val command = commands.optJSONObject(index) ?: continue
            handleCommand(client, command)
        }
    }

    private fun handleCommand(client: DeviceHttpClient, command: JSONObject) {
        val commandId = command.optString("id", "").trim()
        if (commandId.isEmpty()) return
        if (store.handledCommands().contains(commandId)) return
        val commandType = command.optString("type", "")
        val expiresAt = TimeUtils.parseIso(command.optString("expires_at"))
        if (expiresAt != null && expiresAt < System.currentTimeMillis()) {
            store.markCommandHandled(commandId)
            pendingAcks += 1
            try {
                sendAck(client, commandId, "expired", JSONObject())
            } catch (error: Exception) {
                recordError("An expired command could not be acknowledged.")
            } finally {
                pendingAcks -= 1
            }
            NativeEventBus.emitCommand(commandId, commandType, "expired")
            return
        }

        val payload = command.optJSONObject("payload") ?: JSONObject()
        var status = "failed"
        var result = JSONObject()
        var errorMessage: String? = null
        pendingAcks += 1
        try {
            when (commandType) {
                "apply_policy" -> {
                    val policy = payload.optJSONObject("policy")
                    if (policy == null) {
                        errorMessage = "The apply_policy command did not include a policy."
                    } else {
                        val version = payload.optInt("version", store.appliedVersion())
                        result = applier.apply(policy, version)
                        val success = result.optBoolean("success", false)
                        status = if (success) "succeeded" else "failed"
                        if (!success) errorMessage = errorSummary(result.optJSONArray("errors"))
                        if (success) {
                            uploadApps(client)
                            lastAppsUploadAt = System.currentTimeMillis()
                        }
                    }
                }
                "sync_policy" -> {
                    result = applier.applyStoredPolicy()
                    val success = result.optBoolean("success", false)
                    status = if (success) "succeeded" else "failed"
                    if (!success) errorMessage = errorSummary(result.optJSONArray("errors"))
                    val appsUploaded = uploadApps(client)
                    if (appsUploaded) {
                        lastAppsUploadAt = System.currentTimeMillis()
                    }
                    val usageUploaded = uploadUsage(client)
                    if (usageUploaded > 0) {
                        lastUsageUploadAt = System.currentTimeMillis()
                    }
                    result.put("apps_uploaded", appsUploaded)
                    result.put("usage_entries_uploaded", usageUploaded)
                }
                "request_usage" -> {
                    val uploaded = uploadUsage(client)
                    if (uploaded > 0) {
                        status = "succeeded"
                        result = JSONObject().put("uploaded", uploaded)
                    } else {
                        errorMessage = "No usage data could be uploaded. Check Usage Access on the device."
                    }
                }
                "request_location" -> {
                    val fix = LiveState.lastFix
                    if (!LiveState.tracking || fix == null) {
                        errorMessage = "Location sharing is not active on this device."
                    } else {
                        val uploaded = uploadLocation(client, fix)
                        if (uploaded) {
                            status = "succeeded"
                            result = JSONObject().put("uploaded", true)
                        } else {
                            errorMessage = "The location fix could not be uploaded."
                        }
                    }
                }
                "end_session" -> {
                    NativeEventBus.emitCommand(commandId, commandType, "failed")
                    errorMessage = "Session media is managed by the visible assistance screen and " +
                        "cannot be ended by the background service."
                }
                else -> {
                    errorMessage = "Unsupported command type: ${commandType.ifBlank { "unknown" }}."
                }
            }
        } catch (error: Exception) {
            errorMessage = error.message?.take(300) ?: "The command could not be executed."
        } finally {
            pendingAcks -= 1
        }

        if (errorMessage != null) {
            result.put("errors", JSONArray().put(errorMessage))
            recordError(errorMessage)
        }
        store.markCommandHandled(commandId)
        try {
            sendAck(client, commandId, status, result)
        } catch (error: Exception) {
            recordError("The command result could not be delivered to the server.")
        }
        NativeEventBus.emitCommand(commandId, commandType, status)
    }

    /** The ack schema is exactly {action, command_id, status, result}. */
    private fun sendAck(
        client: DeviceHttpClient,
        commandId: String,
        status: String,
        result: JSONObject
    ) {
        val body = JSONObject()
            .put("action", "ack")
            .put("command_id", commandId)
            .put("status", status)
            .put("result", result)
        client.post("device-command", body)
    }

    private fun sendHeartbeat(client: DeviceHttpClient): Boolean {
        return try {
            val battery = batteryStatus()
            val capabilities = JSONObject()
                .put("enforcement_mode", enforcementMode())
                .put("usage_access_granted", NativePermissions.hasUsageAccess(this))
                .put("location_granted", NativePermissions.hasFineLocation(this))
                .put("background_location_granted", NativePermissions.hasBackgroundLocation(this))
                .put("camera_granted", NativePermissions.hasCamera(this))
                .put("microphone_granted", NativePermissions.hasMicrophone(this))
                .put("notifications_granted", NativePermissions.hasNotifications(this))
            val body = JSONObject()
                .put("action", "heartbeat")
                .put("is_charging", battery.charging)
                .put("online", isOnline())
                .put("capabilities", capabilities)
            // No invented value: the field is omitted when the device does not
            // report a battery percentage.
            battery.level?.let { body.put("battery_level", it) }
            val data = client.post("device-telemetry", body)
            val pending = data.optInt("pending_policy_version", 0)
            if (pending > store.appliedVersion()) {
                nextPollAllowedAt = 0L
            }
            true
        } catch (error: Exception) {
            recordError("Heartbeat failed: ${error.message?.take(200) ?: "network error"}")
            false
        }
    }

    private fun uploadApps(client: DeviceHttpClient): Boolean {
        return try {
            val installed = InstalledAppsProvider.load(this).take(500)
            if (installed.isEmpty()) return false
            val owner = applier.isDeviceOwner()
            val apps = JSONArray()
            for (app in installed) {
                val entry = JSONObject()
                    .put("package_name", app.packageName)
                    .put("label", app.label)
                    .put("is_system", app.isSystem)
                    // Without Device Owner the OS gives us no authoritative value;
                    // false is reported rather than claiming that an app is blocked.
                    .put("is_suspended", owner && applier.isSuspended(app.packageName))
                    .put("version_name", app.versionName ?: "")
                apps.put(entry)
            }
            client.post(
                "device-telemetry",
                JSONObject().put("action", "apps_upload").put("apps", apps)
            )
            true
        } catch (error: Exception) {
            recordError("App list upload failed: ${error.message?.take(200) ?: "network error"}")
            false
        }
    }

    private fun uploadUsage(client: DeviceHttpClient): Int {
        if (!UsageReporter.hasAccess(this)) {
            recordError("Usage Access is not granted; usage cannot be uploaded.")
            return 0
        }
        return try {
            val now = System.currentTimeMillis()
            val start = TimeUtils.addDays(TimeUtils.startOfLocalDay(now), -1)
            val rows = UsageReporter.query(this, start, now).take(500)
            if (rows.isEmpty()) return 0
            val entries = JSONArray()
            for (row in rows) {
                val entry = JSONObject()
                    .put("day", row.day)
                    .put("package_name", row.packageName)
                    .put("app_label", row.label)
                    .put("total_ms", row.totalMs)
                val lastUsed = row.lastUsedAtMillis
                if (lastUsed != null) {
                    entry.put("last_used_at", TimeUtils.isoFromMillis(lastUsed))
                }
                entries.put(entry)
            }
            val data = client.post(
                "device-telemetry",
                JSONObject().put("action", "usage_upload").put("entries", entries)
            )
            data.optInt("accepted", entries.length())
        } catch (error: Exception) {
            recordError("Usage upload failed: ${error.message?.take(200) ?: "network error"}")
            0
        }
    }

    private fun uploadPendingLocation(client: DeviceHttpClient) {
        if (!LiveState.tracking) return
        val fix = LiveState.lastFix ?: return
        if (fix.timestampMillis <= lastLocationUploadMillis) return
        if (fix.isMock) {
            val now = System.currentTimeMillis()
            if (now - lastMockWarningMillis > 5 * 60_000L) {
                lastMockWarningMillis = now
                recordError("A mock location provider is active; the location was not uploaded.")
            }
            lastLocationUploadMillis = fix.timestampMillis
            return
        }
        if (uploadLocation(client, fix)) {
            lastLocationUploadMillis = fix.timestampMillis
        }
    }

    private fun uploadLocation(client: DeviceHttpClient, fix: LiveFix): Boolean {
        return try {
            val body = JSONObject()
                .put("action", "location_upload")
                .put("lat", fix.lat)
                .put("lng", fix.lng)
                .put("accuracy_m", fix.accuracyM)
                .put("recorded_at", TimeUtils.isoFromMillis(fix.timestampMillis))
                .put("source", fix.source)
            client.post("device-telemetry", body)
            true
        } catch (error: Exception) {
            recordError("Location upload failed: ${error.message?.take(200) ?: "network error"}")
            false
        }
    }

    private fun batteryStatus(): BatteryState {
        val manager = getSystemService(Context.BATTERY_SERVICE) as? BatteryManager
        val propertyLevel = try {
            manager?.getIntProperty(BatteryManager.BATTERY_PROPERTY_CAPACITY)
        } catch (_: Exception) {
            null
        }
        val sticky = registerReceiver(
            null,
            android.content.IntentFilter(Intent.ACTION_BATTERY_CHANGED)
        )
        val status = sticky?.getIntExtra(BatteryManager.EXTRA_STATUS, -1) ?: -1
        val charging = status == BatteryManager.BATTERY_STATUS_CHARGING ||
            status == BatteryManager.BATTERY_STATUS_FULL
        val level = when {
            propertyLevel != null && propertyLevel in 0..100 -> propertyLevel
            sticky != null -> {
                val raw = sticky.getIntExtra(BatteryManager.EXTRA_LEVEL, -1)
                val scale = sticky.getIntExtra(BatteryManager.EXTRA_SCALE, -1)
                if (raw in 0..1000 && scale > 0) {
                    ((raw.toDouble() / scale.toDouble()) * 100.0).toInt().coerceIn(0, 100)
                } else {
                    null
                }
            }
            else -> null
        }
        return BatteryState(level, charging)
    }

    private fun isOnline(): Boolean {
        return try {
            val manager = getSystemService(Context.CONNECTIVITY_SERVICE) as ConnectivityManager
            val network = manager.activeNetwork ?: return false
            val capabilities = manager.getNetworkCapabilities(network) ?: return false
            capabilities.hasCapability(NetworkCapabilities.NET_CAPABILITY_INTERNET)
        } catch (_: Exception) {
            false
        }
    }

    private fun enforcementMode(): String {
        return when {
            applier.isDeviceOwner() -> "device_owner"
            applier.isAdminActive() -> "device_admin"
            else -> "none"
        }
    }

    private fun errorSummary(errors: JSONArray?): String {
        if (errors == null || errors.length() == 0) return "The policy could not be applied."
        val values = ArrayList<String>()
        for (index in 0 until errors.length()) {
            val value = errors.optString(index, "").trim()
            if (value.isNotEmpty()) values.add(value)
        }
        return values.joinToString(" ").take(300)
    }

    private fun recordError(message: String) {
        val safe = message.take(300)
        if (store.lastError() == safe) return
        store.setLastError(safe)
        lastError = safe
        NativeEventBus.emitServiceStatus(isRunning, safe)
        updateNotification(getString(R.string.guardian_notification_error_text))
    }

    private fun clearError() {
        if (store.lastError() == null && lastError == null) return
        store.setLastError(null)
        lastError = null
        NativeEventBus.emitServiceStatus(isRunning, null)
        updateNotification(getString(R.string.guardian_notification_text))
    }

    private fun createChannel() {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.O) return
        val manager = getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
        val existing = manager.getNotificationChannel(CHANNEL_ID)
        if (existing != null) return
        val channel = NotificationChannel(
            CHANNEL_ID,
            getString(R.string.guardian_channel_name),
            NotificationManager.IMPORTANCE_LOW
        ).apply {
            description = getString(R.string.guardian_channel_description)
            setShowBadge(false)
        }
        manager.createNotificationChannel(channel)
    }

    private fun buildNotification(text: String): Notification {
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
            .setContentTitle(getString(R.string.guardian_notification_title))
            .setContentText(text)
            .setSmallIcon(R.drawable.ic_stat_guardian)
            .setContentIntent(pendingIntent)
            .setOngoing(true)
            .setOnlyAlertOnce(true)
            .setPriority(NotificationCompat.PRIORITY_LOW)
            .build()
    }

    private fun startAsForeground(text: String) {
        val notification = buildNotification(text)
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
            startForeground(
                NOTIFICATION_ID,
                notification,
                ServiceInfo.FOREGROUND_SERVICE_TYPE_DATA_SYNC
            )
        } else {
            startForeground(NOTIFICATION_ID, notification)
        }
    }

    private fun updateNotification(text: String) {
        // Updating the existing notification keeps the foreground service visible.
        val manager = getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
        manager.notify(NOTIFICATION_ID, buildNotification(text))
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

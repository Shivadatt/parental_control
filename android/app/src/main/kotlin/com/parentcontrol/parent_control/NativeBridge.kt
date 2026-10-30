package com.parentcontrol.parent_control

import android.Manifest
import android.app.Activity
import android.app.admin.DevicePolicyManager
import android.content.ComponentName
import android.content.Context
import android.content.Intent
import android.location.Location
import android.location.LocationManager
import android.net.Uri
import android.os.BatteryManager
import android.os.Build
import android.os.Handler
import android.os.Looper
import android.provider.Settings
import androidx.core.content.ContextCompat
import io.flutter.plugin.common.BinaryMessenger
import io.flutter.plugin.common.EventChannel
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import java.lang.ref.WeakReference
import java.util.concurrent.Executors

/**
 * Implements the `com.parentcontrol/native` contract and the native event
 * stream. Nothing here logs credentials, codes, SDP or tokens.
 *
 * The bridge is scoped to the process-wide [io.flutter.embedding.engine.FlutterEngine],
 * not to the Activity: the engine (and therefore the authorized WebRTC session)
 * outlives the UI, so the channels and the event sink must outlive it too. Only
 * the Activity reference used for permission prompts and foreground-only
 * intents is attached and detached with the UI.
 */
class NativeBridge private constructor(
    private val context: Context,
    messenger: BinaryMessenger
) : MethodChannel.MethodCallHandler {
    companion object {
        const val METHOD_CHANNEL = "com.parentcontrol/native"
        const val EVENT_CHANNEL = "com.parentcontrol/native_events"
        private const val PERMISSION_REQUEST_CODE = 7311

        @Volatile
        private var instance: NativeBridge? = null

        /** Returns the process-scoped bridge, creating it on first attach. */
        fun attach(context: Context, messenger: BinaryMessenger): NativeBridge {
            val existing = instance
            if (existing != null) return existing
            synchronized(this) {
                val current = instance
                if (current != null) return current
                val created = NativeBridge(context.applicationContext, messenger)
                instance = created
                return created
            }
        }

        /** The bridge if the engine has already been configured, else null. */
        fun peek(): NativeBridge? = instance
    }

    private val methodChannel = MethodChannel(messenger, METHOD_CHANNEL)
    private val eventChannel = EventChannel(messenger, EVENT_CHANNEL)
    private val executor = Executors.newSingleThreadExecutor()
    private val mainHandler = Handler(Looper.getMainLooper())
    private val store: SecureStore? by lazy {
        try {
            SecureStore.get(context)
        } catch (_: Exception) {
            null
        }
    }
    private val applier: PolicyApplier? by lazy {
        store?.let { PolicyApplier(context, it) }
    }

    @Volatile
    private var activityRef: WeakReference<Activity>? = null

    private var pendingPermissionResult: MethodChannel.Result? = null

    private val streamHandler = object : EventChannel.StreamHandler {
        override fun onListen(arguments: Any?, events: EventChannel.EventSink?) {
            NativeEventBus.attach(events)
        }

        override fun onCancel(arguments: Any?) {
            NativeEventBus.detach()
        }
    }

    init {
        methodChannel.setMethodCallHandler(this)
        eventChannel.setStreamHandler(streamHandler)
    }

    /** The UI currently attached to the engine, or null while it is closed. */
    private fun activityOrNull(): Activity? = activityRef?.get()

    fun attachActivity(activity: Activity) {
        activityRef = WeakReference(activity)
    }

    fun detachActivity(activity: Activity) {
        if (activityOrNull() !== activity) return
        activityRef = null
        // A prompt can only be answered by the Activity that asked for it.
        pendingPermissionResult?.error(
            "activity_destroyed",
            "The permission request was interrupted.",
            null
        )
        pendingPermissionResult = null
    }

    override fun onMethodCall(call: MethodCall, result: MethodChannel.Result) {
        try {
            when (call.method) {
                "getCapabilities" -> result.success(capabilities())
                "getDeviceIdentity" -> getDeviceIdentity(result)
                "getBatteryStatus" -> result.success(batteryStatus())
                "getInstalledApps" -> runAsync(result) { installedApps() }
                "isPackageSuspended" -> {
                    val packageName = stringArgument(call, "packageName")
                    result.success(
                        if (packageName.isNullOrBlank()) false
                        else applier?.isSuspended(packageName) ?: false
                    )
                }
                "applyPolicy" -> applyPolicy(call, result)
                "getGuardianServiceStatus" -> result.success(guardianStatus())
                "startGuardianService" -> result.success(startGuardian())
                "stopGuardianService" -> result.success(stopGuardian())
                "configureBackgroundSync" -> result.success(configureBackgroundSync(call))
                "clearBackgroundSync" -> result.success(clearBackgroundSync())
                "requestDeviceAdmin" -> result.success(requestDeviceAdmin())
                "openUsageAccessSettings" -> result.success(openUsageAccessSettings())
                "openBackgroundLocationSettings" ->
                    result.success(openBackgroundLocationSettings())
                "requestPermissions" -> requestPermissions(call, result)
                "getLastKnownLocation" -> result.success(lastKnownLocation())
                "startLocationTracking" -> result.success(startLocationTracking(call))
                "stopLocationTracking" -> result.success(stopLocationTracking())
                "getDailyUsage" -> dailyUsage(call, result)
                "startAudioAssistanceService" -> {
                    val sessionId = stringArgument(call, "sessionId")
                    result.success(AudioAssistanceService.start(context, sessionId))
                }
                "stopAudioAssistanceService" -> {
                    AudioAssistanceService.stop(context)
                    result.success(true)
                }
                "getAudioAssistanceStatus" -> result.success(audioAssistanceStatus())
                "notifyAudioCaptureHeartbeat" -> {
                    val sessionId = stringArgument(call, "sessionId")
                    result.success(AudioAssistanceService.noteCaptureHeartbeat(sessionId))
                }
                "areNotificationsGranted" ->
                    result.success(NativePermissions.hasNotifications(context))
                "isMicrophoneOneTimeGrant" -> result.success(microphoneOneTimeGrant())
                else -> result.notImplemented()
            }
        } catch (error: SecurityException) {
            result.error("permission_denied", "Android denied access for this operation.", null)
        } catch (error: Exception) {
            result.error("native_error", safeMessage(error), null)
        }
    }

    fun onRequestPermissionsResult(
        requestCode: Int,
        permissions: Array<out String>,
        grantResults: IntArray
    ) {
        if (requestCode != PERMISSION_REQUEST_CODE) return
        val pending = pendingPermissionResult ?: return
        pendingPermissionResult = null
        pending.success(NativePermissions.snapshot(context))
    }

    private fun capabilities(): Map<String, Any?> {
        val owner = applier?.isDeviceOwner() ?: false
        val adminActive = applier?.isAdminActive() ?: false
        return mapOf(
            "available" to true,
            "isDeviceOwner" to owner,
            "isAdminActive" to adminActive,
            "canSuspendPackages" to owner,
            "sdkInt" to Build.VERSION.SDK_INT,
            "manufacturer" to Build.MANUFACTURER.orEmpty(),
            "model" to Build.MODEL.orEmpty(),
            "androidVersion" to (Build.VERSION.RELEASE ?: ""),
            "appVersion" to appVersion(),
            "usageAccessGranted" to NativePermissions.hasUsageAccess(context),
            "fineLocationGranted" to NativePermissions.hasFineLocation(context),
            "backgroundLocationGranted" to NativePermissions.hasBackgroundLocation(context),
            "cameraGranted" to NativePermissions.hasCamera(context),
            "microphoneGranted" to NativePermissions.hasMicrophone(context),
            "notificationsGranted" to NativePermissions.hasNotifications(context),
            "guardianServiceRunning" to GuardianService.isRunning
        )
    }

    private fun getDeviceIdentity(result: MethodChannel.Result) {
        val secureStore = store
        if (secureStore == null) {
            result.error("secure_storage_unavailable", "Encrypted storage is unavailable.", null)
            return
        }
        val secret = secureStore.deviceSecret()
        result.success(
            mapOf(
                "installationId" to secureStore.installationId(),
                "secret" to secret,
                "secretHash" to SecureStore.sha256Hex(secret)
            )
        )
    }

    private fun batteryStatus(): Map<String, Any?> {
        val manager = context.getSystemService(Context.BATTERY_SERVICE) as? BatteryManager
        val property = try {
            manager?.getIntProperty(BatteryManager.BATTERY_PROPERTY_CAPACITY)
        } catch (_: Exception) {
            null
        }
        val sticky = ContextCompat.registerReceiver(
            context,
            null,
            android.content.IntentFilter(Intent.ACTION_BATTERY_CHANGED),
            ContextCompat.RECEIVER_NOT_EXPORTED
        )
        val status = sticky?.getIntExtra(BatteryManager.EXTRA_STATUS, -1) ?: -1
        val charging = status == BatteryManager.BATTERY_STATUS_CHARGING ||
            status == BatteryManager.BATTERY_STATUS_FULL
        val level = when {
            property != null && property in 0..100 -> property
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
        val map = LinkedHashMap<String, Any?>()
        if (level != null) map["level"] = level
        map["isCharging"] = charging
        return map
    }

    private fun installedApps(): List<Map<String, Any?>> {
        val owner = applier?.isDeviceOwner() ?: false
        return InstalledAppsProvider.load(context).map { app ->
            mapOf(
                "packageName" to app.packageName,
                "label" to app.label,
                "isSystem" to app.isSystem,
                // Without Device Owner the OS exposes no authoritative value.
                "isSuspended" to (owner && applier?.isSuspended(app.packageName) == true),
                "versionName" to app.versionName
            )
        }
    }

    private fun applyPolicy(call: MethodCall, result: MethodChannel.Result) {
        val policy = JsonConvert.toJsonObject(call.argument<Any?>("policy"))
        val policyApplier = applier
        if (policy == null) {
            result.error("invalid_arguments", "A policy object is required.", null)
            return
        }
        if (policyApplier == null) {
            result.error("native_error", "Encrypted storage is unavailable.", null)
            return
        }
        runAsync(result) { JsonConvert.toMap(policyApplier.apply(policy)) }
    }

    /**
     * Truthful snapshot of the microphone foreground service.
     *
     * `isRunning` is only true after startForeground actually succeeded.
     * `lastError` carries the last machine-readable start failure reason
     * ("permission_denied", "notification_permission_required",
     * "start_foreground_failed", "start_foreground_service_failed") and is
     * null after a successful start. `captureHealthy` is true only while the
     * Dart isolate keeps confirming that microphone capture still runs.
     */
    private fun audioAssistanceStatus(): Map<String, Any?> = mapOf(
        "isRunning" to AudioAssistanceService.isRunning,
        "activeSessionId" to AudioAssistanceService.activeSessionId,
        "lastError" to AudioAssistanceService.lastError,
        "captureHealthy" to AudioAssistanceService.isCaptureHealthy,
        "captureHeartbeatAgeMs" to AudioAssistanceService.captureHeartbeatAgeMs
    )

    /**
     * Best-effort one-time grant probe for RECORD_AUDIO.
     *
     * Android does not expose the one-time permission flag through the public
     * SDK: PackageManager.getPermissionFlags() and the flag constants
     * (FLAG_PERMISSION_ONE_TIME / FLAG_ONE_TIME) are hidden APIs and blocked for
     * apps. Guessing a flag value would fabricate a state, so `oneTime` is
     * reported as false unless a public API becomes available; `granted` is
     * always the live checkSelfPermission() result. Callers must therefore
     * still verify the grant right before starting, which both the companion
     * start() gate and the service do.
     */
    private fun microphoneOneTimeGrant(): Map<String, Any?> = mapOf(
        "granted" to NativePermissions.hasMicrophone(context),
        "oneTime" to false
    )

    private fun guardianStatus(): Map<String, Any?> {
        val secureStore = store
        return mapOf(
            "running" to GuardianService.isRunning,
            "lastPollAtMillis" to (secureStore?.lastPollAt() ?: 0L),
            "lastError" to secureStore?.lastError(),
            "queuedCommands" to GuardianService.pendingAcks
        )
    }

    private fun startGuardian(): Boolean {
        val secureStore = store ?: return false
        if (!secureStore.hasConfig()) {
            secureStore.setLastError("Background sync is not configured on this device.")
            return false
        }
        if (!NativePermissions.hasNotifications(context)) {
            secureStore.setLastError(
                "Notification permission is required for visible background sync."
            )
            return false
        }
        secureStore.setShouldRunGuardian(true)
        val started = GuardianService.start(context)
        if (!started) {
            secureStore.setShouldRunGuardian(false)
        }
        return started
    }

    private fun stopGuardian(): Boolean {
        val secureStore = store
        secureStore?.setShouldRunGuardian(false)
        GuardianService.stop(context)
        return true
    }

    private fun configureBackgroundSync(call: MethodCall): Boolean {
        val secureStore = store ?: return false
        val url = stringArgument(call, "supabaseUrl")?.trim()?.trimEnd('/')
        val publishableKey = stringArgument(call, "publishableKey")?.trim()
        val deviceId = stringArgument(call, "deviceId")?.trim()
        val deviceSecret = stringArgument(call, "deviceSecret")?.trim()
        val familyId = stringArgument(call, "familyId")?.trim()
        if (url.isNullOrBlank() || !url.startsWith("https://", ignoreCase = true)) return false
        if (publishableKey.isNullOrBlank() || publishableKey.length > 4096) return false
        if (deviceId.isNullOrBlank() || deviceId.length > 128) return false
        if (deviceSecret.isNullOrBlank() || deviceSecret.length > 512) return false
        if (familyId.isNullOrBlank() || familyId.length > 128) return false
        secureStore.saveConfig(
            SyncConfig(
                supabaseUrl = url,
                publishableKey = publishableKey,
                deviceId = deviceId,
                deviceSecret = deviceSecret,
                familyId = familyId
            )
        )
        return true
    }

    private fun clearBackgroundSync(): Boolean {
        val secureStore = store ?: return true
        secureStore.setShouldRunGuardian(false)
        GuardianService.stop(context)
        LocationTrackingService.stop(context)
        val restored = applier?.restoreAll()
        secureStore.clearHandledCommands()
        secureStore.clearConfig()
        if (restored != null && !restored.optBoolean("success", false)) {
            secureStore.setLastError(
                "Some suspended apps could not be restored. Device Owner access may be missing."
            )
            return false
        }
        return true
    }

    private fun requestDeviceAdmin(): Boolean {
        val applierInstance = applier ?: return false
        if (applierInstance.isDeviceOwner()) return true
        val component = ComponentName(context, ParentControlDeviceAdminReceiver::class.java)
        val intent = Intent(DevicePolicyManager.ACTION_ADD_DEVICE_ADMIN).apply {
            putExtra(DevicePolicyManager.EXTRA_DEVICE_ADMIN, component)
            putExtra(
                DevicePolicyManager.EXTRA_ADD_EXPLANATION,
                context.getString(R.string.device_admin_explanation)
            )
        }
        return startActivitySafely(intent)
    }

    private fun openUsageAccessSettings(): Boolean {
        return try {
            if (!startActivitySafely(Intent(Settings.ACTION_USAGE_ACCESS_SETTINGS))) {
                openAppDetails()
            } else {
                true
            }
        } catch (_: Exception) {
            openAppDetails()
        }
    }

    private fun openBackgroundLocationSettings(): Boolean = openAppDetails()

    private fun openAppDetails(): Boolean {
        return startActivitySafely(
            Intent(
                Settings.ACTION_APPLICATION_DETAILS_SETTINGS,
                Uri.fromParts("package", context.packageName, null)
            )
        )
    }

    /**
     * Starts an Activity from the attached UI, or from the application context
     * with NEW_TASK when the UI is closed (the engine, not the Activity, owns
     * this bridge).
     */
    private fun startActivitySafely(intent: Intent): Boolean {
        return try {
            val activity = activityOrNull()
            if (activity != null && !activity.isFinishing) {
                activity.startActivity(intent)
            } else {
                intent.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                context.startActivity(intent)
            }
            true
        } catch (_: Exception) {
            false
        }
    }

    private fun requestPermissions(call: MethodCall, result: MethodChannel.Result) {
        if (pendingPermissionResult != null) {
            result.error(
                "permission_request_in_progress",
                "Another permission request is already open.",
                null
            )
            return
        }
        val permissions = LinkedHashSet<String>()
        if (boolArgument(call, "camera")) permissions.add(Manifest.permission.CAMERA)
        if (boolArgument(call, "microphone")) permissions.add(Manifest.permission.RECORD_AUDIO)
        if (boolArgument(call, "location")) {
            permissions.add(Manifest.permission.ACCESS_COARSE_LOCATION)
            permissions.add(Manifest.permission.ACCESS_FINE_LOCATION)
        }
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU &&
            boolArgument(call, "notifications")
        ) {
            permissions.add(Manifest.permission.POST_NOTIFICATIONS)
        }
        val missing = permissions.filter {
            !NativePermissions.isPermissionGranted(context, it)
        }
        if (missing.isEmpty()) {
            result.success(NativePermissions.snapshot(context))
            return
        }
        val activity = activityOrNull()
        if (activity == null || activity.isFinishing) {
            // No UI to host the prompt: report the real grant state instead of
            // pretending the request succeeded.
            result.success(NativePermissions.snapshot(context))
            return
        }
        pendingPermissionResult = result
        try {
            activity.requestPermissions(missing.toTypedArray(), PERMISSION_REQUEST_CODE)
        } catch (error: Exception) {
            pendingPermissionResult = null
            result.error("permission_request_failed", safeMessage(error), null)
        }
    }

    private fun lastKnownLocation(): Map<String, Any?> {
        val fine = NativePermissions.hasFineLocation(context)
        val coarse = NativePermissions.hasCoarseLocation(context)
        if (!fine && !coarse) return mapOf("available" to false)
        val manager = try {
            context.getSystemService(Context.LOCATION_SERVICE) as LocationManager
        } catch (_: Exception) {
            return mapOf("available" to false)
        }
        var newest: Location? = null
        for (provider in listOf(
            LocationManager.GPS_PROVIDER,
            LocationManager.NETWORK_PROVIDER,
            LocationManager.PASSIVE_PROVIDER
        )) {
            val candidate = try {
                manager.getLastKnownLocation(provider)
            } catch (_: SecurityException) {
                null
            } catch (_: Exception) {
                null
            }
            if (candidate != null && (newest == null || candidate.time > newest.time)) {
                newest = candidate
            }
        }
        val location = newest ?: return mapOf("available" to false)
        if (location.latitude.isNaN() || location.longitude.isNaN()) {
            return mapOf("available" to false)
        }
        val mock = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
            location.isMock
        } else {
            @Suppress("DEPRECATION")
            location.isFromMockProvider
        }
        return mapOf(
            "available" to true,
            "lat" to location.latitude,
            "lng" to location.longitude,
            "accuracyM" to location.accuracy.toDouble(),
            "timestampMillis" to location.time,
            "isMock" to mock,
            "source" to (location.provider ?: "device")
        )
    }

    private fun startLocationTracking(call: MethodCall): Boolean {
        if (!NativePermissions.hasFineLocation(context)) return false
        if (!NativePermissions.hasNotifications(context)) return false
        val interval = intArgument(call, "intervalSeconds") ?: 60
        return LocationTrackingService.start(context, interval.coerceIn(15, 3600))
    }

    private fun stopLocationTracking(): Boolean {
        LocationTrackingService.stop(context)
        return true
    }

    private fun dailyUsage(call: MethodCall, result: MethodChannel.Result) {
        if (!NativePermissions.hasUsageAccess(context)) {
            result.error(
                "usage_access_denied",
                "Usage Access is not granted. Enable it in system settings.",
                null
            )
            return
        }
        val start = longArgument(call, "startMillis")
        val end = longArgument(call, "endMillis")
        if (start == null || end == null || end <= start) {
            result.success(emptyList<Map<String, Any?>>())
            return
        }
        runAsync(result) {
            try {
                UsageReporter.query(context, start, end).map { row ->
                    val entry = LinkedHashMap<String, Any?>()
                    entry["day"] = row.day
                    entry["packageName"] = row.packageName
                    entry["label"] = row.label
                    entry["totalMs"] = row.totalMs
                    row.lastUsedAtMillis?.let { entry["lastUsedAtMillis"] = it }
                    entry
                }
            } catch (_: UsageAccessDeniedException) {
                throw NativeUsageAccessDenied()
            }
        }
    }

    private fun runAsync(
        result: MethodChannel.Result,
        block: () -> Any?
    ) {
        executor.execute {
            try {
                val value = block()
                mainHandler.post { result.success(value) }
            } catch (_: NativeUsageAccessDenied) {
                mainHandler.post {
                    result.error(
                        "usage_access_denied",
                        "Usage Access is not granted. Enable it in system settings.",
                        null
                    )
                }
            } catch (error: Exception) {
                mainHandler.post {
                    result.error("native_error", safeMessage(error), null)
                }
            }
        }
    }

    private fun appVersion(): String {
        return try {
            @Suppress("DEPRECATION")
            val info = context.packageManager.getPackageInfo(context.packageName, 0)
            info.versionName.orEmpty()
        } catch (_: Exception) {
            ""
        }
    }

    private fun stringArgument(call: MethodCall, key: String): String? =
        call.argument<Any?>(key) as? String

    private fun boolArgument(call: MethodCall, key: String): Boolean =
        call.argument<Any?>(key) as? Boolean ?: false

    private fun intArgument(call: MethodCall, key: String): Int? =
        (call.argument<Any?>(key) as? Number)?.toInt()

    private fun longArgument(call: MethodCall, key: String): Long? =
        (call.argument<Any?>(key) as? Number)?.toLong()

    private fun safeMessage(error: Exception): String =
        error.message?.take(300) ?: "The native operation failed."
}

private class NativeUsageAccessDenied : Exception()

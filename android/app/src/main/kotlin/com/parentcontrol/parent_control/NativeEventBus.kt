package com.parentcontrol.parent_control

import android.os.Handler
import android.os.Looper
import io.flutter.plugin.common.EventChannel

/** Bridges background services to the Dart EventChannel on the platform thread. */
object NativeEventBus {
    private val handler = Handler(Looper.getMainLooper())

    @Volatile
    private var sink: EventChannel.EventSink? = null

    fun attach(newSink: EventChannel.EventSink?) {
        sink = newSink
    }

    fun detach() {
        sink = null
    }

    fun emit(event: Map<String, Any?>) {
        handler.post {
            sink?.success(event)
        }
    }

    fun emitLocation(fix: LiveFix) {
        emit(
            mapOf(
                "type" to "location_update",
                "fix" to mapOf(
                    "lat" to fix.lat,
                    "lng" to fix.lng,
                    "accuracyM" to fix.accuracyM,
                    "timestampMillis" to fix.timestampMillis,
                    "isMock" to fix.isMock,
                    "source" to fix.source
                )
            )
        )
    }

    fun emitServiceStatus(running: Boolean, lastError: String?) {
        emit(
            mapOf(
                "type" to "service_status",
                "running" to running,
                "lastError" to lastError
            )
        )
    }

    fun emitCommand(commandId: String, commandType: String, status: String) {
        emit(
            mapOf(
                "type" to "command",
                "commandId" to commandId,
                "commandType" to commandType,
                "status" to status
            )
        )
    }
}

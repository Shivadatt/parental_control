package com.parentcontrol.parent_control

import org.json.JSONObject

data class LiveFix(
    val lat: Double,
    val lng: Double,
    val accuracyM: Double,
    val timestampMillis: Long,
    val isMock: Boolean,
    val source: String
) {
    fun toJson(): JSONObject = JSONObject().apply {
        put("lat", lat)
        put("lng", lng)
        put("accuracyM", accuracyM)
        put("accuracy_m", accuracyM)
        put("timestampMillis", timestampMillis)
        put("isMock", isMock)
        put("source", source)
    }
}

/** Last fix shared between the location foreground service and the sync service. */
object LiveState {
    @Volatile
    var tracking: Boolean = false

    @Volatile
    var lastFix: LiveFix? = null

    fun update(fix: LiveFix) {
        lastFix = fix
    }

    fun clear() {
        lastFix = null
        tracking = false
    }
}

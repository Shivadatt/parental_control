package com.parentcontrol.parent_control

import org.json.JSONObject
import java.io.IOException
import java.net.HttpURLConnection
import java.net.URL

class DeviceHttpException(
    message: String,
    val statusCode: Int = 0
) : IOException(message)

/**
 * Minimal device-authenticated Edge Function client for background work.
 * Only HTTPS is accepted. Credentials are sent in headers and never logged.
 */
class DeviceHttpClient(private val config: SyncConfig) {
    fun post(function: String, body: JSONObject): JSONObject {
        val base = config.supabaseUrl.trim().trimEnd('/')
        if (!base.startsWith("https://", ignoreCase = true)) {
            throw DeviceHttpException("Background sync requires an HTTPS backend.")
        }
        val url = try {
            URL("$base/functions/v1/$function")
        } catch (error: Exception) {
            throw DeviceHttpException("The backend URL is invalid.")
        }
        if (!url.protocol.equals("https", ignoreCase = true)) {
            throw DeviceHttpException("Background sync requires an HTTPS backend.")
        }

        var connection: HttpURLConnection? = null
        try {
            connection = url.openConnection() as HttpURLConnection
            connection.requestMethod = "POST"
            connection.connectTimeout = 15_000
            connection.readTimeout = 20_000
            connection.useCaches = false
            connection.doInput = true
            connection.doOutput = true
            connection.setRequestProperty("Content-Type", "application/json; charset=utf-8")
            connection.setRequestProperty("Accept", "application/json")
            connection.setRequestProperty("apikey", config.publishableKey)
            connection.setRequestProperty("Authorization", "Bearer ${config.publishableKey}")
            connection.setRequestProperty("x-device-id", config.deviceId)
            connection.setRequestProperty("x-device-secret", config.deviceSecret)

            connection.outputStream.use { stream ->
                stream.write(body.toString().toByteArray(Charsets.UTF_8))
            }

            val status = connection.responseCode
            val stream = if (status in 200..299) connection.inputStream else connection.errorStream
            val text = stream?.bufferedReader(Charsets.UTF_8)?.use { it.readText() } ?: ""
            if (status !in 200..299) {
                throw DeviceHttpException(readErrorMessage(text, status), status)
            }
            val envelope = try {
                JSONObject(text)
            } catch (_: Exception) {
                throw DeviceHttpException("The server returned an unreadable response.", status)
            }
            if (!envelope.optBoolean("ok", false)) {
                val error = envelope.optJSONObject("error")
                val message = error?.optString("message", "")?.takeIf { it.isNotBlank() }
                    ?: "The server rejected the request."
                throw DeviceHttpException(message.take(300), status)
            }
            return envelope.optJSONObject("data") ?: JSONObject()
        } finally {
            connection?.disconnect()
        }
    }

    private fun readErrorMessage(text: String, status: Int): String {
        if (text.isBlank()) return "The server returned HTTP $status."
        return try {
            val envelope = JSONObject(text)
            val error = envelope.optJSONObject("error")
            val message = error?.optString("message", "")?.takeIf { it.isNotBlank() }
            (message ?: "The server returned HTTP $status.").take(300)
        } catch (_: Exception) {
            "The server returned HTTP $status."
        }
    }
}

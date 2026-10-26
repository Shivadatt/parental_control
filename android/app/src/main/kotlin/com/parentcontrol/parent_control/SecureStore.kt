package com.parentcontrol.parent_control

import android.content.Context
import android.content.SharedPreferences
import android.util.Base64
import androidx.security.crypto.EncryptedSharedPreferences
import androidx.security.crypto.MasterKey
import org.json.JSONArray
import java.security.MessageDigest
import java.security.SecureRandom
import java.util.UUID

data class SyncConfig(
    val supabaseUrl: String,
    val publishableKey: String,
    val deviceId: String,
    val deviceSecret: String,
    val familyId: String
)

/**
 * Encrypted local state. Values written here must never be logged: the device
 * secret and the background-sync configuration are credentials.
 */
class SecureStore private constructor(context: Context) {
    companion object {
        private const val FILE_NAME = "parent_control_secure"
        private const val KEY_INSTALLATION_ID = "installation_id"
        private const val KEY_DEVICE_SECRET = "device_secret"
        private const val KEY_SUPABASE_URL = "sync_supabase_url"
        private const val KEY_PUBLISHABLE_KEY = "sync_publishable_key"
        private const val KEY_DEVICE_ID = "sync_device_id"
        private const val KEY_SYNC_DEVICE_SECRET = "sync_device_secret"
        private const val KEY_FAMILY_ID = "sync_family_id"
        private const val KEY_SHOULD_RUN = "guardian_should_run"
        private const val KEY_LAST_ERROR = "guardian_last_error"
        private const val KEY_LAST_POLL_AT = "guardian_last_poll_at"
        private const val KEY_POLICY_JSON = "last_policy_json"
        private const val KEY_APPLIED_VERSION = "applied_policy_version"
        private const val KEY_SUSPENDED = "suspended_packages"
        private const val KEY_HANDLED_COMMANDS = "handled_command_ids"
        private const val MAX_HANDLED_COMMANDS = 100

        @Volatile
        private var instance: SecureStore? = null

        fun get(context: Context): SecureStore {
            val existing = instance
            if (existing != null) return existing
            synchronized(this) {
                val cached = instance
                if (cached != null) return cached
                val created = SecureStore(context.applicationContext)
                instance = created
                return created
            }
        }

        fun sha256Hex(value: String): String {
            val digest = MessageDigest.getInstance("SHA-256")
            val bytes = digest.digest(value.toByteArray(Charsets.UTF_8))
            val builder = StringBuilder(bytes.size * 2)
            for (byte in bytes) {
                builder.append(String.format("%02x", byte.toInt() and 0xff))
            }
            return builder.toString()
        }
    }

    private val prefs: SharedPreferences

    init {
        val masterKey = MasterKey.Builder(context)
            .setKeyScheme(MasterKey.KeyScheme.AES256_GCM)
            .build()
        prefs = EncryptedSharedPreferences.create(
            context,
            FILE_NAME,
            masterKey,
            EncryptedSharedPreferences.PrefKeyEncryptionScheme.AES256_SIV,
            EncryptedSharedPreferences.PrefValueEncryptionScheme.AES256_GCM
        )
    }

    fun installationId(): String {
        val existing = prefs.getString(KEY_INSTALLATION_ID, null)
        if (!existing.isNullOrBlank()) return existing
        val created = UUID.randomUUID().toString()
        prefs.edit().putString(KEY_INSTALLATION_ID, created).apply()
        return created
    }

    fun deviceSecret(): String {
        val existing = prefs.getString(KEY_DEVICE_SECRET, null)
        if (!existing.isNullOrBlank()) return existing
        val bytes = ByteArray(32)
        SecureRandom().nextBytes(bytes)
        val created = Base64.encodeToString(
            bytes,
            Base64.URL_SAFE or Base64.NO_WRAP or Base64.NO_PADDING
        )
        prefs.edit().putString(KEY_DEVICE_SECRET, created).apply()
        return created
    }

    fun saveConfig(config: SyncConfig) {
        prefs.edit()
            .putString(KEY_SUPABASE_URL, config.supabaseUrl)
            .putString(KEY_PUBLISHABLE_KEY, config.publishableKey)
            .putString(KEY_DEVICE_ID, config.deviceId)
            .putString(KEY_SYNC_DEVICE_SECRET, config.deviceSecret)
            .putString(KEY_FAMILY_ID, config.familyId)
            .apply()
    }

    fun config(): SyncConfig? {
        val url = prefs.getString(KEY_SUPABASE_URL, null)
        val key = prefs.getString(KEY_PUBLISHABLE_KEY, null)
        val deviceId = prefs.getString(KEY_DEVICE_ID, null)
        val secret = prefs.getString(KEY_SYNC_DEVICE_SECRET, null)
        val familyId = prefs.getString(KEY_FAMILY_ID, null)
        if (url.isNullOrBlank() || key.isNullOrBlank() || deviceId.isNullOrBlank() ||
            secret.isNullOrBlank() || familyId.isNullOrBlank()
        ) {
            return null
        }
        return SyncConfig(url, key, deviceId, secret, familyId)
    }

    fun hasConfig(): Boolean = config() != null

    fun clearConfig() {
        prefs.edit()
            .remove(KEY_SUPABASE_URL)
            .remove(KEY_PUBLISHABLE_KEY)
            .remove(KEY_DEVICE_ID)
            .remove(KEY_SYNC_DEVICE_SECRET)
            .remove(KEY_FAMILY_ID)
            .remove(KEY_SHOULD_RUN)
            .apply()
    }

    fun shouldRunGuardian(): Boolean = prefs.getBoolean(KEY_SHOULD_RUN, false)
    fun setShouldRunGuardian(value: Boolean) {
        prefs.edit().putBoolean(KEY_SHOULD_RUN, value).apply()
    }

    fun lastError(): String? = prefs.getString(KEY_LAST_ERROR, null)
    fun setLastError(message: String?) {
        if (message.isNullOrBlank()) {
            prefs.edit().remove(KEY_LAST_ERROR).apply()
        } else {
            prefs.edit().putString(KEY_LAST_ERROR, message.take(500)).apply()
        }
    }

    fun lastPollAt(): Long = prefs.getLong(KEY_LAST_POLL_AT, 0L)
    fun setLastPollAt(millis: Long) {
        prefs.edit().putLong(KEY_LAST_POLL_AT, millis).apply()
    }

    fun policyJson(): String? = prefs.getString(KEY_POLICY_JSON, null)
    fun setPolicyJson(json: String?) {
        if (json.isNullOrBlank()) {
            prefs.edit().remove(KEY_POLICY_JSON).apply()
        } else {
            prefs.edit().putString(KEY_POLICY_JSON, json).apply()
        }
    }

    fun appliedVersion(): Int = prefs.getInt(KEY_APPLIED_VERSION, 0)
    fun setAppliedVersion(version: Int) {
        prefs.edit().putInt(KEY_APPLIED_VERSION, version).apply()
    }

    fun suspendedPackages(): Set<String> = readStringSet(KEY_SUSPENDED)
    fun setSuspendedPackages(packages: Set<String>) {
        writeStringSet(KEY_SUSPENDED, packages)
    }

    fun handledCommands(): Set<String> = readStringSet(KEY_HANDLED_COMMANDS)
    fun markCommandHandled(commandId: String) {
        if (commandId.isBlank()) return
        val updated = LinkedHashSet(handledCommands())
        updated.add(commandId)
        while (updated.size > MAX_HANDLED_COMMANDS) {
            val first = updated.iterator()
            if (!first.hasNext()) break
            first.next()
            first.remove()
        }
        writeStringSet(KEY_HANDLED_COMMANDS, updated)
    }

    fun clearHandledCommands() {
        prefs.edit().remove(KEY_HANDLED_COMMANDS).apply()
    }

    fun clearPolicyState() {
        prefs.edit()
            .remove(KEY_POLICY_JSON)
            .remove(KEY_APPLIED_VERSION)
            .remove(KEY_SUSPENDED)
            .apply()
    }

    private fun readStringSet(key: String): Set<String> {
        val raw = prefs.getString(key, null) ?: return emptySet()
        return try {
            val array = JSONArray(raw)
            val values = LinkedHashSet<String>()
            for (index in 0 until array.length()) {
                val item = array.optString(index, "")
                if (item.isNotBlank()) values.add(item)
            }
            values
        } catch (_: Exception) {
            emptySet()
        }
    }

    private fun writeStringSet(key: String, values: Set<String>) {
        val array = JSONArray()
        for (value in values) {
            array.put(value)
        }
        prefs.edit().putString(key, array.toString()).apply()
    }
}

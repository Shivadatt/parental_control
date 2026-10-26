package com.parentcontrol.parent_control

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.os.Build
import android.widget.Toast

/**
 * Resumes visible background sync after a reboot or app update when the child
 * previously configured it.
 *
 * Android 15 forbids starting a dataSync foreground service from
 * BOOT_COMPLETED. That case is reported to the child instead of pretending the
 * service is running.
 */
class BootReceiver : BroadcastReceiver() {
    override fun onReceive(context: Context, intent: Intent) {
        if (intent.action != Intent.ACTION_BOOT_COMPLETED &&
            intent.action != Intent.ACTION_MY_PACKAGE_REPLACED
        ) {
            return
        }
        val store = try {
            SecureStore.get(context)
        } catch (_: Exception) {
            return
        }
        if (!store.shouldRunGuardian() || !store.hasConfig()) return

        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.VANILLA_ICE_CREAM) {
            store.setLastError(
                "Android 15 does not allow starting visible background sync at boot. " +
                    "Open Parent Control to resume it."
            )
            return
        }
        if (!NativePermissions.hasNotifications(context)) {
            store.setLastError(
                "Notification permission is required for visible background sync. " +
                    "Open Parent Control to enable it."
            )
            return
        }
        if (!GuardianService.start(context)) {
            Toast.makeText(
                context,
                context.getString(R.string.guardian_boot_failed),
                Toast.LENGTH_LONG
            ).show()
        }
    }
}

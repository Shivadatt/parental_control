package com.parentcontrol.parent_control

import android.Manifest
import android.app.AppOpsManager
import android.content.Context
import android.content.pm.PackageManager
import android.os.Build
import android.os.Process
import androidx.core.content.ContextCompat

object NativePermissions {
    fun hasCamera(context: Context): Boolean = granted(context, Manifest.permission.CAMERA)

    fun hasMicrophone(context: Context): Boolean = granted(context, Manifest.permission.RECORD_AUDIO)

    fun hasFineLocation(context: Context): Boolean =
        granted(context, Manifest.permission.ACCESS_FINE_LOCATION)

    fun hasCoarseLocation(context: Context): Boolean =
        granted(context, Manifest.permission.ACCESS_COARSE_LOCATION)

    fun hasBackgroundLocation(context: Context): Boolean {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.Q) {
            return hasFineLocation(context)
        }
        return granted(context, Manifest.permission.ACCESS_BACKGROUND_LOCATION)
    }

    fun hasNotifications(context: Context): Boolean {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.TIRAMISU) return true
        return granted(context, Manifest.permission.POST_NOTIFICATIONS)
    }

    fun hasUsageAccess(context: Context): Boolean {
        return try {
            val appOps = context.getSystemService(Context.APP_OPS_SERVICE) as AppOpsManager
            val mode = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
                appOps.unsafeCheckOpNoThrow(
                    AppOpsManager.OPSTR_GET_USAGE_STATS,
                    Process.myUid(),
                    context.packageName
                )
            } else {
                @Suppress("DEPRECATION")
                appOps.checkOpNoThrow(
                    AppOpsManager.OPSTR_GET_USAGE_STATS,
                    Process.myUid(),
                    context.packageName
                )
            }
            mode == AppOpsManager.MODE_ALLOWED
        } catch (_: Exception) {
            false
        }
    }

    fun snapshot(context: Context): Map<String, Boolean> = mapOf(
        "camera" to hasCamera(context),
        "microphone" to hasMicrophone(context),
        "location" to hasFineLocation(context),
        "backgroundLocation" to hasBackgroundLocation(context),
        "notifications" to hasNotifications(context)
    )

    private fun granted(context: Context, permission: String): Boolean =
        ContextCompat.checkSelfPermission(context, permission) == PackageManager.PERMISSION_GRANTED

    fun isPermissionGranted(context: Context, permission: String): Boolean =
        ContextCompat.checkSelfPermission(context, permission) == PackageManager.PERMISSION_GRANTED
}

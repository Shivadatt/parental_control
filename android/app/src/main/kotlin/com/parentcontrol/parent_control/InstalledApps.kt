package com.parentcontrol.parent_control

import android.content.Context
import android.content.pm.ApplicationInfo
import android.content.pm.PackageManager

data class InstalledPackage(
    val packageName: String,
    val label: String,
    val isSystem: Boolean,
    val versionName: String?
)

object InstalledAppsProvider {
    fun load(context: Context): List<InstalledPackage> {
        val packageManager = context.packageManager
        val packages = try {
            packageManager.getInstalledPackages(0)
        } catch (_: Exception) {
            return emptyList()
        }
        val result = ArrayList<InstalledPackage>(packages.size)
        for (info in packages) {
            val name = info.packageName ?: continue
            val applicationInfo = info.applicationInfo ?: continue
            val label = try {
                packageManager.getApplicationLabel(applicationInfo).toString()
            } catch (_: Exception) {
                name
            }
            val isSystem = (applicationInfo.flags and ApplicationInfo.FLAG_SYSTEM) != 0
            result.add(
                InstalledPackage(
                    packageName = name,
                    label = label.ifBlank { name },
                    isSystem = isSystem,
                    versionName = info.versionName
                )
            )
        }
        return result.sortedBy { it.label.lowercase() }
    }
}

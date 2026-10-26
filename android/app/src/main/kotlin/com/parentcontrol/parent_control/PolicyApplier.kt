package com.parentcontrol.parent_control

import android.app.admin.DevicePolicyManager
import android.content.ComponentName
import android.content.Context
import android.provider.Settings
import org.json.JSONArray
import org.json.JSONObject
import com.parentcontrol.parent_control.policy.ChildPolicy
import com.parentcontrol.parent_control.policy.PolicyEvaluator
import com.parentcontrol.parent_control.policy.PolicyGuard
import com.parentcontrol.parent_control.policy.PolicyJson
import java.util.Calendar

/**
 * Applies the parent's policy through DevicePolicyManager.
 *
 * Suspension is only possible for a Device Owner (fully managed provisioning);
 * every other state is reported as unsupported instead of pretending that an
 * app was blocked. Suspended packages are always re-confirmed through DPM.
 */
class PolicyApplier(
    private val context: Context,
    private val store: SecureStore
) {
    private val devicePolicyManager =
        context.getSystemService(Context.DEVICE_POLICY_SERVICE) as DevicePolicyManager
    private val admin = ComponentName(context, ParentControlDeviceAdminReceiver::class.java)

    @Synchronized
    fun apply(policyJson: JSONObject?, policyVersion: Int? = null): JSONObject {
        val errors = LinkedHashSet<String>()
        val unsupported = LinkedHashSet<String>()
        var success = false
        var policy = ChildPolicy()
        var suspended: Set<String> = emptySet()
        try {
            if (policyJson != null) store.setPolicyJson(policyJson.toString())
            val raw = policyJson ?: store.policyJson()?.let { JSONObject(it) }
            policy = PolicyJson.parse(raw)
            val installed = InstalledAppsProvider.load(context).associateBy { it.packageName }
            val calendar = Calendar.getInstance()
            val isoDay = TimeUtils.isoDayOfWeek(calendar)
            val minute = TimeUtils.minuteOfDay(calendar)
            val previous = store.suspendedPackages()
            val isOwner = isDeviceOwner()
            val protectedHome = defaultHomePackage()
            val protectedIme = defaultInputMethodPackage()

            val desired = LinkedHashSet<String>()
            for (packageName in policy.explicitCandidates()) {
                if (!policy.isPackageBlockedNow(packageName, isoDay, minute)) continue
                if (packageName == context.packageName) {
                    unsupported.add(packageName)
                    errors.add("Parent Control cannot restrict itself.")
                    continue
                }
                if (PolicyGuard.isProtectedPackage(
                        packageName,
                        context.packageName,
                        protectedHome,
                        protectedIme
                    )
                ) {
                    unsupported.add(packageName)
                    errors.add("$packageName is a protected system component and was not suspended.")
                    continue
                }
                if (!installed.containsKey(packageName)) {
                    unsupported.add(packageName)
                    continue
                }
                desired.add(packageName)
            }

            if (policy.enforceAppBlocks && policy.blockAllExceptAllowed) {
                for (installedPackage in installed.values) {
                    if (installedPackage.isSystem) continue
                    if (PolicyGuard.isProtectedPackage(
                            installedPackage.packageName,
                            context.packageName,
                            protectedHome,
                            protectedIme
                        )
                    ) {
                        continue
                    }
                    if (policy.isPackageBlockedNow(installedPackage.packageName, isoDay, minute)) {
                        desired.add(installedPackage.packageName)
                    }
                }
            }

            if (desired.isNotEmpty() && !isOwner) {
                errors.add(
                    "Device Owner provisioning is required to suspend apps on this device. " +
                        "No apps were suspended."
                )
                unsupported.addAll(desired)
                desired.clear()
            }

            val toSuspend = desired - previous
            val toRestore = PolicyEvaluator.restoreList(previous, desired)
            if (isOwner) {
                if (toSuspend.isNotEmpty()) {
                    suspendPackages(toSuspend, errors)
                }
                if (toRestore.isNotEmpty()) {
                    restorePackages(toRestore, errors)
                }
            } else if (toRestore.isNotEmpty()) {
                errors.add(
                    "Previously suspended apps could not be restored because this app is no " +
                        "longer Device Owner."
                )
            }

            // Confirm with DevicePolicyManager instead of trusting the request.
            val tracked = LinkedHashSet<String>()
            for (packageName in desired + previous) {
                if (isSuspended(packageName)) tracked.add(packageName)
            }
            for (packageName in desired) {
                if (packageName !in tracked) {
                    errors.add("Could not confirm that $packageName is suspended.")
                }
            }
            for (packageName in previous - desired) {
                if (packageName in tracked) {
                    errors.add("Could not restore $packageName.")
                }
            }
            store.setSuspendedPackages(tracked)
            suspended = tracked
            if (policyVersion != null) store.setAppliedVersion(policyVersion)
            success = errors.isEmpty()
        } catch (error: Exception) {
            errors.add(error.message?.take(300) ?: "The policy could not be applied.")
            suspended = try {
                store.suspendedPackages().filter { isSuspended(it) }.toSet()
            } catch (_: Exception) {
                emptySet()
            }
        }
        return buildResult(
            success = success,
            suspended = suspended,
            unsupported = unsupported,
            errors = errors,
            policy = policy
        )
    }

    fun applyStoredPolicy(): JSONObject {
        val stored = store.policyJson()
        if (stored.isNullOrBlank()) {
            return buildResult(
                success = false,
                suspended = store.suspendedPackages(),
                unsupported = emptySet(),
                errors = linkedSetOf("No policy has been stored on this device yet."),
                policy = ChildPolicy()
            )
        }
        return try {
            apply(JSONObject(stored))
        } catch (error: Exception) {
            buildResult(
                success = false,
                suspended = store.suspendedPackages(),
                unsupported = emptySet(),
                errors = linkedSetOf("The stored policy is unreadable."),
                policy = ChildPolicy()
            )
        }
    }

    /** Called by the 60-second guardian tick. Returns null when no policy exists. */
    fun tick(): JSONObject? {
        if (store.policyJson().isNullOrBlank()) return null
        return apply(null)
    }

    /** Restores every package this app suspended and forgets the stored policy. */
    @Synchronized
    fun restoreAll(): JSONObject {
        val errors = LinkedHashSet<String>()
        val previous = store.suspendedPackages()
        if (previous.isNotEmpty() && isDeviceOwner()) {
            restorePackages(previous, errors)
        }
        val remaining = previous.filter { isSuspended(it) }.toSet()
        val success = errors.isEmpty() && remaining.isEmpty()
        if (success) {
            store.clearPolicyState()
        } else {
            store.setSuspendedPackages(remaining)
        }
        return buildResult(
            success = success,
            suspended = remaining,
            unsupported = emptySet(),
            errors = errors,
            policy = ChildPolicy()
        )
    }

    fun isSuspended(packageName: String): Boolean {
        if (packageName.isBlank()) return false
        return try {
            devicePolicyManager.isPackageSuspended(admin, packageName)
        } catch (_: SecurityException) {
            false
        } catch (_: IllegalArgumentException) {
            false
        } catch (_: Exception) {
            false
        }
    }

    fun isDeviceOwner(): Boolean =
        try {
            devicePolicyManager.isDeviceOwnerApp(context.packageName)
        } catch (_: Exception) {
            false
        }

    fun isAdminActive(): Boolean =
        try {
            devicePolicyManager.isAdminActive(admin)
        } catch (_: Exception) {
            false
        }

    private fun suspendPackages(packages: Set<String>, errors: MutableSet<String>) {
        try {
            devicePolicyManager.setPackagesSuspended(admin, packages.toTypedArray(), true)
        } catch (error: SecurityException) {
            errors.add("The system refused to suspend apps: Device Owner access is missing.")
        } catch (error: Exception) {
            errors.add("The system refused to suspend apps: ${error.message?.take(200)}")
        }
    }

    private fun restorePackages(packages: Set<String>, errors: MutableSet<String>) {
        try {
            devicePolicyManager.setPackagesSuspended(admin, packages.toTypedArray(), false)
        } catch (error: SecurityException) {
            errors.add("The system refused to restore apps: Device Owner access is missing.")
        } catch (error: Exception) {
            errors.add("The system refused to restore apps: ${error.message?.take(200)}")
        }
    }

    private fun defaultHomePackage(): String? {
        return try {
            val intent = android.content.Intent(android.content.Intent.ACTION_MAIN)
            intent.addCategory(android.content.Intent.CATEGORY_HOME)
            val resolved = context.packageManager.resolveActivity(
                intent,
                android.content.pm.PackageManager.MATCH_DEFAULT_ONLY
            )
            resolved?.activityInfo?.packageName
        } catch (_: Exception) {
            null
        }
    }

    private fun defaultInputMethodPackage(): String? {
        return try {
            val value = Settings.Secure.getString(
                context.contentResolver,
                Settings.Secure.DEFAULT_INPUT_METHOD
            )
            value?.substringBefore('/')?.takeIf { it.isNotBlank() }
        } catch (_: Exception) {
            null
        }
    }

    private fun buildResult(
        success: Boolean,
        suspended: Set<String>,
        unsupported: Set<String>,
        errors: Set<String>,
        policy: ChildPolicy
    ): JSONObject {
        val calendar = Calendar.getInstance()
        val result = JSONObject()
        result.put("success", success)
        result.put("applied_at", TimeUtils.nowIso())
        result.put("suspended_packages", toJsonArray(suspended.sorted()))
        result.put("unsupported_packages", toJsonArray(unsupported.sorted()))
        result.put("errors", toJsonArray(errors.toList()))
        result.put("service_running", GuardianService.isRunning)
        // Informational only: bedtime is stored but app suspension follows app rules.
        result.put("bedtime_active", policy.hasBedtime && policy.isWithinBedtime(TimeUtils.minuteOfDay(calendar)))
        return result
    }

    private fun toJsonArray(values: List<String>): JSONArray {
        val array = JSONArray()
        for (value in values) {
            array.put(value)
        }
        return array
    }
}

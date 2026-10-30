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
    private companion object {
        /** The ack stays small; more than 20 per-app failures add no signal. */
        const val MAX_REPORTED_FAILURES = 20
    }

    private val devicePolicyManager =
        context.getSystemService(Context.DEVICE_POLICY_SERVICE) as DevicePolicyManager
    private val admin = ComponentName(context, ParentControlDeviceAdminReceiver::class.java)

    @Synchronized
    fun apply(policyJson: JSONObject?, policyVersion: Int? = null): JSONObject {
        val errors = LinkedHashSet<String>()
        val unsupported = LinkedHashSet<String>()
        // package name -> why it is not (or not confirmed) suspended
        val failures = LinkedHashMap<String, String>()
        var success = false
        var policy = ChildPolicy()
        var suspended: Set<String> = emptySet()
        var countsKnown = false
        var desiredCount = 0
        var appliedCount = 0
        var enforcementSupported = false
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
                    failures[packageName] = "Parent Control cannot restrict itself."
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
                    val reason =
                        "$packageName is a protected system component and was not suspended."
                    failures[packageName] = reason
                    errors.add(reason)
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

            // Desired means "the policy asks this app to be suspended now".
            // A protected app that was explicitly selected still counts: it is
            // wanted but cannot be applied, so it must show up as a failure
            // instead of disappearing from the denominator.
            desiredCount = desired.size + failures.size
            var suspendCallSucceeded = false

            if (desiredCount > 0 && !isOwner) {
                // Never clear the target set: the ack has to say desired=N,
                // applied=0, supported=false so the server can record
                // "unsupported" instead of a false "enforced".
                errors.add(
                    "Device Owner provisioning is required to suspend apps on this device. " +
                        "No apps were suspended."
                )
                unsupported.addAll(desired)
            } else if (isOwner) {
                val toSuspend = desired - previous
                val toRestore = PolicyEvaluator.restoreList(previous, desired)
                if (toSuspend.isNotEmpty()) {
                    suspendCallSucceeded = suspendPackages(toSuspend, errors)
                }
                if (toRestore.isNotEmpty()) {
                    restorePackages(toRestore, errors)
                }
            } else {
                val toRestore = PolicyEvaluator.restoreList(previous, desired)
                if (toRestore.isNotEmpty()) {
                    errors.add(
                        "Previously suspended apps could not be restored because this app is no " +
                            "longer Device Owner."
                    )
                }
            }

            // Confirm with DevicePolicyManager instead of trusting the request.
            val tracked = LinkedHashSet<String>()
            for (packageName in desired + previous) {
                if (isSuspended(packageName)) tracked.add(packageName)
            }
            for (packageName in desired) {
                if (packageName !in tracked) {
                    val reason = "Could not confirm that $packageName is suspended."
                    failures.putIfAbsent(packageName, reason)
                    errors.add(reason)
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

            val applied = desired.filter { it in tracked }.toSet()
            appliedCount = applied.size
            // Supported needs Device Owner plus evidence that every eligible
            // package really is suspended: either this run's
            // setPackagesSuspended call or a previously confirmed set. With no
            // eligible package at all, Device Owner alone is the capability.
            enforcementSupported = isOwner && (
                suspendCallSucceeded || applied.size == desired.size
                )
            countsKnown = true
            success = errors.isEmpty() && (
                desiredCount == 0 ||
                    (enforcementSupported && appliedCount == desiredCount)
                )
        } catch (error: Exception) {
            errors.add(error.message?.take(300) ?: "The policy could not be applied.")
            suspended = try {
                store.suspendedPackages().filter { isSuspended(it) }.toSet()
            } catch (_: Exception) {
                emptySet()
            }
            // Counts are unknown after an exception: report none of them so
            // the server keeps the policy "pending" rather than guessing.
            countsKnown = false
        }
        return buildResult(
            success = success,
            suspended = suspended,
            unsupported = unsupported,
            errors = errors,
            policy = policy,
            countsKnown = countsKnown,
            desiredCount = desiredCount,
            appliedCount = appliedCount,
            enforcementSupported = enforcementSupported,
            failures = failures
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

    /** `device_owner` only when the system really granted that capability. */
    fun enforcementMode(): String = when {
        isDeviceOwner() -> "device_owner"
        isAdminActive() -> "device_admin"
        else -> "none"
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
            policy = ChildPolicy(),
            countsKnown = true,
            desiredCount = 0,
            appliedCount = 0,
            enforcementSupported = isDeviceOwner(),
            failures = emptyMap()
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

    /** Returns true only when the system accepted a non-empty suspension call. */
    private fun suspendPackages(packages: Set<String>, errors: MutableSet<String>): Boolean {
        if (packages.isEmpty()) return false
        return try {
            devicePolicyManager.setPackagesSuspended(admin, packages.toTypedArray(), true)
            true
        } catch (error: SecurityException) {
            errors.add("The system refused to suspend apps: Device Owner access is missing.")
            false
        } catch (error: Exception) {
            errors.add("The system refused to suspend apps: ${error.message?.take(200)}")
            false
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
        policy: ChildPolicy,
        countsKnown: Boolean = false,
        desiredCount: Int = 0,
        appliedCount: Int = 0,
        enforcementSupported: Boolean = false,
        failures: Map<String, String> = emptyMap()
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
        if (countsKnown) {
            val failedCount = (desiredCount - appliedCount).coerceAtLeast(0)
            result.put("desired_count", desiredCount)
            result.put("applied_count", appliedCount)
            result.put("failed_count", failedCount)
            result.put("enforcement_supported", enforcementSupported)
            result.put("enforcement_mode", enforcementMode())
            result.put("failures", failureArray(failures))
        }
        return result
    }

    private fun failureArray(failures: Map<String, String>): JSONArray {
        val array = JSONArray()
        var emitted = 0
        for ((packageName, reason) in failures) {
            if (emitted >= MAX_REPORTED_FAILURES) break
            array.put(
                JSONObject()
                    .put("package", packageName)
                    .put("reason", reason.take(200))
            )
            emitted += 1
        }
        return array
    }

    private fun toJsonArray(values: List<String>): JSONArray {
        val array = JSONArray()
        for (value in values) {
            array.put(value)
        }
        return array
    }
}

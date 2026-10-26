package com.parentcontrol.parent_control.policy

/** Pure decision helpers, covered by JVM unit tests. */
object PolicyEvaluator {
    /** Packages named by the policy that must be blocked at the given local time. */
    fun explicitBlockedNow(policy: ChildPolicy, isoDay: Int, minuteOfDay: Int): Set<String> {
        if (!policy.enforceAppBlocks) return emptySet()
        return policy.explicitCandidates()
            .filter { policy.isPackageBlockedNow(it, isoDay, minuteOfDay) }
            .toSet()
    }

    /** Packages that are currently suspended but must be restored. */
    fun restoreList(previousSuspended: Set<String>, desiredSuspended: Set<String>): Set<String> =
        previousSuspended - desiredSuspended

    /** Applies the block-all rule to a user-installed package. */
    fun shouldBlockInstalled(policy: ChildPolicy, packageName: String, isoDay: Int, minuteOfDay: Int): Boolean =
        policy.isPackageBlockedNow(packageName, isoDay, minuteOfDay)
}

/**
 * Safety guard: packages that must never be suspended, even when a policy asks
 * for it. The default home app and default input method are also protected
 * dynamically by the applier because suspending them can lock the user out.
 */
object PolicyGuard {
    private val CRITICAL_PACKAGES = setOf(
        "android",
        "com.android.systemui",
        "com.android.settings",
        "com.android.phone",
        "com.android.server.telecom",
        "com.android.dialer",
        "com.google.android.dialer",
        "com.android.incallui",
        "com.android.emergency",
        "com.android.permissioncontroller",
        "com.google.android.permissioncontroller",
        "com.android.packageinstaller",
        "com.google.android.packageinstaller",
        "com.android.vending",
        "com.google.android.gms",
        "com.google.android.gsf",
        "com.android.managedprovisioning",
        "com.android.keyguard",
        "com.android.launcher",
        "com.android.launcher3",
        "com.google.android.apps.nexuslauncher",
        "com.sec.android.app.launcher",
        "com.miui.home",
        "com.oneplus.launcher",
        "com.oppo.launcher",
        "com.vivo.launcher",
        "com.huawei.android.launcher",
        "com.android.inputmethod.latin",
        "com.google.android.inputmethod.latin",
        "com.samsung.android.honeyboard",
        "com.baidu.input",
        "com.sohu.inputmethod.sogou",
        "com.iflytek.inputmethod"
    )

    fun isProtectedPackage(
        packageName: String,
        ownPackageName: String,
        defaultHomePackage: String? = null,
        defaultInputMethodPackage: String? = null
    ): Boolean {
        if (packageName.isBlank()) return true
        if (packageName == ownPackageName) return true
        if (packageName in CRITICAL_PACKAGES) return true
        if (!defaultHomePackage.isNullOrBlank() && packageName == defaultHomePackage) return true
        if (!defaultInputMethodPackage.isNullOrBlank() && packageName == defaultInputMethodPackage) return true
        return false
    }
}

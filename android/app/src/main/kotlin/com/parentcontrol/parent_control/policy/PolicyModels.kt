package com.parentcontrol.parent_control.policy

/** A recurring local-time window. ISO weekdays: Monday = 1 … Sunday = 7. */
data class PolicyWindow(
    val daysOfWeek: Set<Int>,
    val startMinutes: Int,
    val endMinutes: Int
) {
    val spansMidnight: Boolean get() = endMinutes <= startMinutes

    fun isActiveAt(isoDay: Int, minuteOfDay: Int): Boolean {
        if (daysOfWeek.isEmpty()) return false
        if (isoDay !in 1..7) return false
        if (startMinutes == endMinutes) return false
        if (!spansMidnight) {
            return isoDay in daysOfWeek && minuteOfDay >= startMinutes && minuteOfDay < endMinutes
        }
        if (isoDay in daysOfWeek && minuteOfDay >= startMinutes) return true
        val previousDay = if (isoDay == 1) 7 else isoDay - 1
        return previousDay in daysOfWeek && minuteOfDay < endMinutes
    }
}

data class PolicyAppRule(
    val packageName: String,
    val label: String,
    val blocked: Boolean,
    val windows: List<PolicyWindow>
) {
    fun isActiveAt(isoDay: Int, minuteOfDay: Int): Boolean {
        if (!blocked) return false
        if (windows.isEmpty()) return true
        return windows.any { it.isActiveAt(isoDay, minuteOfDay) }
    }
}

data class ChildPolicy(
    val enforceAppBlocks: Boolean = true,
    val blockAllExceptAllowed: Boolean = false,
    val blockedPackages: Set<String> = emptySet(),
    val allowedPackages: Set<String> = emptySet(),
    val appRules: List<PolicyAppRule> = emptyList(),
    val dailyScreenTimeLimitMinutes: Int? = null,
    val bedtimeStartMinutes: Int? = null,
    val bedtimeEndMinutes: Int? = null
) {
    val hasBedtime: Boolean
        get() = bedtimeStartMinutes != null && bedtimeEndMinutes != null &&
            bedtimeStartMinutes != bedtimeEndMinutes

    fun isWithinBedtime(minuteOfDay: Int): Boolean {
        if (!hasBedtime) return false
        val start = bedtimeStartMinutes ?: return false
        val end = bedtimeEndMinutes ?: return false
        return if (start < end) {
            minuteOfDay >= start && minuteOfDay < end
        } else {
            minuteOfDay >= start || minuteOfDay < end
        }
    }

    /**
     * Mirrors [PolicyPayload.isPackageBlockedNow] in the Flutter client: a
     * matching app rule wins over the package lists, including a rule that is
     * currently inactive.
     */
    fun isPackageBlockedNow(packageName: String, isoDay: Int, minuteOfDay: Int): Boolean {
        if (!enforceAppBlocks) return false
        val rule = appRules.firstOrNull { it.packageName == packageName }
        if (rule != null) return rule.isActiveAt(isoDay, minuteOfDay)
        if (blockedPackages.contains(packageName)) {
            return !blockAllExceptAllowed || !allowedPackages.contains(packageName)
        }
        if (blockAllExceptAllowed) return !allowedPackages.contains(packageName)
        return false
    }

    fun explicitCandidates(): Set<String> {
        val candidates = LinkedHashSet<String>()
        for (rule in appRules) {
            if (rule.packageName.isNotBlank()) candidates.add(rule.packageName)
        }
        candidates.addAll(blockedPackages)
        return candidates
    }
}

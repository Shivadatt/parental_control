package com.parentcontrol.parent_control.policy

import org.json.JSONArray
import org.json.JSONObject

/** Parses the `policy` object produced by the Flutter PolicyPayload.toJson(). */
object PolicyJson {
    fun parse(json: JSONObject?): ChildPolicy {
        if (json == null) return ChildPolicy()
        return ChildPolicy(
            enforceAppBlocks = json.optBoolean("enforce_app_blocks", true),
            blockAllExceptAllowed = json.optBoolean("block_all_except_allowed", false),
            blockedPackages = readStringSet(json.optJSONArray("blocked_packages")),
            allowedPackages = readStringSet(json.optJSONArray("allowed_packages")),
            appRules = readRules(json.optJSONArray("app_rules")),
            dailyScreenTimeLimitMinutes = optionalInt(json, "daily_screen_time_limit_minutes"),
            bedtimeStartMinutes = optionalInt(json, "bedtime_start_minutes"),
            bedtimeEndMinutes = optionalInt(json, "bedtime_end_minutes")
        )
    }

    private fun readStringSet(array: JSONArray?): Set<String> {
        if (array == null) return emptySet()
        val values = LinkedHashSet<String>()
        for (index in 0 until array.length()) {
            val raw = array.opt(index)
            if (raw == null || raw == JSONObject.NULL) continue
            val text = raw.toString().trim()
            if (text.isNotEmpty()) values.add(text)
        }
        return values
    }

    private fun readRules(array: JSONArray?): List<PolicyAppRule> {
        if (array == null) return emptyList()
        val rules = ArrayList<PolicyAppRule>()
        for (index in 0 until array.length()) {
            val ruleJson = array.optJSONObject(index) ?: continue
            val packageName = ruleJson.optString("package_name", "").trim()
            if (packageName.isEmpty()) continue
            val label = ruleJson.optString("label", packageName).ifBlank { packageName }
            rules.add(
                PolicyAppRule(
                    packageName = packageName,
                    label = label,
                    blocked = ruleJson.optBoolean("blocked", false),
                    windows = readWindows(ruleJson.optJSONArray("windows"))
                )
            )
        }
        return rules
    }

    private fun readWindows(array: JSONArray?): List<PolicyWindow> {
        if (array == null) return emptyList()
        val windows = ArrayList<PolicyWindow>()
        for (index in 0 until array.length()) {
            val windowJson = array.optJSONObject(index) ?: continue
            val days = LinkedHashSet<Int>()
            val daysArray = windowJson.optJSONArray("days_of_week")
            if (daysArray != null) {
                for (dayIndex in 0 until daysArray.length()) {
                    val day = daysArray.optInt(dayIndex, 0)
                    if (day in 1..7) days.add(day)
                }
            }
            val start = windowJson.optInt("start_minutes", 0).coerceIn(0, 1439)
            val end = windowJson.optInt("end_minutes", 0).coerceIn(0, 1439)
            windows.add(PolicyWindow(daysOfWeek = days, startMinutes = start, endMinutes = end))
        }
        return windows
    }

    private fun optionalInt(json: JSONObject, key: String): Int? {
        if (!json.has(key) || json.isNull(key)) return null
        return json.optInt(key)
    }
}

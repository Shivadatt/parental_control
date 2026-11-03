package com.parentcontrol.parent_control

/**
 * The single source of truth for the `enforcement_mode` value this device
 * reports (policy ack `result.enforcement_mode` and the heartbeat
 * `capabilities.enforcement_mode`).
 *
 * Pure on purpose: it takes only the two capability booleans and has no
 * Android, context or singleton dependency, so the rule is covered by a JVM
 * test. `PolicyApplier` (the ack) and `GuardianService` (the heartbeat) both
 * delegate here; keeping two copies would let them drift apart silently.
 *
 * The returned strings are part of the wire contract (`core.sql:101` allows
 * `none` / `device_admin` / `device_owner`) and must stay byte-identical.
 */
object EnforcementMode {
    /**
     * Device Owner wins over an active Device Admin, because a Device Owner is
     * the only state that can really suspend packages. "none" means no
     * enforcement capability at all.
     */
    fun of(isDeviceOwner: Boolean, isAdminActive: Boolean): String = when {
        isDeviceOwner -> "device_owner"
        isAdminActive -> "device_admin"
        else -> "none"
    }
}

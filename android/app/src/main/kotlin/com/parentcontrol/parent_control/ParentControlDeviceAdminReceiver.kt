package com.parentcontrol.parent_control

import android.app.admin.DeviceAdminReceiver

/**
 * Device administration component.
 *
 * Device Administrator alone does not allow app suspension. Suspension requires
 * Device Owner provisioning, which a normal Play installation does not have.
 * A device owner can be provisioned only on a factory-reset device without
 * accounts, for example:
 *
 *   adb shell dpm set-device-owner \
 *     com.parentcontrol.parent_control/.ParentControlDeviceAdminReceiver
 *
 * This app never attempts the provisioning command programmatically.
 */
class ParentControlDeviceAdminReceiver : DeviceAdminReceiver()

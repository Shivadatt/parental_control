#!/usr/bin/env python3
from __future__ import annotations

import argparse

from lane2_adb import filtered_evidence, run_evidence


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("serial")
    parser.add_argument("prefix")
    args = parser.parse_args()

    run_evidence(
        args.serial,
        f"{args.prefix}_identity",
        "shell getprop ro.product.model; getprop ro.product.manufacturer; getprop ro.build.version.release; "
        "getprop ro.build.version.sdk; getprop ro.build.version.security_patch; getprop ro.build.fingerprint",
        60,
    )
    filtered_evidence(
        args.serial,
        f"{args.prefix}_package",
        "shell dumpsys package com.parentcontrol.parent_control",
        90,
        [r"versionName=", r"versionCode=", r"firstInstallTime=", r"lastUpdateTime=", r"userId=", r"pkgFlags="],
        [],
    )
    filtered_evidence(
        args.serial,
        f"{args.prefix}_runtime_permissions",
        "shell dumpsys package com.parentcontrol.parent_control",
        90,
        [r"android\.permission\.(?:CAMERA|RECORD_AUDIO|ACCESS_FINE_LOCATION|ACCESS_COARSE_LOCATION|ACCESS_BACKGROUND_LOCATION|POST_NOTIFICATIONS|PACKAGE_USAGE_STATS)"],
        [],
    )
    run_evidence(args.serial, f"{args.prefix}_appops", "shell cmd appops get com.parentcontrol.parent_control", 90)
    filtered_evidence(
        args.serial,
        f"{args.prefix}_device_policy",
        "shell dumpsys device_policy",
        90,
        [r"com\.parentcontrol\.parent_control", r"Device Owner", r"Device Admin", r"mAdminMap", r"mOwnerComponent"],
        [],
    )
    run_evidence(
        args.serial,
        f"{args.prefix}_accessibility_services",
        "shell settings get secure enabled_accessibility_services",
        60,
    )
    run_evidence(
        args.serial,
        f"{args.prefix}_notification_listeners",
        "shell settings get secure enabled_notification_listeners",
        60,
    )
    run_evidence(
        args.serial,
        f"{args.prefix}_network_settings",
        "shell settings get global wifi_on; settings get global mobile_data; settings get global airplane_mode_on; settings get global low_power",
        60,
    )
    filtered_evidence(
        args.serial,
        f"{args.prefix}_connectivity",
        "shell dumpsys connectivity",
        120,
        [r"Active default network", r"VALIDATED", r"NetworkAgentInfo"],
        [r"SSID", r"BSSID", r"IPv4", r"IPv6", r"linkAddresses", r"dnsAddresses"],
    )
    run_evidence(args.serial, f"{args.prefix}_ping", "shell ping -c 2 -W 3 1.1.1.1", 30)
    filtered_evidence(
        args.serial,
        f"{args.prefix}_power",
        "shell dumpsys power",
        90,
        [r"mWakefulness=", r"Display Power", r"mScreenOn", r"mLowPowerModeEnabled", r"mDeviceIdleMode"],
        [],
    )
    filtered_evidence(
        args.serial,
        f"{args.prefix}_deviceidle",
        "shell dumpsys deviceidle",
        90,
        [r"com\.parentcontrol\.parent_control", r"mState=", r"mLightState=", r"mWhitelist", r"mTempWhitelist", r"mAppIdleEnabled"],
        [],
    )
    filtered_evidence(
        args.serial,
        f"{args.prefix}_netpolicy",
        "shell dumpsys netpolicy",
        90,
        [r"mRestrictBackground", r"restrictBackground", r"mDataSaver", r"uid="],
        [],
    )
    run_evidence(
        args.serial,
        f"{args.prefix}_foreground",
        "shell dumpsys activity activities",
        90,
    )
    run_evidence(
        args.serial,
        f"{args.prefix}_services",
        "shell dumpsys activity services com.parentcontrol.parent_control",
        90,
    )
    return 0


if __name__ == "__main__":
    raise SystemExit(main())

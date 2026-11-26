#!/usr/bin/env python3
from __future__ import annotations

import argparse
import hashlib
import json
import re

from lane2_adb import CWD, PACKAGE, base_adb, decode, ensure_output, now_iso, run_command


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("serial")
    parser.add_argument("phase")
    args = parser.parse_args()

    start = now_iso()
    commands = {
        "accessibility": ["shell", "settings", "get", "secure", "enabled_accessibility_services"],
        "notification_listeners": ["shell", "settings", "get", "secure", "enabled_notification_listeners"],
        "deviceidle": ["shell", "dumpsys", "deviceidle", "whitelist"],
        "device_policy": ["shell", "dumpsys", "device_policy"],
        "power": ["shell", "dumpsys", "power"],
        "netpolicy": ["shell", "dumpsys", "netpolicy"],
        "usage_appop": ["shell", "cmd", "appops", "get", PACKAGE, "GET_USAGE_STATS"],
        "low_power": ["shell", "settings", "get", "global", "low_power_mode"],
        "airplane": ["shell", "settings", "get", "global", "airplane_mode_on"],
        "wifi": ["shell", "settings", "get", "global", "wifi_on"],
        "mobile_data": ["shell", "settings", "get", "global", "mobile_data"],
        "battery_optimization": ["shell", "settings", "get", "secure", "battery_optimization_mode"],
        "screen_timeout": ["shell", "settings", "get", "system", "screen_off_timeout"],
    }
    outputs: dict[str, str] = {}
    records: list[dict] = []
    for key, suffix in commands.items():
        argv = base_adb(args.serial) + suffix
        rc, stdout, stderr, duration = run_command(argv, 90)
        outputs[key] = decode(stdout)
        records.append({
            "key": key,
            "command": " ".join(argv),
            "exit": rc,
            "duration_seconds": round(duration, 3),
            "stdout_lines": len(outputs[key].splitlines()),
            "stderr": decode(stderr).strip(),
        })

    uid_match = re.search(r"uid:(\d+)", decode(run_command(base_adb(args.serial) + ["shell", "cmd", "package", "list", "packages", "-U", PACKAGE], 60)[1]))
    uid = uid_match.group(1) if uid_match else None
    uid_policy_lines = [line.strip() for line in outputs["netpolicy"].splitlines() if uid and re.search(rf"\bUID={re.escape(uid)}\b", line)]
    summary = {
        "start": start,
        "end": now_iso(),
        "serial": args.serial,
        "package": PACKAGE,
        "cwd": str(CWD),
        "mode": "read-only capability probe; unrelated package identities and setting values are not retained",
        "uid": uid,
        "haven_accessibility_enabled": PACKAGE in outputs["accessibility"],
        "haven_notification_listener_enabled": PACKAGE in outputs["notification_listeners"],
        "haven_device_idle_whitelisted": PACKAGE in outputs["deviceidle"],
        "haven_device_admin_enabled": bool(re.search(rf"{re.escape(PACKAGE)}/\.ParentControlDeviceAdminReceiver", outputs["device_policy"])),
        "haven_device_owner_enabled": bool(re.search(rf"Device Owner[^\n]*{re.escape(PACKAGE)}|mOwnerComponent[^\n]*{re.escape(PACKAGE)}", outputs["device_policy"], re.I)),
        "usage_access_appop": next((line.strip() for line in outputs["usage_appop"].splitlines() if "GET_USAGE_STATS" in line), "unknown"),
        "low_power_mode": outputs["low_power"].strip(),
        "airplane_mode_on": outputs["airplane"].strip(),
        "wifi_on": outputs["wifi"].strip(),
        "mobile_data": outputs["mobile_data"].strip(),
        "battery_optimization_mode": outputs["battery_optimization"].strip(),
        "screen_off_timeout_ms": outputs["screen_timeout"].strip(),
        "uid_netpolicy_lines": uid_policy_lines,
        "power_markers": [line.strip() for line in outputs["power"].splitlines() if re.search(r"mWakefulness=|mDeviceIdleMode=|mLowPowerModeEnabled", line)],
    }
    output = ensure_output(f"{args.phase}.txt")
    body = [
        f"start={start}",
        f"end={summary['end']}",
        f"serial={args.serial}",
        f"cwd={CWD}",
        f"package={PACKAGE}",
        "mode=read-only capability probe",
        "--- command records ---",
        json.dumps(records, indent=2),
        "--- sanitized summary ---",
        json.dumps(summary, indent=2),
    ]
    output.write_text("\n".join(body) + "\n", encoding="utf-8", newline="\n")
    meta = {
        **summary,
        "output": str(output),
        "sha256": hashlib.sha256(output.read_bytes()).hexdigest(),
        "commands": records,
    }
    meta_path = ensure_output(f"{args.phase}.json")
    meta_path.write_text(json.dumps(meta, indent=2) + "\n", encoding="utf-8", newline="\n")
    print(json.dumps(summary))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())

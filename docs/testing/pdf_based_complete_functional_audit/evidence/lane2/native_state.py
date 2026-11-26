#!/usr/bin/env python3
from __future__ import annotations

import argparse
import hashlib
import json
import re

from lane2_adb import (
    CWD,
    PACKAGE,
    base_adb,
    decode,
    ensure_output,
    now_iso,
    run_command,
    sanitize,
)


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("serial")
    parser.add_argument("phase")
    args = parser.parse_args()

    start = now_iso()
    commands = {
        "activities": ["shell", "dumpsys", "activity", "activities"],
        "services": ["shell", "dumpsys", "activity", "services", PACKAGE],
        "camera": ["shell", "dumpsys", "media.camera"],
        "audio": ["shell", "dumpsys", "audio"],
        "camera_op": ["shell", "cmd", "appops", "get", PACKAGE, "CAMERA"],
        "microphone_op": ["shell", "cmd", "appops", "get", PACKAGE, "RECORD_AUDIO"],
        "power": ["shell", "dumpsys", "power"],
    }
    outputs: dict[str, str] = {}
    records = []
    for key, suffix in commands.items():
        argv = base_adb(args.serial) + suffix
        rc, stdout, stderr, duration = run_command(argv, 90)
        outputs[key] = decode(stdout)
        records.append(
            f"{key}_start={now_iso()} command={' '.join(argv)} cwd={CWD} "
            f"exit={rc} duration_seconds={duration:.3f} stdout_lines={len(outputs[key].splitlines())}"
        )
        if stderr:
            records.append(f"{key}_stderr={sanitize(decode(stderr)).strip()}")

    service_lines = [
        line for line in outputs["services"].splitlines()
        if re.search(rf"ServiceRecord\{{[^}}]*{re.escape(PACKAGE)}/\.(?:GuardianService|LocationTrackingService|AudioAssistanceService)\}}", line)
        or re.search(r"isForeground=|foregroundId=|startRequested=|crashCount=|lastActivity=", line)
        or "(nothing)" in line
    ]
    service_names = [
        name for name in ("GuardianService", "LocationTrackingService", "AudioAssistanceService")
        if any(f"/.{name}}}" in line for line in service_lines)
    ]

    camera_section = outputs["camera"].split("Active Camera Clients:", 1)[-1].split("== Camera Provider HAL", 1)[0]
    camera_package_present = bool(re.search(rf"Client Package Name:\s*{re.escape(PACKAGE)}\b", camera_section))
    open_camera_devices = sorted(set(re.findall(r"Device (\d+) is open", camera_section)))
    camera_open = camera_package_present and bool(open_camera_devices)
    camera_selected = [
        line for line in outputs["camera"].splitlines()
        if "Active Camera Clients:" in line
        or re.search(rf"{re.escape(PACKAGE)}|Device \d+ is (?:open|closed)", line)
    ]

    audio_blocks = re.findall(
        rf"- Package: {re.escape(PACKAGE)}(.*?)(?=\n  - Package:|\Z)",
        outputs["audio"],
        flags=re.S,
    )
    recording_active = any(re.search(r"Recording active:\s*true", block) for block in audio_blocks)
    playback_active = any(re.search(r"Playback active:\s*true", block) for block in audio_blocks)
    audio_selected: list[str] = []
    in_target = False
    for line in outputs["audio"].splitlines():
        if re.search(r"^\s*- Package:", line):
            in_target = PACKAGE in line
            audio_selected.append(f"  - Package: {PACKAGE}" if in_target else "  - Package: [OTHER PACKAGE]")
        if in_target and (PACKAGE in line or re.search(r"Playback active:|Recording active:|Update time:", line)):
            audio_selected.append(line)
        elif re.search(rf"rec (?:update|stop).*pack:{re.escape(PACKAGE)}", line):
            audio_selected.append(line)

    activity_selected = [
        line for line in outputs["activities"].splitlines()
        if re.search(r"mResumedActivity|topResumedActivity|mFocusedApp", line)
    ]
    power_selected = [
        line for line in outputs["power"].splitlines()
        if re.search(r"mWakefulness=|Display Power|mScreenOn|mHoldingDisplaySuspendBlocker", line)
    ]

    def appop_mode(key: str, name: str) -> str:
        return next(
            (line.strip().split(";", 1)[0] for line in outputs[key].splitlines() if line.strip().startswith(f"{name}:")),
            "unknown",
        )

    summary = {
        "start": start,
        "end": now_iso(),
        "serial": args.serial,
        "package": PACKAGE,
        "cwd": str(CWD),
        "foreground_activity_lines": [sanitize(line.strip()) for line in activity_selected],
        "screen_lines": [sanitize(line.strip()) for line in power_selected],
        "services": service_names,
        "camera_open": camera_open,
        "camera_package_in_active_clients": camera_package_present,
        "open_camera_devices": open_camera_devices,
        "recording_active": recording_active,
        "playback_active": playback_active,
        "camera_op": appop_mode("camera_op", "CAMERA"),
        "microphone_op": appop_mode("microphone_op", "RECORD_AUDIO"),
    }
    output = ensure_output(f"{args.phase}.txt")
    body = [
        f"start={start}",
        f"end={summary['end']}",
        f"serial={args.serial}",
        f"cwd={CWD}",
        f"package={PACKAGE}",
        "mode=read-only native-state snapshot",
        *records,
        "--- summary ---",
        json.dumps(summary, indent=2),
        "--- foreground activity ---",
        *[sanitize(line) for line in activity_selected],
        "--- screen power ---",
        *[sanitize(line) for line in power_selected],
        "--- services ---",
        *[sanitize(line) for line in service_lines],
        "--- active camera ---",
        *[sanitize(line) for line in camera_selected],
        "--- audio package state ---",
        *[sanitize(line) for line in audio_selected],
        "--- camera app-op ---",
        sanitize(outputs["camera_op"]),
        "--- microphone app-op ---",
        sanitize(outputs["microphone_op"]),
    ]
    output.write_text("\n".join(body) + "\n", encoding="utf-8", newline="\n")
    meta = ensure_output(f"{args.phase}.json")
    meta.write_text(
        sanitize(json.dumps({**summary, "output": str(output), "sha256": hashlib.sha256(output.read_bytes()).hexdigest()}, indent=2)) + "\n",
        encoding="utf-8",
        newline="\n",
    )
    print(json.dumps({"exit": 0, "summary": summary, "output": str(output)}))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())

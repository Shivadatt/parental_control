#!/usr/bin/env python3
"""Timestamped, sanitized Child runtime samples for one lane-2 scenario."""

from __future__ import annotations

import argparse
import json
import re
import time
from pathlib import Path

from lane2_adb import (
    CWD,
    LANE2,
    PACKAGE,
    ensure_output,
    filtered_evidence,
    now_iso,
    run_evidence,
)


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("serial")
    parser.add_argument("phase")
    parser.add_argument("--samples", type=int, default=7)
    parser.add_argument("--interval", type=int, default=60)
    args = parser.parse_args()

    summary = ensure_output(f"{args.phase}_monitor_summary.txt")
    start = now_iso()
    lines = [
        f"start={start}",
        f"serial={args.serial}",
        f"cwd={CWD}",
        f"package={PACKAGE}",
        f"samples_requested={args.samples}",
        f"interval_seconds={args.interval}",
        "mode=read-only ADB diagnostics; no force-stop, permission, network, or data changes",
    ]
    summary.write_text("\n".join(lines) + "\n", encoding="utf-8", newline="\n")

    run_evidence(args.serial, f"{args.phase}_uid", f"shell cmd package list packages -U {PACKAGE}", 60)
    uid_text = ensure_output(f"{args.phase}_uid.txt").read_text(encoding="utf-8")
    match = re.search(r"uid:(\d+)", uid_text)
    uid = match.group(1) if match else "UNKNOWN"

    for sample in range(1, args.samples + 1):
        sample_start = now_iso()
        prefix = f"{args.phase}_s{sample:02d}"
        run_evidence(args.serial, f"{prefix}_pid", f"shell pidof {PACKAGE}", 60)
        filtered_evidence(
            args.serial, f"{prefix}_activity", "shell dumpsys activity activities", 90,
            [r"mResumedActivity", r"topResumedActivity", r"mFocusedApp", re.escape(PACKAGE)], [],
        )
        filtered_evidence(
            args.serial, f"{prefix}_services", f"shell dumpsys activity services {PACKAGE}", 90,
            [re.escape(PACKAGE), r"ServiceRecord", r"isForeground", r"foregroundId", r"startRequested", r"crashCount", r"lastActivity"], [],
        )
        filtered_evidence(
            args.serial, f"{prefix}_processes", "shell dumpsys activity processes", 90,
            [re.escape(PACKAGE)], [],
        )
        filtered_evidence(
            args.serial, f"{prefix}_netstats", "shell dumpsys netstats detail", 120,
            [rf"\buid={re.escape(uid)}\b"], [],
        )
        run_evidence(args.serial, f"{prefix}_appops", f"shell appops get {PACKAGE}", 90)
        filtered_evidence(
            args.serial, f"{prefix}_power", "shell dumpsys power", 90,
            [r"mWakefulness=", r"Display Power", r"mScreenOn", r"mHoldingDisplaySuspendBlocker", r"mHoldingWakeLockSuspendBlocker"], [],
        )
        filtered_evidence(
            args.serial, f"{prefix}_deviceidle", "shell dumpsys deviceidle whitelist", 90,
            [re.escape(PACKAGE), r"User Whitelist", r"System Whitelist"], [],
        )
        filtered_evidence(
            args.serial, f"{prefix}_netpolicy", "shell dumpsys netpolicy", 90,
            [rf"\buid={re.escape(uid)}\b", r"mRestrictBackground", r"restrictBackground", r"mDataSaver"], [],
        )
        filtered_evidence(
            args.serial, f"{prefix}_location", "shell dumpsys location", 90,
            [re.escape(PACKAGE), r"Location Manager State", r"mEnabledProviders", r"mDisabledProviders", r"gps", r"network"],
            [r"last location", r"latitude", r"longitude", r"mLastLocation"],
        )
        filtered_evidence(
            args.serial, f"{prefix}_audio_capture", "shell dumpsys audio", 90,
            [re.escape(PACKAGE)], [],
        )
        filtered_evidence(
            args.serial, f"{prefix}_camera_capture", "shell dumpsys media.camera", 90,
            [re.escape(PACKAGE)], [],
        )
        sample_end = now_iso()
        with summary.open("a", encoding="utf-8", newline="\n") as handle:
            handle.write(f"sample={sample} start={sample_start} end={sample_end} uid={uid} commands=12 evidence_prefix={prefix}\n")
        if sample < args.samples:
            time.sleep(args.interval)

    end = now_iso()
    with summary.open("a", encoding="utf-8", newline="\n") as handle:
        handle.write(f"end={end} samples_completed={args.samples} commands_total={1 + args.samples * 12}\n")
    print(json.dumps({"phase": args.phase, "samples": args.samples, "uid": uid, "summary": str(summary), "end": end}))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())

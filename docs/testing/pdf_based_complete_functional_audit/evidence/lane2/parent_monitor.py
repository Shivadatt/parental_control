#!/usr/bin/env python3
from __future__ import annotations

import argparse
import json
import time

from lane2_adb import ensure_output, now_iso, sanitize, ui_evidence


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("serial")
    parser.add_argument("phase")
    parser.add_argument("--samples", type=int, default=8)
    parser.add_argument("--interval", type=int, default=60)
    args = parser.parse_args()

    summary = ensure_output(f"{args.phase}_summary.txt")
    lines = [
        f"start={now_iso()}",
        f"serial={args.serial}",
        f"samples_requested={args.samples}",
        f"interval_seconds={args.interval}",
        "mode=read-only Parent UI sampling",
    ]
    summary.write_text("\n".join(lines) + "\n", encoding="utf-8", newline="\n")

    for sample in range(1, args.samples + 1):
        sample_start = now_iso()
        rc, records, output, _ = ui_evidence(args.serial, f"{args.phase}_s{sample:02d}", 90)
        sample_end = now_iso()
        values = [
            sanitize(record["text"] or record["content_desc"])
            for record in records
            if record["text"] or record["content_desc"]
        ]
        markers = [
            value for value in values
            if any(term in value.casefold() for term in (
                "dashboard", "online", "offline", "sync", "last seen", "battery", "policy",
                "enforcement", "device permissions", "usage access", "location", "camera", "microphone",
            ))
        ]
        with summary.open("a", encoding="utf-8", newline="\n") as handle:
            handle.write(
                f"sample={sample} start={sample_start} end={sample_end} exit={rc} "
                f"node_count={len(records)} evidence={output}\n"
            )
            for marker in markers:
                handle.write(f"sample={sample}_marker={marker}\n")
        if sample < args.samples:
            time.sleep(args.interval)

    end = now_iso()
    with summary.open("a", encoding="utf-8", newline="\n") as handle:
        handle.write(f"end={end} samples_completed={args.samples}\n")
    print(json.dumps({"exit": 0, "phase": args.phase, "samples": args.samples, "summary": str(summary), "end": end}))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())

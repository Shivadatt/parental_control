#!/usr/bin/env python3
"""Read-only/sanitized ADB evidence helpers for lane 2.

All retained output is written below lane2. The script redacts account emails,
coordinates, credentials, tokens, and long token-like hex values before writing.
"""

from __future__ import annotations

import argparse
import hashlib
import io
import json
import os
import re
import shlex
import subprocess
import sys
import time
from datetime import datetime, timezone
from pathlib import Path
from xml.etree import ElementTree as ET

from PIL import Image, ImageDraw

LANE2 = Path(r"D:\parentcontrol_app\docs\testing\pdf_based_complete_functional_audit\evidence\lane2").resolve()
OUTPUT_ROOT = Path(os.environ.get("HAVEN_EVIDENCE_ROOT", str(LANE2))).resolve()
CWD = Path(r"D:\parentcontrol_app").resolve()
PACKAGE = "com.parentcontrol.parent_control"
DEVICE_DUMP = "/data/local/tmp/haven_lane2_ui.xml"


def now_iso() -> str:
    return datetime.now(timezone.utc).astimezone().isoformat(timespec="seconds")


def ensure_output(path: str) -> Path:
    value = Path(path)
    if not value.is_absolute():
        value = OUTPUT_ROOT / value
    value = value.resolve()
    if OUTPUT_ROOT not in value.parents and value != OUTPUT_ROOT:
        raise ValueError(f"Output must stay inside {OUTPUT_ROOT}")
    value.parent.mkdir(parents=True, exist_ok=True)
    return value


def sanitize(text: str) -> str:
    protected_metrics: list[str] = []

    def protect_metric(match: re.Match[str]) -> str:
        protected_metrics.append(match.group(0))
        return f"__HAVEN_METRIC_{len(protected_metrics) - 1}__"

    def protect_digest(match: re.Match[str]) -> str:
        protected_metrics.append(match.group(0))
        return f"__HAVEN_DIGEST_{len(protected_metrics) - 1}__"

    def protect_timestamp(match: re.Match[str]) -> str:
        protected_metrics.append(match.group(0))
        return f"__HAVEN_TIMESTAMP_{len(protected_metrics) - 1}__"

    text = re.sub(
        r"(?i)\b(?:duration|duration_seconds|duration_ms)\b['\"]?\s*[:=]\s*['\"]?-?\d+(?:\.\d+)?",
        protect_metric,
        text,
    )
    text = re.sub(
        r"(?i)\b(?:sha256|sha256_sanitized_output|unstaged_diff_sha256|staged_diff_sha256)\b['\"]?\s*[:=]\s*['\"]?[A-Fa-f0-9]{64}\b",
        protect_digest,
        text,
    )
    text = re.sub(
        r"\b\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2}(?:\.\d+)?(?:Z|[+-]\d{2}:\d{2})?\b",
        protect_timestamp,
        text,
    )
    text = re.sub(r"\b\d{2}-\d{2}\s+\d{2}:\d{2}:\d{2}(?:\.\d+)?\b", protect_timestamp, text)
    text = re.sub(r"[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Za-z]{2,}", "[REDACTED_EMAIL]", text)
    text = re.sub(r"(?i)\b(Display name|Family name|Child name)\n[^\n]+", r"\1\n[REDACTED_NAME]", text)
    text = re.sub(r"\beyJ[A-Za-z0-9_-]+\.[A-Za-z0-9_-]+\.[A-Za-z0-9_-]+\b", "[REDACTED_TOKEN]", text)
    text = re.sub(r"\b[A-Fa-f0-9]{32,}\b", "[REDACTED_HEX]", text)
    text = re.sub(r"(?i)\b(lat(?:itude)?|lng|longitude)\b['\"]?\s*[:=]\s*['\"]?-?\d+(?:\.\d+)?", r"\1=[REDACTED_COORD]", text)
    text = re.sub(r"-?\d{1,3}\.\d{3,}\s*,\s*-?\d{1,3}\.\d{3,}", "[REDACTED_COORD]", text)
    text = re.sub(r"(?<![\w.])-?\d{1,3}\.\d{3,}(?![\w.])", "[REDACTED_COORD]", text)
    text = re.sub(r'(?i)\bnetworkId="[^"\n]*"', 'networkId="[REDACTED_NETWORK]"', text)
    text = re.sub(r'(?i)\b(?:ssid|bssid)="[^"\n]*"', '[REDACTED_NETWORK]', text)
    text = re.sub(r"(?<![\w.])com\.(?!parentcontrol\.parent_control\b)[A-Za-z0-9_.]+", "[REDACTED_PACKAGE]", text)
    text = re.sub(r"\bPC-[A-Z0-9]{8}\b", "[REDACTED_CHILD_ID]", text)
    text = re.sub(
        r"(?i)\b(authorization|x-device-secret|apikey|api[_-]?key|access[_-]?token|refresh[_-]?token|device[_-]?secret|password|secret)\b['\"]?\s*[:=]\s*['\']?[^,\s;\"'}]+",
        r"\1=[REDACTED_SECRET]",
        text,
    )
    text = re.sub(r"(?i)(https?://[^\s?]+)\?[^\s\"']+", r"\1?[REDACTED_QUERY]", text)
    for index, value in enumerate(protected_metrics):
        text = text.replace(f"__HAVEN_METRIC_{index}__", value)
        text = text.replace(f"__HAVEN_DIGEST_{index}__", value)
        text = text.replace(f"__HAVEN_TIMESTAMP_{index}__", value)
    return text


def sha256_bytes(data: bytes) -> str:
    return hashlib.sha256(data).hexdigest()


def write_text(path: Path, text: str) -> None:
    path.write_text(sanitize(text), encoding="utf-8", newline="\n")


def base_adb(serial: str) -> list[str]:
    adb = os.environ.get("ADB", "adb")
    return [adb, "-s", serial]


def run_command(argv: list[str], timeout: int) -> tuple[int, bytes, bytes, float]:
    started = time.monotonic()
    try:
        result = subprocess.run(argv, cwd=str(CWD), capture_output=True, timeout=timeout, check=False)
        return result.returncode, result.stdout, result.stderr, time.monotonic() - started
    except subprocess.TimeoutExpired as exc:
        return 124, exc.stdout or b"", (exc.stderr or b"") + f"\nTIMEOUT after {timeout}s\n".encode(), time.monotonic() - started


def decode(data: bytes) -> str:
    return data.decode("utf-8", errors="replace")


def save_meta(name: str, payload: dict) -> None:
    meta_path = ensure_output(f"{name}.json")
    meta_path.write_text(sanitize(json.dumps(payload, indent=2, ensure_ascii=False)) + "\n", encoding="utf-8", newline="\n")


def run_evidence(serial: str, name: str, command: str, timeout: int) -> int:
    output = ensure_output(f"{name}.txt")
    argv = base_adb(serial) + shlex.split(command)
    start = now_iso()
    rc, stdout, stderr, duration = run_command(argv, timeout)
    end = now_iso()
    clean_stdout = sanitize(decode(stdout))
    clean_stderr = sanitize(decode(stderr))
    body = (
        f"start={start}\nend={end}\nserial={serial}\ncwd={CWD}\n"
        f"command={shlex.join(argv)}\nexit={rc}\nduration_seconds={duration:.3f}\n"
        f"stdout_lines={len(clean_stdout.splitlines())}\nstderr_lines={len(clean_stderr.splitlines())}\n"
        "--- stdout ---\n" + clean_stdout + ("" if clean_stdout.endswith("\n") else "\n") +
        "--- stderr ---\n" + clean_stderr + ("" if clean_stderr.endswith("\n") else "\n")
    )
    output.write_text(body, encoding="utf-8", newline="\n")
    save_meta(name, {
        "start": start,
        "end": end,
        "serial": serial,
        "cwd": str(CWD),
        "command": shlex.join(argv),
        "exit": rc,
        "duration_seconds": round(duration, 3),
        "stdout_lines": len(clean_stdout.splitlines()),
        "stderr_lines": len(clean_stderr.splitlines()),
        "stdout_bytes_sanitized": len(clean_stdout.encode()),
        "stderr_bytes_sanitized": len(clean_stderr.encode()),
        "sha256_sanitized_output": sha256_bytes(body.encode()),
        "output": str(output),
    })
    print(json.dumps({"exit": rc, "duration_seconds": round(duration, 3), "output": str(output), "sha256": sha256_bytes(body.encode())}))
    return rc


def filtered_evidence(serial: str, name: str, command: str, timeout: int, includes: list[str], excludes: list[str]) -> int:
    output = ensure_output(f"{name}.txt")
    argv = base_adb(serial) + shlex.split(command)
    start = now_iso()
    rc, stdout, stderr, duration = run_command(argv, timeout)
    end = now_iso()
    raw_lines = decode(stdout).splitlines()
    include_patterns = [re.compile(value, re.IGNORECASE) for value in includes]
    exclude_patterns = [re.compile(value, re.IGNORECASE) for value in excludes]
    selected = []
    for line in raw_lines:
        if include_patterns and not any(pattern.search(line) for pattern in include_patterns):
            continue
        if any(pattern.search(line) for pattern in exclude_patterns):
            continue
        selected.append(line)
    clean_stdout = sanitize("\n".join(selected))
    clean_stderr = sanitize(decode(stderr))
    body = (
        f"start={start}\nend={end}\nserial={serial}\ncwd={CWD}\n"
        f"command={shlex.join(argv)}\nexit={rc}\nduration_seconds={duration:.3f}\n"
        f"raw_stdout_lines={len(raw_lines)}\nselected_stdout_lines={len(selected)}\n"
        f"include={json.dumps(includes)}\nexclude={json.dumps(excludes)}\n"
        "--- selected stdout ---\n" + clean_stdout + ("" if clean_stdout.endswith("\n") else "\n") +
        "--- stderr ---\n" + clean_stderr + ("" if clean_stderr.endswith("\n") else "\n")
    )
    output.write_text(body, encoding="utf-8", newline="\n")
    save_meta(name, {
        "start": start,
        "end": end,
        "serial": serial,
        "cwd": str(CWD),
        "command": shlex.join(argv),
        "exit": rc,
        "duration_seconds": round(duration, 3),
        "raw_stdout_lines": len(raw_lines),
        "selected_stdout_lines": len(selected),
        "include": includes,
        "exclude": excludes,
        "sha256_sanitized_output": sha256_bytes(body.encode()),
        "output": str(output),
    })
    print(json.dumps({"exit": rc, "raw_lines": len(raw_lines), "selected_lines": len(selected), "output": str(output)}))
    return rc


def dump_ui(serial: str, timeout: int) -> tuple[int, str, str, str]:
    dump_cmd = base_adb(serial) + ["shell", "uiautomator", "dump", DEVICE_DUMP]
    rc1, out1, err1, _ = run_command(dump_cmd, timeout)
    read_cmd = base_adb(serial) + ["exec-out", "cat", DEVICE_DUMP]
    rc2, xml_bytes, err2, _ = run_command(read_cmd, timeout)
    clean_cmd = base_adb(serial) + ["shell", "rm", "-f", DEVICE_DUMP]
    rc3, _, err3, _ = run_command(clean_cmd, timeout)
    xml = decode(xml_bytes)
    messages = decode(out1) + decode(err1) + decode(err2) + decode(err3)
    return (rc1 or rc2 or rc3), xml, shlex.join(dump_cmd), sanitize(messages)


def node_records(xml: str) -> list[dict]:
    records: list[dict] = []
    try:
        root = ET.fromstring(xml)
    except ET.ParseError:
        return records
    for node in root.iter("node"):
        text = node.attrib.get("text", "")
        desc = node.attrib.get("content-desc", "")
        records.append({
            "text": text,
            "content_desc": desc,
            "resource_id": node.attrib.get("resource-id", ""),
            "class": node.attrib.get("class", ""),
            "clickable": node.attrib.get("clickable", ""),
            "bounds": node.attrib.get("bounds", ""),
        })
    return records


def redact_account_identifiers(records: list[dict]) -> list[dict]:
    account_names: set[str] = set()
    for record in records:
        desc = record["content_desc"]
        if "This account is linked as a child" in desc and desc.splitlines()[0].strip():
            account_names.add(desc.splitlines()[0].strip())
        signed_in = re.search(r"Signed in as\n([^\n]+)", desc)
        if signed_in:
            account_names.add(signed_in.group(1).strip())
        dashboard_card = re.match(r"([^\n]+)\n[^\n]+\n(?:Revoked|Online|Offline)\nLast seen", desc)
        if dashboard_card:
            account_names.add(dashboard_card.group(1).strip())
    retained: list[dict] = []
    for record in records:
        text = record["text"]
        desc = record["content_desc"]
        if text.strip() in account_names:
            text = "[REDACTED_ACCOUNT]"
        if desc.strip() in account_names:
            desc = "[REDACTED_ACCOUNT]"
        for name in account_names:
            desc = re.sub(rf"(?m)^{re.escape(name)}$", "[REDACTED_ACCOUNT]", desc)
        desc = re.sub(r"(Signed in as\n)[^\n]+", r"\1[REDACTED_ACCOUNT]", desc)
        if "From usage_daily rows uploaded by the device" in desc:
            desc = re.sub(
                r"(?m)^(?!Parent Control$)([^\n]+)\n((?:\d+h )?\d+m(?: \d+s)?|\d+s)\nLast used",
                r"[REDACTED_APP]\n\2\nLast used",
                desc,
            )
        bounds = parse_bounds(record["bounds"])
        if (
            bounds
            and bounds[0] < 100
            and 150 <= bounds[1] <= 260
            and record["class"] == "android.view.View"
            and record["clickable"] == "false"
            and "\n" not in desc
            and desc
        ):
            desc = "[REDACTED_HEADER]"
        retained.append({**record, "text": text, "content_desc": desc})
    return retained


def omit_notification_contents(records: list[dict]) -> tuple[list[dict], int]:
    retained: list[dict] = []
    omitted = 0
    in_notification_shade = False
    for record in records:
        resource_id = record.get("resource_id", "")
        if resource_id == "com.android.systemui:id/notification_stack_scroller":
            retained.append({**record, "text": "[REDACTED_UNRELATED_NOTIFICATION]", "content_desc": ""})
            in_notification_shade = True
            continue
        if in_notification_shade:
            if resource_id == "com.android.systemui:id/keyguard_bottom_area":
                in_notification_shade = False
                retained.append(record)
            else:
                omitted += 1
            continue
        retained.append(record)
    return retained, omitted


def sensitive(text: str) -> bool:
    return sanitize(text) != text


def parse_bounds(value: str) -> tuple[int, int, int, int] | None:
    match = re.fullmatch(r"\[(\d+),(\d+)\]\[(\d+),(\d+)\]", value)
    if not match:
        return None
    return tuple(int(part) for part in match.groups())  # type: ignore[return-value]


def ui_evidence(serial: str, name: str, timeout: int) -> tuple[int, list[dict], str, str]:
    start = now_iso()
    rc, xml, command, messages = dump_ui(serial, timeout)
    end = now_iso()
    records = node_records(xml)
    records = redact_account_identifiers(records)
    records, omitted_notification_nodes = omit_notification_contents(records)
    lines = [f"start={start}", f"end={end}", f"serial={serial}", f"cwd={CWD}", f"ui_command={command}", f"exit={rc}"]
    lines.append(f"node_count={len(records)}")
    lines.append(f"omitted_notification_nodes={omitted_notification_nodes}")
    for index, record in enumerate(records):
        lines.append(
            f"{index}|text={sanitize(record['text'])}|desc={sanitize(record['content_desc'])}|"
            f"id={record['resource_id']}|class={record['class']}|clickable={record['clickable']}|bounds={record['bounds']}"
        )
    output = ensure_output(f"{name}.ui.txt")
    output.write_text("\n".join(lines) + "\n" + messages, encoding="utf-8", newline="\n")
    save_meta(name + "_ui", {
        "start": start,
        "end": end,
        "serial": serial,
        "cwd": str(CWD),
        "command": command,
        "device_temp_file": DEVICE_DUMP,
        "device_temp_file_removed": True,
        "exit": rc,
        "node_count": len(records),
        "omitted_notification_nodes": omitted_notification_nodes,
        "output": str(output),
        "sha256": sha256_bytes(output.read_bytes()),
    })
    print(json.dumps({"exit": rc, "node_count": len(records), "output": str(output)}))
    return rc, records, output.as_posix(), xml


def screenshot(serial: str, name: str, timeout: int, strip_body: bool, crop: str | None) -> int:
    ui_rc, records, ui_path, _ = ui_evidence(serial, name, timeout)
    shot_cmd = base_adb(serial) + ["exec-out", "screencap", "-p"]
    start = now_iso()
    rc, png, stderr, duration = run_command(shot_cmd, timeout)
    end = now_iso()
    if rc != 0:
        print(json.dumps({"exit": rc, "ui_exit": ui_rc, "ui": ui_path, "stderr": sanitize(decode(stderr))}))
        return rc
    image = Image.open(io.BytesIO(png)).convert("RGB")
    draw = ImageDraw.Draw(image)
    redactions = 0
    for record in records:
        if sensitive(record["text"]) or sensitive(record["content_desc"]):
            bounds = parse_bounds(record["bounds"])
            if bounds:
                left, top, right, bottom = bounds
                draw.rectangle((max(0, left - 6), max(0, top - 6), min(image.width - 1, right + 6), min(image.height - 1, bottom + 6)), fill=(0, 0, 0))
                redactions += 1
    if strip_body and image.height > 180:
        draw.rectangle((0, 100, image.width, image.height - 90), fill=(0, 0, 0))
    if crop:
        values = [int(part) for part in crop.split(",")]
        if len(values) != 4:
            raise ValueError("crop must be left,top,right,bottom")
        image = image.crop(tuple(values))
    output = ensure_output(f"{name}.png")
    image.save(output, format="PNG", optimize=True)
    save_meta(name + "_shot", {
        "start": start,
        "end": end,
        "serial": serial,
        "cwd": str(CWD),
        "command": shlex.join(shot_cmd),
        "exit": rc,
        "duration_seconds": round(duration, 3),
        "image_size_after_processing": list(image.size),
        "redacted_sensitive_nodes": redactions,
        "body_stripped": strip_body,
        "crop": crop,
        "ui_evidence": ui_path,
        "output": str(output),
        "sha256": sha256_bytes(output.read_bytes()),
    })
    print(json.dumps({"exit": rc, "ui_exit": ui_rc, "output": str(output), "redactions": redactions, "sha256": sha256_bytes(output.read_bytes())}))
    return rc


def tap_text(serial: str, name: str, text: str, timeout: int, occurrence: int) -> int:
    _, records, ui_path, _ = ui_evidence(serial, name, timeout)
    matches = []
    needle = text.casefold()
    tab_pattern = re.compile(rf"{re.escape(needle)}\s+Tab \d+ of \d+", re.IGNORECASE)
    for record in records:
        values = (record["text"], record["content_desc"])
        if any(value.casefold() == needle or tab_pattern.fullmatch(value) for value in values) and parse_bounds(record["bounds"]):
            matches.append(record)
    if occurrence < 0 or occurrence >= len(matches):
        print(json.dumps({"exit": 3, "matches": len(matches), "wanted": sanitize(text), "ui": ui_path}))
        return 3
    bounds = parse_bounds(matches[occurrence]["bounds"])
    assert bounds is not None
    left, top, right, bottom = bounds
    x = (left + right) // 2
    y = (top + bottom) // 2
    return run_evidence(serial, name + "_tap", f"shell input tap {x} {y}", timeout)


def key_event(serial: str, name: str, key: str, timeout: int) -> int:
    return run_evidence(serial, name, f"shell input keyevent {key}", timeout)


def main() -> int:
    parser = argparse.ArgumentParser()
    sub = parser.add_subparsers(dest="action", required=True)

    run_p = sub.add_parser("run")
    run_p.add_argument("serial")
    run_p.add_argument("name")
    run_p.add_argument("command")
    run_p.add_argument("--timeout", type=int, default=180)

    filter_p = sub.add_parser("filter")
    filter_p.add_argument("serial")
    filter_p.add_argument("name")
    filter_p.add_argument("command")
    filter_p.add_argument("--include", action="append", default=[])
    filter_p.add_argument("--exclude", action="append", default=[])
    filter_p.add_argument("--timeout", type=int, default=180)

    ui_p = sub.add_parser("ui")
    ui_p.add_argument("serial")
    ui_p.add_argument("name")
    ui_p.add_argument("--timeout", type=int, default=180)

    shot_p = sub.add_parser("shot")
    shot_p.add_argument("serial")
    shot_p.add_argument("name")
    shot_p.add_argument("--timeout", type=int, default=180)
    shot_p.add_argument("--strip-body", action="store_true")
    shot_p.add_argument("--crop")

    tap_p = sub.add_parser("tap")
    tap_p.add_argument("serial")
    tap_p.add_argument("name")
    tap_p.add_argument("text")
    tap_p.add_argument("--occurrence", type=int, default=0)
    tap_p.add_argument("--timeout", type=int, default=180)

    key_p = sub.add_parser("key")
    key_p.add_argument("serial")
    key_p.add_argument("name")
    key_p.add_argument("key")

    args = parser.parse_args()
    if args.action == "run":
        return run_evidence(args.serial, args.name, args.command, args.timeout)
    if args.action == "filter":
        return filtered_evidence(args.serial, args.name, args.command, args.timeout, args.include, args.exclude)
    if args.action == "ui":
        return ui_evidence(args.serial, args.name, args.timeout)[0]
    if args.action == "shot":
        return screenshot(args.serial, args.name, args.timeout, args.strip_body, args.crop)
    if args.action == "tap":
        return tap_text(args.serial, args.name, args.text, args.timeout, args.occurrence)
    if args.action == "key":
        return key_event(args.serial, args.name, args.key, 180)
    return 2


if __name__ == "__main__":
    try:
        raise SystemExit(main())
    except Exception as exc:
        print(json.dumps({"exit": 1, "error": sanitize(str(exc))}))
        raise SystemExit(1)

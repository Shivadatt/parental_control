#!/usr/bin/env python3
"""Sanitized two-device evidence collector for lane 3 BG-03/BG-04/BG-05.

Only visible app controls are tapped. Child consent and Android prompts are
never bypassed. No credentials or media bytes are retained. All output stays
inside lane3. This script does not build, install, mutate Git, change settings,
clear data, force-stop, reboot, or provision Device Owner.
"""
from __future__ import annotations

import argparse
import html
import io
import json
import math
import os
import re
import shlex
import subprocess
import time
from dataclasses import dataclass
from datetime import datetime
from pathlib import Path
from typing import Callable
from xml.etree import ElementTree as ET

from PIL import Image, ImageOps

ROOT = Path(r"D:\parentcontrol_app").resolve()
LANE3 = (ROOT / "docs/testing/pdf_based_complete_functional_audit/evidence/lane3").resolve()
PACKAGE = "com.parentcontrol.parent_control"
PARENT = "emulator-5554"
CHILD = "5HXWRGQ4IFU8WS4T"
CWD = str(ROOT)

SAFE_PREFIXES = (
    "Back", "Refresh", "Refresh requests", "Home", "Requests", "Review requests",
    "Waiting for you", "Rules", "Settings", "Devices", "Open device", "Device revoked", "Device identity",
    "Device permissions", "No devices linked", "This phone is no longer linked", "Remote assistance", "Request audio",
    "Request video", "Request failed", "Assistance with explicit consent", "Audio and video come from",
    "Recent sessions", "Tap to open", "Video assistance", "Audio assistance", "Active",
    "Waiting for consent", "Waiting for the child", "The child device is not sending video",
    "Waiting for the child’s video", "Child consent", "Recorded", "Accepted", "Session duration",
    "Requested", "Elapsed", "Relay not configured", "No TURN relay", "Request video assistance?",
    "Request audio assistance?", "Sending this request", "Send request", "Cancel", "Cancel request",
    "Assistance session", "This phone's camera", "This app does not record", "This app never records",
    "You accepted this request", "Ready when you are", "Join with camera and microphone",
    "Join with microphone", "Accept", "Decline", "Review and respond", "Linking requests",
    "Assistance requests", "A parent is asking", "Camera and microphone stay off",
    "Accept this assistance request?", "Accepting records your consent", "Start the live session?",
    "Your camera and microphone will be used", "Your microphone will be used", "Join now",
    "Stop sharing", "This turns off your camera", "The session stays open", "Media connected",
    "Connecting media", "Video live", "Video connecting", "Camera and microphone are live",
    "Camera and microphone live", "Camera and microphone are on", "Camera and microphone starting",
    "Camera and microphone off", "Starting the camera", "Session ended", "Request ended",
    "This session is over", "No camera or microphone", "End", "End session", "Ending stops video",
    "Ending stops audio", "End assistance session?", "This stops audio playback", "Safety alerts",
    "Listen to audio", "One-way audio live", "Listening to the child device", "Audio unavailable",
    "Connecting to the child device", "Checking audio", "Video not live", "Audio not live",
    "The child accepted", "You will view the child device", "You will listen to the child device",
    "Your microphone will not be used", "The server has not confirmed", "Retry", "Leave anyway",
    "Microphone is live", "Microphone is on", "Microphone live", "Microphone off", "Starting the microphone",
    "Starting the microphone", "Connected, but the microphone", "Connected, but the camera", "DEBUG RTP",
    "Allow", "While using the app", "Only this time", "Don't allow", "Start now",
)


def now() -> str:
    return datetime.now().astimezone().isoformat(timespec="seconds")


def sanitize(text: str) -> str:
    text = html.unescape(text)
    text = re.sub(r"[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Za-z]{2,}", "[REDACTED_EMAIL]", text)
    text = re.sub(r"\beyJ[A-Za-z0-9_-]+\.[A-Za-z0-9_-]+\.[A-Za-z0-9_-]+\b", "[REDACTED_TOKEN]", text)
    text = re.sub(r"\b[A-Fa-f0-9]{32,}\b", "[REDACTED_HEX]", text)
    text = re.sub(r"\b[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}\b", "[REDACTED_UUID]", text)
    text = re.sub(r"(?i)\b(lat(?:itude)?|lng|longitude)\b['\"]?\s*[:=]\s*['\"]?-?\d+(?:\.\d+)?", r"\1=[REDACTED_COORD]", text)
    text = re.sub(r"-?\d{1,3}\.\d{4,}\s*,\s*-?\d{1,3}\.\d{4,}", "[REDACTED_COORD]", text)
    text = re.sub(
        r"(?i)\b(authorization|x-device-secret|apikey|api[_-]?key|access[_-]?token|refresh[_-]?token|device[_-]?secret|password|secret)\b['\"]?\s*[:=]\s*['\"]?[^,\s;\"'}]+",
        r"\1=[REDACTED_SECRET]", text,
    )
    text = re.sub(r"(?i)(https?://[^\s?]+)\?[^\s\"']+", r"\1?[REDACTED_QUERY]", text)
    text = re.sub(r"\b(?:\d{1,3}\.){3}\d{1,3}\b", "[REDACTED_IP]", text)
    text = re.sub(r"(Device .*? Child )\S+", r"\1[REDACTED_NAME]", text)
    return text


def clean(value: str) -> str:
    return re.sub(r"\s+", " ", html.unescape(value)).strip()


def safe_ui(value: str) -> bool:
    value = clean(value)
    return bool(value) and value.startswith(SAFE_PREFIXES)


@dataclass
class Node:
    text: str
    desc: str
    cls: str
    bounds: str
    clickable: str

    @property
    def label(self) -> str:
        return clean(self.desc or self.text)


@dataclass
class CommandResult:
    rc: int
    stdout: str
    retained: str
    duration: float
    start: str
    end: str


class Audit:
    def __init__(self, test_id: str, title: str):
        self.test_id = test_id
        self.title = title
        self.started = now()
        self.monotonic = time.monotonic()
        self.log_path = LANE3 / f"{test_id}_commands.log"
        self.lines: list[str] = [f"test_id={test_id}", f"title={title}", f"start={self.started}", f"cwd={CWD}"]
        self.own_session_started = False
        self.summary: dict = {"test_id": test_id, "start": self.started}

    def run(
        self,
        args: list[str],
        note: str = "",
        timeout: int = 45,
        selector: Callable[[str], str] | None = None,
        retain_raw: bool = False,
    ) -> CommandResult:
        start = now()
        monotonic = time.monotonic()
        env = {**os.environ, "MSYS_NO_PATHCONV": "1"}
        try:
            proc = subprocess.run(args, cwd=CWD, capture_output=True, timeout=timeout, env=env, check=False)
            rc, out_b, err_b = proc.returncode, proc.stdout, proc.stderr
        except subprocess.TimeoutExpired as exc:
            rc = 124
            out_b = exc.stdout or b""
            err_b = (exc.stderr or b"") + f"\nTIMEOUT after {timeout}s\n".encode()
        duration = time.monotonic() - monotonic
        end = now()
        stdout = out_b.decode("utf-8", errors="replace")
        stderr = err_b.decode("utf-8", errors="replace")
        if selector is not None:
            retained = selector(stdout)
        elif retain_raw:
            retained = stdout
        else:
            retained = ""
        retained = sanitize(retained).strip()
        clean_stderr = sanitize(stderr).strip()
        self.lines.extend([
            f"[{start}] command={shlex.join(args)}",
            f"[{start}] note={note or 'command'}",
            f"[{start}] cwd={CWD}",
            f"[{start}] exit={rc}",
            f"[{start}] duration_s={duration:.3f}",
            f"[{start}] raw_stdout_lines={len(stdout.splitlines())} raw_stderr_lines={len(stderr.splitlines())}",
            f"[{start}] retained_stdout_lines={len(retained.splitlines())}",
        ])
        if retained:
            self.lines.append("--- retained stdout ---\n" + retained)
        if clean_stderr:
            self.lines.append("--- retained stderr ---\n" + clean_stderr)
        return CommandResult(rc, stdout, retained, duration, start, end)

    def adb(self, serial: str, args: list[str], note: str = "", **kwargs) -> CommandResult:
        return self.run(["adb", "-s", serial, *args], note=note, **kwargs)

    def logcat(self, serial: str, label: str) -> Path:
        result = self.adb(serial, ["logcat", "-d", "-v", "time", "-t", "4000"],
                          f"Read recent sanitized logcat for {label}", retain_raw=False)
        needles = (
            "remote-session", "remote_session", "RemoteSession", "assistance",
            "AppException", "PostgrestException", "DioException", "SocketException",
            "requestSession", "EdgeApi", "E/flutter",
        )
        rows = [sanitize(line) for line in result.stdout.splitlines()
                if any(needle.lower() in line.lower() for needle in needles)]
        rows = rows[-250:]
        path = LANE3 / f"{self.test_id}_{'parent' if serial == PARENT else 'child'}_{label}_logcat.txt"
        path.write_text(
            f"test_id={self.test_id}\nlabel={label}\nserial={serial}\ncwd={CWD}\n"
            f"command_exit={result.rc}\nraw_stdout_lines={len(result.stdout.splitlines())}\n"
            f"retained_stdout_lines={len(rows)}\nretention=sanitized matching lines only\n"
            + "\n".join(rows) + "\n",
            encoding="utf-8", newline="\n",
        )
        self.lines.append(f"logcat_evidence={path} retained_stdout_lines={len(rows)}")
        return path

    def ui(self, serial: str, label: str) -> tuple[list[Node], str, Path]:
        safe_label = re.sub(r"[^A-Za-z0-9_.-]", "_", label)
        remote = f"/data/local/tmp/haven_lane3_{self.test_id}_{safe_label}.xml"
        dumped = self.adb(serial, ["shell", "uiautomator", "dump", remote], f"UI dump {label}", timeout=60,
                          selector=lambda s: "\n".join(line for line in s.splitlines() if "dumped to" in line or "ERROR" in line))
        read = self.adb(serial, ["exec-out", "cat", remote], f"Read UI XML {label}; raw XML not retained", retain_raw=False)
        self.adb(serial, ["shell", "rm", "-f", remote], f"Remove own temporary UI artifact {label}")
        xml = read.stdout
        nodes: list[Node] = []
        try:
            root = ET.fromstring(xml)
            for item in root.iter("node"):
                nodes.append(Node(
                    clean(item.attrib.get("text", "")), clean(item.attrib.get("content-desc", "")),
                    item.attrib.get("class", ""), item.attrib.get("bounds", ""), item.attrib.get("clickable", ""),
                ))
        except ET.ParseError:
            self.lines.append(f"ui_parse_error={label}")
        evidence = LANE3 / f"{self.test_id}_{'parent' if serial == PARENT else 'child'}_{safe_label}.ui.txt"
        rows = [
            f"test_id={self.test_id}", f"label={label}", f"start={dumped.start}", f"end={read.end}",
            f"serial={serial}", f"cwd={CWD}", f"dump_exit={dumped.rc}", f"read_exit={read.rc}",
            f"node_count={len(nodes)}", "retention=whitelisted visible labels and bounds only; raw XML not retained",
        ]
        for index, node in enumerate(nodes):
            if safe_ui(node.label):
                rows.append(f"{index}|label={sanitize(node.label)}|class={node.cls}|clickable={node.clickable}|bounds={node.bounds}")
        evidence.write_text("\n".join(rows) + "\n", encoding="utf-8", newline="\n")
        self.lines.append(f"evidence={evidence} retained_ui_strings={sum(safe_ui(n.label) for n in nodes)}")
        if dumped.rc or read.rc:
            raise RuntimeError(f"UI capture failed for {serial} {label}")
        return nodes, xml, evidence

    def activity(self, serial: str, label: str) -> dict:
        result = self.adb(serial, ["shell", "dumpsys", "activity", "activities"], label,
                          selector=lambda s: "\n".join(
                              line for line in s.splitlines()
                              if re.search(r"mResumedActivity|topResumedActivity|mFocusedActivity", line)
                          ))
        components = re.findall(r"([A-Za-z0-9_.$]+/[A-Za-z0-9_.$]+)", result.retained)
        components = list(dict.fromkeys(components))
        foreground = any(component.startswith(PACKAGE + "/") for component in components)
        state = {"foreground": foreground, "components": components, "exit": result.rc}
        self.lines.append(f"{label} activity_summary foreground_app={str(foreground).lower()} components={','.join(components) or 'unknown'}")
        return state

    def native(self, serial: str, label: str) -> dict:
        services = self.adb(serial, ["shell", "dumpsys", "activity", "services", PACKAGE], f"{label} services")
        service_names = [name for name in ("GuardianService", "LocationTrackingService", "AudioAssistanceService") if name in services.stdout]
        foreground_ids = sorted(set(re.findall(r"foregroundId=(\d+)", services.stdout)))
        camera = self.adb(serial, ["shell", "dumpsys", "media.camera"], f"{label} camera")
        open_devices: list[str] = []
        active_tail = camera.stdout.split("Active Camera Clients:", 1)[-1]
        cut_points = [active_tail.find(marker) for marker in ("Allowed user IDs:", "== Camera device", "Camera service events log") if marker in active_tail]
        active_clients = active_tail[:min(cut_points)] if cut_points else active_tail
        if PACKAGE in active_clients:
            found = re.search(r"Camera ID:\s*(\d+)", active_clients)
            open_devices.append(found.group(1) if found else "unknown")
        open_devices = sorted(set(open_devices), key=lambda value: int(value) if value.isdigit() else -1)
        audio = self.adb(serial, ["shell", "dumpsys", "audio"], f"{label} audio")
        blocks = re.findall(rf"- Package: {re.escape(PACKAGE)}(.*?)(?=\n  - Package:|\Z)", audio.stdout, flags=re.S)
        recording = any(re.search(r"Recording active:\s*true", block) for block in blocks)
        playback = any(re.search(r"Playback active:\s*true", block) for block in blocks)
        events = [line for line in audio.stdout.splitlines() if re.search(rf"rec (?:update|stop).*pack:{re.escape(PACKAGE)}", line)]
        latest = "none"
        if events:
            latest = "update" if "rec update" in events[-1] else "stop"
        mic = self.adb(serial, ["shell", "cmd", "appops", "get", PACKAGE, "RECORD_AUDIO"], f"{label} microphone appop")
        cam = self.adb(serial, ["shell", "cmd", "appops", "get", PACKAGE, "CAMERA"], f"{label} camera appop")
        mic_mode = next((line.strip().split(";")[0] for line in mic.stdout.splitlines() if line.strip().startswith("RECORD_AUDIO:")), "unknown")
        cam_mode = next((line.strip().split(";")[0] for line in cam.stdout.splitlines() if line.strip().startswith("CAMERA:")), "unknown")
        network = self.adb(serial, ["shell", "dumpsys", "connectivity"], f"{label} network")
        default = re.search(r"Active default network:\s*(\d+)", network.stdout)
        network_id = default.group(1) if default else None
        network_summary = "unknown"
        if network_id:
            match = re.search(rf"NetworkAgentInfo\{{(?:network\{{)?{re.escape(network_id)}\b.*?(?=\n\s*NetworkAgentInfo\{{|\Z)", network.stdout, flags=re.S)
            if match:
                block = match.group(0)
                capabilities_match = re.search(r"nc\{\s*\[\s*Transports:\s*([A-Z_]+)\s+Capabilities:\s*([^\s]+)", block)
                if capabilities_match:
                    transport = capabilities_match.group(1)
                    caps = [name for name in ("INTERNET", "VALIDATED", "NOT_RESTRICTED", "TRUSTED", "NOT_VPN") if name in capabilities_match.group(2).split("&")]
                    network_summary = f"id={network_id};transport={transport};capabilities={','.join(caps) or 'unknown'}"
        state = {
            "services": service_names, "foreground_ids": foreground_ids, "camera_devices": open_devices,
            "recording": recording, "playback": playback, "latest_recording": latest,
            "microphone_mode": mic_mode, "camera_mode": cam_mode, "network": network_summary,
            "exits": [services.rc, camera.rc, audio.rc, mic.rc, cam.rc, network.rc],
        }
        self.lines.append(
            f"{label} native_summary services={','.join(service_names) or 'none'};foreground_ids={','.join(foreground_ids) or 'none'};"
            f"camera_open_devices={','.join(open_devices) or 'none'};recording_active={str(recording).lower()};"
            f"latest_recording_event={latest};playback_active={str(playback).lower()};microphone_mode={mic_mode};"
            f"camera_mode={cam_mode};network={network_summary}"
        )
        return state

    def privacy_notification(self, label: str) -> dict:
        result = self.adb(CHILD, ["shell", "dumpsys", "notification"], label, timeout=60)
        title = "Audio assistance active" in result.stdout
        text = "Your microphone is being shared with your parent." in result.stdout
        stop = bool(re.search(r"Stop", result.stdout)) and PACKAGE in result.stdout
        state = {"title": title, "text": text, "stop_action_present": stop}
        self.lines.append(f"{label} notification_summary title={str(title).lower()} text={str(text).lower()} stop_action_present={str(stop).lower()}")
        return state

    def device(self, serial: str, role: str) -> dict:
        props = {}
        for key in ("ro.product.model", "ro.build.version.release", "ro.build.version.sdk", "ro.build.version.security_patch", "persist.sys.timezone"):
            result = self.adb(serial, ["shell", "getprop", key], f"{role} {key}", retain_raw=True)
            props[key] = result.stdout.strip()
        date = self.adb(serial, ["shell", "date", "+%Y-%m-%dT%H:%M:%S%z"], f"{role} device time", retain_raw=True)
        package = self.adb(serial, ["shell", "dumpsys", "package", PACKAGE], f"{role} package version")
        version_name = re.search(r"versionName=([^\s]+)", package.stdout)
        version_code = re.search(r"versionCode=(\d+)", package.stdout)
        size = self.adb(serial, ["shell", "wm", "size"], f"{role} display size", retain_raw=True)
        density = self.adb(serial, ["shell", "wm", "density"], f"{role} display density", retain_raw=True)
        state = {
            "role": role, "serial": serial, "model": props["ro.product.model"],
            "android_release": props["ro.build.version.release"], "sdk": props["ro.build.version.sdk"],
            "security_patch": props["ro.build.version.security_patch"], "timezone": props["persist.sys.timezone"],
            "device_time": date.stdout.strip(), "version_name": version_name.group(1) if version_name else "unknown",
            "version_code": version_code.group(1) if version_code else "unknown",
            "display_size": size.stdout.strip(), "display_density": density.stdout.strip(),
        }
        self.lines.append(f"{role} identity=" + json.dumps(state, sort_keys=True))
        return state

    def baseline(self, label: str) -> dict:
        devices = self.adb(PARENT, ["devices", "-l"], "Connected ADB devices", retain_raw=True)
        self.lines.append("adb_devices=" + sanitize(devices.stdout.strip()).replace("\n", ";"))
        parent_device = self.device(PARENT, "parent")
        child_device = self.device(CHILD, "child")
        parent_activity = self.activity(PARENT, f"{label}_parent_activity")
        child_activity = self.activity(CHILD, f"{label}_child_activity")
        parent_native = self.native(PARENT, f"{label}_parent")
        child_native = self.native(CHILD, f"{label}_child")
        state = {
            "parent_device": parent_device, "child_device": child_device,
            "parent_activity": parent_activity, "child_activity": child_activity,
            "parent_native": parent_native, "child_native": child_native,
        }
        self.summary["baseline"] = state
        return state

    def finish(self, extra: dict | None = None, status: str = "COLLECTED") -> None:
        if extra:
            self.summary.update(extra)
        self.summary["status"] = status
        self.summary["end"] = now()
        self.summary["duration_seconds"] = round(time.monotonic() - self.monotonic, 3)
        self.lines.append(f"end={self.summary['end']}")
        self.lines.append(f"total_duration_s={self.summary['duration_seconds']:.3f}")
        self.lines.append("collection_status=" + status)
        self.log_path.write_text("\n".join(self.lines) + "\n", encoding="utf-8", newline="\n")
        summary_path = LANE3 / f"{self.test_id}_summary.json"
        summary_path.write_text(sanitize(json.dumps(self.summary, indent=2, ensure_ascii=False)) + "\n", encoding="utf-8", newline="\n")
        print(json.dumps({"test_id": self.test_id, "status": status, "log": str(self.log_path), "summary": str(summary_path)}))


def point(node: Node) -> tuple[int, int]:
    found = re.fullmatch(r"\[(\d+),(\d+)\]\[(\d+),(\d+)\]", node.bounds)
    if not found:
        raise RuntimeError(f"No bounds for {node.label}")
    x1, y1, x2, y2 = map(int, found.groups())
    return (x1 + x2) // 2, (y1 + y2) // 2


def find_node(nodes: list[Node], label: str) -> Node | None:
    for node in nodes:
        value = node.label
        if value == label or re.fullmatch(rf"{re.escape(label)} Tab \d of \d", value):
            return node
    return None


def has(nodes: list[Node], label: str) -> bool:
    return find_node(nodes, label) is not None


def has_prefix(nodes: list[Node], label: str) -> bool:
    return any(node.label.startswith(label) for node in nodes)


def labels(nodes: list[Node]) -> list[str]:
    return list(dict.fromkeys(node.label for node in nodes if node.label))


def tap(audit: Audit, serial: str, nodes: list[Node], label: str, note: str) -> None:
    node = find_node(nodes, label)
    if not node:
        raise RuntimeError(f"Visible control not found on {serial}: {label}")
    x, y = point(node)
    audit.adb(serial, ["shell", "input", "tap", str(x), str(y)], note)


def scroll(audit: Audit, serial: str, nodes: list[Node], label: str, prefix: str, direction: str = "down") -> list[Node]:
    if find_node(nodes, label) or has_prefix(nodes, label):
        return nodes
    gesture = ["540", "1900", "540", "550"] if direction == "down" else ["540", "550", "540", "1900"]
    for index in range(5):
        audit.adb(serial, ["shell", "input", "swipe", *gesture], f"Scroll {direction} toward {label} {index + 1}")
        time.sleep(0.7)
        nodes, _, _ = audit.ui(serial, f"{prefix}_{index + 1}")
        if find_node(nodes, label) or has_prefix(nodes, label):
            return nodes
    return nodes


def detect_os_prompt(audit: Audit, serial: str, nodes: list[Node], label: str) -> None:
    prompt_labels = [value for value in labels(nodes) if value in ("Allow", "While using the app", "Only this time", "Don't allow", "Start now")]
    if prompt_labels:
        audit.summary.setdefault("os_prompts", []).append({"serial": serial, "label": label, "visible": prompt_labels})
        raise RuntimeError(f"Android consent prompt visible; not bypassed: {prompt_labels}")


def home_child(audit: Audit, label: str) -> dict:
    audit.adb(CHILD, ["shell", "input", "keyevent", "KEYCODE_HOME"], f"Keep Child UI in Launcher/background: {label}")
    time.sleep(1.2)
    return audit.activity(CHILD, label)


def open_child(audit: Audit, label: str) -> None:
    audit.adb(CHILD, ["shell", "am", "start", "-n", f"{PACKAGE}/.MainActivity"], f"Manually reopen existing Child app: {label}")
    time.sleep(2)
    audit.activity(CHILD, f"{label}_activity")


def open_parent(audit: Audit, label: str) -> None:
    audit.adb(PARENT, ["shell", "am", "start", "-n", f"{PACKAGE}/.MainActivity"], f"Open existing Parent app if needed: {label}")
    time.sleep(1.5)


def open_remote_assistance(audit: Audit, prefix: str) -> list[Node]:
    nodes, _, _ = audit.ui(PARENT, f"{prefix}_parent_current")
    for index in range(2):
        if has_prefix(nodes, "Session ended") or has_prefix(nodes, "Request ended"):
            tap(audit, PARENT, nodes, "Back", "Leave terminal session screen")
            time.sleep(1)
            nodes, _, _ = audit.ui(PARENT, f"{prefix}_after_terminal_{index + 1}")
        else:
            break
    if has(nodes, "Safety alerts"):
        tap(audit, PARENT, nodes, "Back", "Return from Safety alerts")
        time.sleep(1)
        nodes, _, _ = audit.ui(PARENT, f"{prefix}_after_alerts")
    if not has(nodes, "Remote assistance") and has(nodes, "Devices"):
        tap(audit, PARENT, nodes, "Devices", "Open Parent Devices tab")
        time.sleep(1.5)
        nodes, _, _ = audit.ui(PARENT, f"{prefix}_parent_devices")
    if not has(nodes, "Remote assistance") and has(nodes, "Open device"):
        tap(audit, PARENT, nodes, "Open device", "Open existing linked Child device")
        time.sleep(1.5)
        nodes, _, _ = audit.ui(PARENT, f"{prefix}_parent_device_detail")
    if not has(nodes, "Remote assistance"):
        nodes = scroll(audit, PARENT, nodes, "Remote assistance", f"{prefix}_entry_scroll", direction="down")
        tap(audit, PARENT, nodes, "Remote assistance", "Open Remote assistance")
        time.sleep(2)
        nodes, _, _ = audit.ui(PARENT, f"{prefix}_remote_assistance")
    if has_prefix(nodes, "Cancel request") or has_prefix(nodes, "End session") or has(nodes, "End"):
        raise RuntimeError("Existing open assistance session/request visible; test not started")
    if any(
        node.label.startswith(("Video assistance", "Audio assistance"))
        and re.search(r"\b(Active|Waiting for consent|Accepted)\b", node.label)
        for node in nodes
    ):
        raise RuntimeError("Existing open assistance session card visible; test not started")
    return nodes


def clean_native(state: dict) -> bool:
    return not state["camera_devices"] and not state["recording"] and "AudioAssistanceService" not in state["services"]


def start_request(audit: Audit, kind: str, prefix: str, background_child: bool = True) -> None:
    parent_nodes = open_remote_assistance(audit, prefix)
    child_nodes, _, _ = audit.ui(CHILD, f"{prefix}_child_before_background")
    if has(child_nodes, "Stop sharing") or has(child_nodes, "Camera and microphone are live"):
        raise RuntimeError("Child capture UI already active; test not started")
    if background_child:
        child_state = home_child(audit, f"{prefix}_child_background_before_request")
        if child_state["foreground"]:
            raise RuntimeError("Child app remained foreground after Home")
    else:
        child_state = audit.activity(CHILD, f"{prefix}_child_foreground_before_request")
        if not child_state["foreground"]:
            raise RuntimeError("Child app was not foreground for diagnostic request")
    audit.summary["child_foreground_before_request"] = child_state["foreground"]
    request_label = "Request video" if kind == "video" else "Request audio"
    parent_nodes = scroll(audit, PARENT, parent_nodes, request_label, f"{prefix}_request_scroll")
    tap(audit, PARENT, parent_nodes, request_label, f"Initiate {kind} assistance from Parent while Child UI is backgrounded")
    time.sleep(0.8)
    confirm, _, _ = audit.ui(PARENT, f"{prefix}_request_confirmation")
    detect_os_prompt(audit, PARENT, confirm, "parent_request_confirmation")
    if not has(confirm, "Send request"):
        raise RuntimeError("Parent request confirmation not visible")
    tap(audit, PARENT, confirm, "Send request", "Confirm Parent request; no Child media may open yet")
    audit.own_session_started = True
    time.sleep(1.5)
    waiting = []
    for index in range(10):
        waiting, _, _ = audit.ui(PARENT, f"{prefix}_parent_waiting" if index == 0 else f"{prefix}_parent_waiting_poll_{index + 1:02d}")
        if has_prefix(waiting, "Cancel request"):
            break
        if has_prefix(waiting, "Request failed"):
            audit.logcat(PARENT, f"{prefix}_request_failed")
            audit.logcat(CHILD, f"{prefix}_request_failed")
            raise RuntimeError("Parent displayed Request failed before Child consent")
        time.sleep(2)
    if not has_prefix(waiting, "Cancel request"):
        audit.logcat(PARENT, f"{prefix}_request_not_waiting")
        audit.logcat(CHILD, f"{prefix}_request_not_waiting")
        raise RuntimeError("Parent did not enter Waiting for consent state")
    time.sleep(25)
    after_wait_activity = audit.activity(CHILD, f"{prefix}_child_background_after_25s")
    audit.ui(CHILD, f"{prefix}_child_launcher_after_25s")
    after_wait_native = audit.native(CHILD, f"{prefix}_child_after_request_before_reopen")
    audit.summary["background_request_observation"] = {
        "child_foreground_after_25s": after_wait_activity["foreground"],
        "child_camera_open_before_reopen": bool(after_wait_native["camera_devices"]),
        "child_recording_before_reopen": after_wait_native["recording"],
        "manual_reopen_performed": True,
    }
    open_child(audit, f"{prefix}_child_reopen")


def child_consent_and_join(audit: Audit, kind: str, prefix: str) -> None:
    nodes, _, _ = audit.ui(CHILD, f"{prefix}_child_requests_entry")
    if has(nodes, "Review requests"):
        tap(audit, CHILD, nodes, "Review requests", "Open pending assistance request after manual reopen")
    else:
        tap(audit, CHILD, nodes, "Requests", "Open Child Requests tab")
    time.sleep(1)
    nodes, _, _ = audit.ui(CHILD, f"{prefix}_child_requests_tab")
    if not has(nodes, "Review and respond") and not has(nodes, "Accept"):
        tap(audit, CHILD, nodes, "Refresh requests", "Refresh Child requests")
        time.sleep(3)
        nodes, _, _ = audit.ui(CHILD, f"{prefix}_child_requests_refreshed")
    if has(nodes, "Review and respond"):
        tap(audit, CHILD, nodes, "Review and respond", "Review Parent request")
        time.sleep(1)
        nodes, _, _ = audit.ui(CHILD, f"{prefix}_child_request_detail")
    nodes = scroll(audit, CHILD, nodes, "Accept", f"{prefix}_accept_scroll")
    tap(audit, CHILD, nodes, "Accept request" if has(nodes, "Accept request") else "Accept", "Open explicit Child Accept confirmation")
    time.sleep(0.8)
    confirm, _, _ = audit.ui(CHILD, f"{prefix}_child_accept_confirmation")
    detect_os_prompt(audit, CHILD, confirm, "child_accept_confirmation")
    tap(audit, CHILD, confirm, "Accept request" if has(confirm, "Accept request") else "Accept", "Record explicit Child consent; media must remain off before Join")
    time.sleep(1.5)
    before_join = audit.native(CHILD, f"{prefix}_child_after_accept_before_join")
    audit.summary["after_accept_before_join"] = before_join
    nodes, _, _ = audit.ui(CHILD, f"{prefix}_child_join_card")
    join_label = "Join with camera and microphone" if kind == "video" else "Join with microphone"
    nodes = scroll(audit, CHILD, nodes, join_label, f"{prefix}_join_scroll")
    tap(audit, CHILD, nodes, join_label, "Open explicit Child Join confirmation")
    time.sleep(0.8)
    confirm, _, _ = audit.ui(CHILD, f"{prefix}_child_join_confirmation")
    detect_os_prompt(audit, CHILD, confirm, "child_join_confirmation")
    tap(audit, CHILD, confirm, "Join now", "Explicitly Join and authorize Child capture")
    time.sleep(4)


def parent_join(audit: Audit, kind: str, prefix: str) -> str:
    start_label = "Start video session" if kind == "video" else "Listen to audio"
    mode = "unknown"
    for index in range(15):
        nodes, _, _ = audit.ui(PARENT, f"{prefix}_parent_join_poll_{index + 1:02d}")
        detect_os_prompt(audit, PARENT, nodes, "parent_join")
        if has(nodes, start_label):
            mode = "explicit_parent_join"
            tap(audit, PARENT, nodes, start_label, "Join as receive-only Parent")
            time.sleep(0.8)
            confirm, _, _ = audit.ui(PARENT, f"{prefix}_parent_join_confirmation")
            detect_os_prompt(audit, PARENT, confirm, "parent_join_confirmation")
            tap(audit, PARENT, confirm, "Join now", "Confirm receive-only Parent Join")
            break
        values = labels(nodes)
        if any(value.startswith("Media connected") for value in values) or any("live" in value.lower() for value in values):
            mode = "automatic_receive_only_parent_join"
            break
        time.sleep(2)
    audit.summary["parent_join_mode"] = mode
    if mode == "unknown":
        raise RuntimeError("Parent neither exposed Join nor connected automatically")
    return mode


def rtp(nodes: list[Node]) -> dict | None:
    for node in nodes:
        if node.label.startswith("DEBUG RTP:"):
            found = re.search(r"in (\d+) pkts / (\d+) B · out (\d+) pkts / (\d+) B", node.label)
            if found:
                return {"in_packets": int(found.group(1)), "in_bytes": int(found.group(2)),
                        "out_packets": int(found.group(3)), "out_bytes": int(found.group(4))}
    return None


def video_metrics_binary(audit: Audit, nodes: list[Node], label: str) -> dict:
    start = now()
    monotonic = time.monotonic()
    args = ["adb", "-s", PARENT, "exec-out", "screencap", "-p"]
    try:
        proc = subprocess.run(args, cwd=CWD, capture_output=True, timeout=60,
                              env={**os.environ, "MSYS_NO_PATHCONV": "1"}, check=False)
        rc, data, err = proc.returncode, proc.stdout, proc.stderr
    except subprocess.TimeoutExpired as exc:
        rc, data, err = 124, exc.stdout or b"", (exc.stderr or b"") + b"\nTIMEOUT after 60s\n"
    duration = time.monotonic() - monotonic
    audit.lines.extend([
        f"[{start}] command={shlex.join(args)}", f"[{start}] note={label}; in-memory pixel metrics only; image bytes discarded",
        f"[{start}] cwd={CWD}", f"[{start}] exit={rc}", f"[{start}] duration_s={duration:.3f}",
        f"[{start}] raw_stdout_bytes={len(data)} retained_media_bytes=0",
    ])
    if err:
        audit.lines.append("--- retained stderr ---\n" + sanitize(err.decode("utf-8", errors="replace")).strip())
    if rc:
        raise RuntimeError("Parent screencap failed")
    with Image.open(io.BytesIO(data)) as source:
        image = source.convert("RGB")
    width, height = image.size
    anchor = find_node(nodes, "Video live") or find_node(nodes, "End session")
    if not anchor:
        raise RuntimeError("Cannot derive video region without Video live or End session bounds")
    found = re.fullmatch(r"\[(\d+),(\d+)\]\[(\d+),(\d+)\]", anchor.bounds)
    if not found:
        raise RuntimeError("Invalid End control bounds")
    anchor_top = int(found.group(2))
    left, right = 48, width - 48
    region_height = int((right - left) * 9 / 16)
    bottom = max(180, anchor_top - 24)
    top = max(180, bottom - region_height)
    bottom = min(height - 32, top + region_height)
    if bottom <= top:
        raise RuntimeError("Invalid video region")
    gray = ImageOps.grayscale(image.crop((left, top, right, bottom)))
    sampled = list(gray.resize((160, 90)).getdata())
    mean = sum(sampled) / len(sampled)
    stddev = math.sqrt(sum((value - mean) ** 2 for value in sampled) / len(sampled))
    bright = sum(value > 80 for value in sampled) / len(sampled)
    signature = list(gray.resize((64, 36)).getdata())
    metrics = {"width": width, "height": height, "region": [left, top, right, bottom],
               "mean_luma": round(mean, 3), "stddev_luma": round(stddev, 3),
               "bright_fraction": round(bright, 4), "signature": signature}
    audit.lines.append(f"{label} pixel_summary dimensions={width}x{height};region={left},{top},{right},{bottom};"
                       f"mean_luma={mean:.3f};stddev_luma={stddev:.3f};bright_fraction={bright:.4f};retained_media_bytes=0")
    return metrics


def live_samples(audit: Audit, kind: str, prefix: str) -> list[dict]:
    child_ui, _, _ = audit.ui(CHILD, f"{prefix}_child_visible_live_before_background")
    audit.summary["child_visible_live_labels"] = labels(child_ui)
    background = home_child(audit, f"{prefix}_child_background_during_capture")
    if background["foreground"]:
        raise RuntimeError("Child app did not enter background after Join")
    expected_child = "Camera and microphone are live" if kind == "video" else "Microphone is live"
    expected_parent = "Video live" if kind == "video" else "One-way audio live"
    child_ready = False
    for index in range(15):
        child_ui, _, _ = audit.ui(CHILD, f"{prefix}_child_visible_live_poll_{index + 1:02d}")
        if has(child_ui, expected_child):
            child_ready = True
            break
        time.sleep(2)
    if not child_ready:
        raise RuntimeError(f"Child {expected_child} state did not appear")
    ready = False
    for index in range(15):
        parent_nodes, _, _ = audit.ui(PARENT, f"{prefix}_parent_live_poll_{index + 1:02d}")
        values = labels(parent_nodes)
        if has(parent_nodes, "Media connected") and has(parent_nodes, expected_parent):
            ready = True
            break
        time.sleep(2)
    if not ready:
        raise RuntimeError(f"Parent {expected_parent} state did not appear")
    notification = audit.privacy_notification(f"{prefix}_child_privacy_notification")
    samples: list[dict] = []
    previous = None
    for index in range(3):
        parent_nodes, _, _ = audit.ui(PARENT, f"{prefix}_parent_live_{index + 1:02d}")
        child_activity = audit.activity(CHILD, f"{prefix}_child_background_sample_{index + 1:02d}")
        parent_native = audit.native(PARENT, f"{prefix}_parent_native_{index + 1:02d}")
        child_native = audit.native(CHILD, f"{prefix}_child_native_{index + 1:02d}")
        counters = rtp(parent_nodes)
        sample = {
            "parent_media_connected": has(parent_nodes, "Media connected"),
            "parent_live": has(parent_nodes, expected_parent),
            "parent_rtp": counters,
            "parent_camera_open": bool(parent_native["camera_devices"]),
            "parent_recording": parent_native["recording"],
            "parent_playback": parent_native["playback"],
            "child_foreground": child_activity["foreground"],
            "child_camera_open": bool(child_native["camera_devices"]),
            "child_recording": child_native["recording"],
            "child_audio_service": "AudioAssistanceService" in child_native["services"],
            "child_network": child_native["network"],
        }
        if kind == "video":
            frame = video_metrics_binary(audit, parent_nodes, f"{prefix}_parent_frame_{index + 1:02d}")
            delta = None
            if previous is not None:
                delta = sum(abs(a - b) for a, b in zip(previous, frame["signature"])) / len(previous)
            previous = frame["signature"]
            sample["frame"] = {key: value for key, value in frame.items() if key != "signature"}
            sample["frame_delta"] = None if delta is None else round(delta, 3)
            sample["nonblack_varied_frame"] = frame["stddev_luma"] > 15 and frame["bright_fraction"] > 0.10
        samples.append(sample)
        audit.lines.append(f"{prefix}_live_sample_{index + 1:02d}=" + json.dumps(sample, sort_keys=True))
        if index < 2:
            time.sleep(6)
    audit.summary["live_samples"] = samples
    audit.summary["privacy_notification"] = notification
    audit.summary["child_visible_live_marker_present"] = has(child_ui, expected_child)
    return samples


def end_session(audit: Audit, prefix: str) -> dict:
    nodes, _, _ = audit.ui(PARENT, f"{prefix}_parent_before_end")
    if has(nodes, "Cancel request"):
        tap(audit, PARENT, nodes, "Cancel request", "Cancel own request")
        confirm_label = "Cancel request"
    else:
        tap(audit, PARENT, nodes, "End" if has(nodes, "End") else "End session", "Open own end-session confirmation")
        time.sleep(0.8)
        nodes, _, _ = audit.ui(PARENT, f"{prefix}_parent_end_confirmation")
        confirm_label = "End session"
    tap(audit, PARENT, nodes, confirm_label, "Confirm server-owned session teardown")
    ended = False
    for index in range(12):
        time.sleep(2)
        parent_nodes, parent_values = audit.ui(PARENT, f"{prefix}_parent_ended_poll_{index + 1:02d}")
        if has(parent_nodes, "Session ended") or has(parent_nodes, "Request ended"):
            ended = True
            break
    clean_parent = None
    clean_child = None
    for index in range(10):
        parent_state = audit.native(PARENT, f"{prefix}_parent_teardown_poll_{index + 1:02d}")
        child_state = audit.native(CHILD, f"{prefix}_child_teardown_poll_{index + 1:02d}")
        clean_parent = clean_native(parent_state)
        clean_child = clean_native(child_state)
        if clean_parent and clean_child:
            break
        time.sleep(2)
    open_child(audit, f"{prefix}_child_after_end")
    child_ended = False
    for index in range(8):
        child_nodes, _, _ = audit.ui(CHILD, f"{prefix}_child_ended_poll_{index + 1:02d}")
        if has(child_nodes, "Session ended"):
            child_ended = True
            break
        time.sleep(2)
    home_child(audit, f"{prefix}_child_final_background")
    result = {"parent_terminal_ui": ended, "child_terminal_ui": child_ended,
              "parent_capture_clean": clean_parent, "child_capture_clean": clean_child}
    audit.summary["teardown"] = result
    return result


def cleanup(audit: Audit) -> None:
    if not audit.own_session_started:
        return
    audit.lines.append("cleanup=attempt_own_session_only")
    try:
        open_parent(audit, "cleanup")
        nodes, _, _ = audit.ui(PARENT, "cleanup_parent_current")
        if has_prefix(nodes, "Cancel request"):
            tap(audit, PARENT, nodes, "Cancel request", "Cleanup own pending request")
            time.sleep(0.7)
            nodes, _, _ = audit.ui(PARENT, "cleanup_cancel_confirmation")
            tap(audit, PARENT, nodes, "Cancel request", "Confirm cleanup cancellation")
        elif has(nodes, "End"):
            tap(audit, PARENT, nodes, "End", "Cleanup own active session")
            time.sleep(0.7)
            nodes, _, _ = audit.ui(PARENT, "cleanup_end_confirmation")
            tap(audit, PARENT, nodes, "End session", "Confirm cleanup end")
        elif has_prefix(nodes, "End session"):
            tap(audit, PARENT, nodes, "End session", "Cleanup own active session")
            time.sleep(0.7)
            nodes, _, _ = audit.ui(PARENT, "cleanup_end_confirmation")
            tap(audit, PARENT, nodes, "End session", "Confirm cleanup end")
        time.sleep(6)
        audit.native(PARENT, "cleanup_parent")
        audit.native(CHILD, "cleanup_child")
    except Exception as exc:
        audit.lines.append(f"cleanup_error={type(exc).__name__}:{sanitize(str(exc))}")


def execute_media(audit: Audit, kind: str, background_child: bool = True) -> None:
    baseline = audit.baseline("pre")
    if not clean_native(baseline["parent_native"]) or not clean_native(baseline["child_native"]):
        raise RuntimeError("Native baseline not clean; test not started")
    prefix = audit.test_id
    start_request(audit, kind, prefix, background_child=background_child)
    child_consent_and_join(audit, kind, prefix)
    parent_join(audit, kind, prefix)
    samples = live_samples(audit, kind, prefix)
    teardown = end_session(audit, prefix)
    inbound = [sample["parent_rtp"]["in_packets"] for sample in samples if sample["parent_rtp"]]
    outbound = [sample["parent_rtp"]["out_packets"] for sample in samples if sample["parent_rtp"]]
    audit.summary["rtp_in_monotonic"] = len(inbound) == 3 and inbound[0] < inbound[1] < inbound[2]
    audit.summary["parent_out_rtp_zero"] = len(outbound) == 3 and all(value == 0 for value in outbound)
    audit.summary["all_parent_camera_inactive"] = all(not sample["parent_camera_open"] for sample in samples)
    audit.summary["all_parent_microphone_inactive"] = all(not sample["parent_recording"] for sample in samples)
    audit.summary["all_child_background"] = all(not sample["child_foreground"] for sample in samples)
    audit.summary["all_child_capture_active"] = all(sample["child_recording"] and (kind == "audio" or sample["child_camera_open"]) for sample in samples)
    audit.summary["all_parent_media_live"] = all(sample["parent_media_connected"] and sample["parent_live"] and sample["parent_playback"] for sample in samples)
    if kind == "video":
        audit.summary["all_frames_nonblack_varied"] = all(sample["nonblack_varied_frame"] for sample in samples)
        deltas = [sample["frame_delta"] for sample in samples if sample["frame_delta"] is not None]
        audit.summary["frame_deltas"] = deltas
    audit.finish(status="COLLECTED")


def execute_bg05(audit: Audit) -> None:
    baseline = audit.baseline("pre")
    open_child(audit, "BG05_child_privacy_inspection")
    child_nodes, _, _ = audit.ui(CHILD, "BG05_child_before_background")
    if has(child_nodes, "Settings"):
        tap(audit, CHILD, child_nodes, "Settings", "Open Child Settings to inspect privacy copy")
        time.sleep(1)
        child_nodes, _, _ = audit.ui(CHILD, "BG05_child_settings")
        child_nodes = scroll(audit, CHILD, child_nodes, "This app never records", "BG05_child_privacy_scroll", direction="down")
    background = home_child(audit, "BG05_child_background_before_parent")
    parent_nodes = open_remote_assistance(audit, "BG05")
    parent_nodes = scroll(audit, PARENT, parent_nodes, "Request video", "BG05_parent_controls_scroll")
    parent_controls = [node.label for node in parent_nodes if node.clickable == "true"]
    audit.summary["parent_remote_controls"] = [value for value in parent_controls if value in ("Request audio", "Request video")]
    audit.summary["screen_control_labels"] = [
        value for value in parent_controls
        if not value.startswith(("Audio assistance", "Video assistance", "Tap to open"))
        and re.search(r"screen|mirror|cast", value, re.I)
    ]
    audit.summary["child_background_before_check"] = not background["foreground"]
    files = [path for base in (ROOT / "lib", ROOT / "android") for path in base.rglob("*") if path.suffix in (".dart", ".kt", ".xml")]
    patterns = {
        "MediaProjection": re.compile(r"MediaProjection", re.I),
        "VIRTUAL_DISPLAY": re.compile(r"VIRTUAL_DISPLAY", re.I),
        "FOREGROUND_SERVICE_MEDIA_PROJECTION": re.compile(r"FOREGROUND_SERVICE_MEDIA_PROJECTION", re.I),
        "screen mirror/cast/share": re.compile(r"screen[_ -]?(?:mirror|mirroring|cast|share|capture)", re.I),
    }
    scan_rows = [f"test_id=BG05", f"cwd={CWD}", f"scanned_files={len(files)}", "scope=lib/**/*.dart,android/**/*.kt,android/**/*.xml"]
    counts = {}
    for name, pattern in patterns.items():
        matches = []
        for path in files:
            try:
                text = path.read_text(encoding="utf-8", errors="replace")
            except OSError:
                continue
            for number, line in enumerate(text.splitlines(), 1):
                if pattern.search(line):
                    matches.append(f"{path}:{number}:{sanitize(line.strip())[:240]}")
        counts[name] = len(matches)
        scan_rows.append(f"pattern={name} count={len(matches)}")
        scan_rows.extend("match=" + value for value in matches[:20])
    scan_path = LANE3 / "BG05_source_scan.txt"
    scan_path.write_text("\n".join(scan_rows) + "\n", encoding="utf-8", newline="\n")
    audit.lines.append(f"source_scan={scan_path} counts={json.dumps(counts, sort_keys=True)}")
    audit.summary["source_scan_counts"] = counts
    audit.summary["source_scan_path"] = str(scan_path)
    audit.finish(status="COLLECTED")


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("test", choices=("BG03", "BG04", "BG05"))
    args = parser.parse_args()
    titles = {"BG03": "Parent-initiated remote camera with Child UI backgrounded",
              "BG04": "Parent-initiated one-way audio with Child UI backgrounded",
              "BG05": "Screen mirroring capability confirmation"}
    audit = Audit(args.test, titles[args.test])
    try:
        if args.test == "BG05":
            execute_bg05(audit)
        else:
            execute_media(audit, "video" if args.test == "BG03" else "audio")
        return 0
    except Exception as exc:
        audit.summary["error"] = f"{type(exc).__name__}:{sanitize(str(exc))}"
        audit.lines.append(f"error={type(exc).__name__}:{sanitize(str(exc))}")
        cleanup(audit)
        audit.finish(status="COLLECTION_ERROR")
        return 1


if __name__ == "__main__":
    raise SystemExit(main())

#!/usr/bin/env python3
from __future__ import annotations

import argparse
import importlib.util
import json
import sys
import time
from pathlib import Path

ROOT = Path(__file__).resolve().parent
COLLECTOR = ROOT / "lane3_remote_access.py"
SPEC = importlib.util.spec_from_file_location("lane3_remote_access", COLLECTOR)
if SPEC is None or SPEC.loader is None:
    raise RuntimeError("Unable to load lane3_remote_access.py")
REMOTE = importlib.util.module_from_spec(SPEC)
sys.modules[SPEC.name] = REMOTE
SPEC.loader.exec_module(REMOTE)


def has_contains(nodes: list[REMOTE.Node], needle: str) -> bool:
    return any(needle.casefold() in node.label.casefold() for node in nodes)


def wait_for_clean(audit: REMOTE.Audit, started: str, timeout: int = 90) -> dict:
    began = time.monotonic()
    last_parent = None
    last_child = None
    parent_terminal = False
    for index in range(timeout):
        state = audit.adb(REMOTE.CHILD, ["get-state"], "Check Child ADB availability during teardown")
        if state.rc == 0:
            last_parent = audit.native(REMOTE.PARENT, f"{audit.test_id}_teardown_parent_{index + 1:02d}")
            last_child = audit.native(REMOTE.CHILD, f"{audit.test_id}_teardown_child_{index + 1:02d}")
            if REMOTE.clean_native(last_parent) and REMOTE.clean_native(last_child):
                if index % 5 == 0:
                    try:
                        nodes, _, _ = audit.ui(REMOTE.PARENT, f"{audit.test_id}_teardown_ui_{index + 1:02d}")
                        parent_terminal = REMOTE.has_prefix(nodes, "Session ended") or REMOTE.has_prefix(nodes, "Request ended")
                    except RuntimeError:
                        parent_terminal = False
                if parent_terminal or index >= 10:
                    return {
                        "clean": True,
                        "end_confirmed_at": started,
                        "clean_observed_at": REMOTE.now(),
                        "seconds_from_end_confirmation": round(time.monotonic() - began, 3),
                        "parent_terminal_ui": parent_terminal,
                        "parent_native": last_parent,
                        "child_native": last_child,
                    }
        time.sleep(1)
    return {
        "clean": False,
        "end_confirmed_at": started,
        "clean_observed_at": REMOTE.now(),
        "seconds_from_end_confirmation": round(time.monotonic() - began, 3),
        "parent_terminal_ui": parent_terminal,
        "parent_native": last_parent,
        "child_native": last_child,
    }


def end_and_verify(audit: REMOTE.Audit) -> dict:
    nodes, _, _ = audit.ui(REMOTE.PARENT, f"{audit.test_id}_before_end")
    if REMOTE.has_prefix(nodes, "Cancel request"):
        REMOTE.tap(audit, REMOTE.PARENT, nodes, "Cancel request", "Cancel own pending request")
        confirm_label = "Cancel request"
    else:
        REMOTE.tap(audit, REMOTE.PARENT, nodes, "End" if REMOTE.has(nodes, "End") else "End session", "Open own end-session confirmation")
        time.sleep(0.8)
        nodes, _, _ = audit.ui(REMOTE.PARENT, f"{audit.test_id}_end_confirmation")
        confirm_label = "End session"
    REMOTE.tap(audit, REMOTE.PARENT, nodes, confirm_label, "Confirm server-owned session teardown")
    confirmed = REMOTE.now()
    result = wait_for_clean(audit, confirmed)
    audit.summary["teardown"] = result
    return result


def emergency_cleanup(audit: REMOTE.Audit) -> None:
    try:
        REMOTE.open_parent(audit, f"{audit.test_id}_cleanup")
        nodes, _, _ = audit.ui(REMOTE.PARENT, f"{audit.test_id}_cleanup_current")
        if REMOTE.has_prefix(nodes, "Cancel request"):
            REMOTE.tap(audit, REMOTE.PARENT, nodes, "Cancel request", "Cleanup own pending request")
            time.sleep(0.7)
            nodes, _, _ = audit.ui(REMOTE.PARENT, f"{audit.test_id}_cleanup_cancel_confirmation")
            REMOTE.tap(audit, REMOTE.PARENT, nodes, "Cancel request", "Confirm cleanup cancellation")
        elif REMOTE.has(nodes, "End"):
            REMOTE.tap(audit, REMOTE.PARENT, nodes, "End", "Cleanup own active session")
            time.sleep(0.7)
            nodes, _, _ = audit.ui(REMOTE.PARENT, f"{audit.test_id}_cleanup_end_confirmation")
            REMOTE.tap(audit, REMOTE.PARENT, nodes, "End session", "Confirm cleanup end")
        elif REMOTE.has_prefix(nodes, "End session"):
            REMOTE.tap(audit, REMOTE.PARENT, nodes, "End session", "Cleanup own active session")
            time.sleep(0.7)
            nodes, _, _ = audit.ui(REMOTE.PARENT, f"{audit.test_id}_cleanup_end_confirmation")
            REMOTE.tap(audit, REMOTE.PARENT, nodes, "End session", "Confirm cleanup end")
    except Exception as exc:
        audit.lines.append(f"cleanup_ui_error={type(exc).__name__}:{REMOTE.sanitize(str(exc))}")
    if audit.own_session_started:
        result = wait_for_clean(audit, REMOTE.now())
        audit.summary["cleanup_teardown"] = result


def prepare_child_requests(audit: REMOTE.Audit, test_id: str) -> None:
    nodes, _, _ = audit.ui(REMOTE.CHILD, f"{test_id}_child_prepare_entry")
    for index in range(2):
        if REMOTE.has(nodes, "Requests") or REMOTE.has(nodes, "Review requests") or REMOTE.has(nodes, "Refresh status"):
            return
        if REMOTE.has(nodes, "Back"):
            REMOTE.tap(audit, REMOTE.CHILD, nodes, "Back", "Return from terminal assistance screen to Child requests")
            time.sleep(0.8)
            nodes, _, _ = audit.ui(REMOTE.CHILD, f"{test_id}_child_prepare_back_{index + 1}")
            continue
        break


def execute(kind: str, test_id: str) -> None:
    audit = REMOTE.Audit(test_id, f"Explicitly consented {kind} media sampling and teardown")
    try:
        baseline = audit.baseline("pre")
        if not REMOTE.clean_native(baseline["parent_native"]) or not REMOTE.clean_native(baseline["child_native"]):
            raise RuntimeError("Native baseline not clean; test not started")
        prepare_child_requests(audit, test_id)
        REMOTE.start_request(audit, kind, test_id)
        REMOTE.child_consent_and_join(audit, kind, test_id)
        REMOTE.parent_join(audit, kind, test_id)
        child_ui, _, _ = audit.ui(REMOTE.CHILD, f"{test_id}_child_live_visible")
        audit.summary["child_visible_live_labels"] = REMOTE.labels(child_ui)
        audit.summary["privacy_notification"] = audit.privacy_notification(f"{test_id}_privacy_notification")
        background = REMOTE.home_child(audit, f"{test_id}_child_background")
        if background["foreground"]:
            raise RuntimeError("Child app did not enter background after Join")
        expected_child = "Camera and microphone are live" if kind == "video" else "Microphone is live"
        expected_parent = "Video live" if kind == "video" else "One-way audio live"
        if not REMOTE.has_prefix(child_ui, expected_child):
            raise RuntimeError(f"Child live marker absent: {expected_child}")
        samples = []
        previous = None
        for index in range(3):
            parent_nodes, _, _ = audit.ui(REMOTE.PARENT, f"{test_id}_parent_sample_{index + 1:02d}")
            parent_native = audit.native(REMOTE.PARENT, f"{test_id}_parent_native_{index + 1:02d}")
            child_native = audit.native(REMOTE.CHILD, f"{test_id}_child_native_{index + 1:02d}")
            child_activity = audit.activity(REMOTE.CHILD, f"{test_id}_child_activity_{index + 1:02d}")
            sample = {
                "sampled_at": REMOTE.now(),
                "parent_media_connected": REMOTE.has_prefix(parent_nodes, "Media connected"),
                "parent_live": has_contains(parent_nodes, expected_parent),
                "parent_playback": parent_native["playback"],
                "parent_camera_open": bool(parent_native["camera_devices"]),
                "parent_recording": parent_native["recording"],
                "child_foreground": child_activity["foreground"],
                "child_camera_open": bool(child_native["camera_devices"]),
                "child_recording": child_native["recording"],
                "child_audio_service": "AudioAssistanceService" in child_native["services"],
                "parent_rtp": REMOTE.rtp(parent_nodes),
            }
            if kind == "video":
                frame = REMOTE.video_metrics_binary(audit, parent_nodes, f"{test_id}_frame_{index + 1:02d}")
                delta = None if previous is None else sum(abs(a - b) for a, b in zip(previous, frame["signature"])) / len(previous)
                previous = frame["signature"]
                sample["frame"] = {key: value for key, value in frame.items() if key != "signature"}
                sample["frame_delta"] = None if delta is None else round(delta, 3)
                sample["nonblack_varied_frame"] = frame["stddev_luma"] > 15 and frame["bright_fraction"] > 0.10
            samples.append(sample)
            audit.lines.append(f"{test_id}_sample_{index + 1:02d}=" + json.dumps(sample, sort_keys=True))
            if index < 2:
                time.sleep(5)
        audit.summary["live_samples"] = samples
        audit.summary["all_parent_media_live"] = all(sample["parent_media_connected"] and sample["parent_live"] and sample["parent_playback"] for sample in samples)
        audit.summary["all_parent_capture_inactive"] = all(not sample["parent_camera_open"] and not sample["parent_recording"] for sample in samples)
        audit.summary["all_child_background"] = all(not sample["child_foreground"] for sample in samples)
        audit.summary["all_child_capture_active"] = all(sample["child_recording"] and (kind == "audio" or sample["child_camera_open"]) for sample in samples)
        if kind == "video":
            audit.summary["all_frames_nonblack_varied"] = all(sample["nonblack_varied_frame"] for sample in samples)
            audit.summary["frame_deltas"] = [sample["frame_delta"] for sample in samples if sample["frame_delta"] is not None]
        if kind == "video":
            REMOTE.open_child(audit, f"{test_id}_child_stop_sharing")
            stop_ui, _, _ = audit.ui(REMOTE.CHILD, f"{test_id}_child_stop_sharing_ui")
            stop_ui = REMOTE.scroll(audit, REMOTE.CHILD, stop_ui, "Stop sharing", f"{test_id}_stop_sharing_scroll")
            REMOTE.tap(audit, REMOTE.CHILD, stop_ui, "Stop sharing", "Open Child sharing-consent withdrawal confirmation")
            time.sleep(0.8)
            stop_confirm, _, _ = audit.ui(REMOTE.CHILD, f"{test_id}_child_stop_sharing_confirmation")
            REMOTE.tap(audit, REMOTE.CHILD, stop_confirm, "Stop sharing", "Confirm visible Child sharing-consent withdrawal")
            stop_started = time.monotonic()
            stopped_native = None
            for attempt in range(10):
                time.sleep(1)
                stopped_native = audit.native(REMOTE.CHILD, f"{test_id}_child_stopped_{attempt + 1:02d}")
                if not stopped_native["camera_devices"] and not stopped_native["recording"]:
                    break
            audit.summary["child_stop_sharing"] = {
                "clean_after_stop": not stopped_native["camera_devices"] and not stopped_native["recording"],
                "seconds_to_clean": round(time.monotonic() - stop_started, 3),
                "child_native": stopped_native,
            }
        teardown = end_and_verify(audit)
        if not teardown["clean"]:
            raise RuntimeError("Capture did not reach a clean native state after End")
        REMOTE.open_child(audit, f"{test_id}_child_terminal")
        child_terminal, _, _ = audit.ui(REMOTE.CHILD, f"{test_id}_child_terminal_ui")
        audit.summary["child_terminal_labels"] = REMOTE.labels(child_terminal)
        REMOTE.home_child(audit, f"{test_id}_child_final_background")
        audit.finish(status="COLLECTED")
    except Exception as exc:
        audit.summary["error"] = f"{type(exc).__name__}:{REMOTE.sanitize(str(exc))}"
        audit.lines.append("error=" + audit.summary["error"])
        emergency_cleanup(audit)
        audit.finish(status="COLLECTION_ERROR")
        raise


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("kind", choices=("video", "audio"))
    parser.add_argument("test_id")
    args = parser.parse_args()
    execute(args.kind, args.test_id)
    return 0


if __name__ == "__main__":
    raise SystemExit(main())

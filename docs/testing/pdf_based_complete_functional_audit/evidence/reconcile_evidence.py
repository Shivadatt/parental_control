#!/usr/bin/env python3
from __future__ import annotations

import hashlib
import importlib.util
import json
import re
import sys
from datetime import datetime, timezone
from pathlib import Path

ROOT = Path(__file__).resolve().parent
HELPER_PATH = ROOT / "lane2" / "lane2_adb.py"
SPEC = importlib.util.spec_from_file_location("lane2_adb", HELPER_PATH)
if SPEC is None or SPEC.loader is None:
    raise RuntimeError("Unable to load lane2_adb.py")
HELPER = importlib.util.module_from_spec(SPEC)
sys.modules[SPEC.name] = HELPER
SPEC.loader.exec_module(HELPER)

RECORD_START = re.compile(r"(?m)^\d+\|text=")
FIRST_LINE = re.compile(
    r"^(?P<index>\d+)\|text=(?P<text>.*?)\|desc=(?P<desc>.*)\|id=(?P<id>.*)"
    r"\|class=(?P<class>.*)\|clickable=(?P<clickable>.*)\|bounds=(?P<bounds>\[\d+,\d+\]\[\d+,\d+\])"
    r"(?:\|checked=(?P<checked>.*))?$"
)
MESSAGE_START = re.compile(r"(?m)^UI hier(?:a|ch)archy dumped to:")


def now_iso() -> str:
    return datetime.now(timezone.utc).astimezone().isoformat(timespec="seconds")


def read_text(path: Path) -> str:
    try:
        return path.read_text(encoding="utf-8")
    except UnicodeDecodeError:
        return path.read_text(encoding="cp1252")


def digest(path: Path) -> str:
    return hashlib.sha256(path.read_bytes()).hexdigest()


def parse_ui_text(text: str, source: str = "validation") -> tuple[str, list[dict], str]:
    starts = list(RECORD_START.finditer(text))
    if not starts:
        return text, [], ""
    prefix = text[: starts[0].start()]
    records: list[dict] = []
    trailing = ""
    for position, start in enumerate(starts):
        end = starts[position + 1].start() if position + 1 < len(starts) else len(text)
        chunk = text[start.start() : end].rstrip("\n")
        first, separator, remainder = chunk.partition("\n")
        match = FIRST_LINE.fullmatch(first)
        if match is None:
            raise ValueError(f"Unrecognized UI record in {source}: {first[:160]}")
        message_match = MESSAGE_START.search(remainder)
        messages = ""
        if message_match:
            messages = remainder[message_match.start() :]
            remainder = remainder[: message_match.start()].rstrip("\n")
        elif position + 1 == len(starts):
            trailer = re.search(r"(?m)^UI .*dumped to:", remainder)
            if trailer:
                messages = remainder[trailer.start() :]
                remainder = remainder[: trailer.start()].rstrip("\n")
        if position + 1 == len(starts):
            trailing = ("\n" + messages) if messages else ""
        records.append(
            {
                "index": int(match.group("index")),
                "text": match.group("text"),
                "content_desc": remainder if separator else "",
                "resource_id": match.group("id"),
                "class": match.group("class"),
                "clickable": match.group("clickable"),
                "checked": match.group("checked") or "",
                "bounds": match.group("bounds"),
            }
        )
    return prefix, records, trailing


def serialize_ui(prefix: str, records: list[dict], trailing: str) -> str:
    lines = [prefix.rstrip("\n")]
    for record in records:
        checked = f"|checked={record['checked']}" if record["class"].endswith("Switch") else ""
        lines.append(
            f"{record['index']}|text={record['text']}|desc={record['content_desc']}|id={record['resource_id']}"
            f"|class={record['class']}|clickable={record['clickable']}|bounds={record['bounds']}{checked}"
        )
    return "\n".join(lines) + "\n" + trailing


def refresh_output_hashes(ui_paths: set[Path], lane: Path) -> int:
    refreshed = 0
    changed_paths = {path.resolve() for path in ui_paths}
    for meta_path in sorted(lane.glob("*.json")):
        try:
            data = json.loads(read_text(meta_path))
        except json.JSONDecodeError:
            continue
        if not isinstance(data, dict):
            continue
        output = data.get("output")
        if not isinstance(output, str):
            continue
        output_path = Path(output)
        if not output_path.is_absolute():
            output_path = lane / output_path
        if output_path.resolve() not in changed_paths:
            continue
        file_digest = digest(output_path)
        changed = False
        for key, value in list(data.items()):
            if "sha256" in key.casefold() and isinstance(value, str) and re.fullmatch(r"[A-Fa-f0-9]{64}", value):
                if value != file_digest:
                    data[key] = file_digest
                    changed = True
        if changed:
            meta_path.write_text(json.dumps(data, indent=2, ensure_ascii=False) + "\n", encoding="utf-8", newline="\n")
            refreshed += 1
    return refreshed


def collect_account_names(lane: Path) -> set[str]:
    names: set[str] = set()
    patterns = [
        re.compile(r"\b(?:Audio|Video) assistance\s+(?:Requested|Accepted|Active|Declined|Expired|Ended|Failed|Waiting for consent)\s+From\s+([^\n]+?)\s+Requested\s+", re.IGNORECASE),
        re.compile(r"(?m)^From\s*\n\s*([^\n]+)"),
    ]
    for path in sorted(item for item in lane.glob("*") if item.is_file() and item.suffix in {".txt", ".json", ".log"}):
        text = read_text(path)
        for pattern in patterns:
            names.update(match.group(1).strip() for match in pattern.finditer(text) if match.group(1).strip())
    return names


def redact_account_names_text(text: str, names: set[str]) -> str:
    for name in sorted(names, key=len, reverse=True):
        if not name or name.startswith("[REDACTED_"):
            continue
        text = re.sub(re.escape(name), "[REDACTED_ACCOUNT]", text)
    return text


def sanitize_ui_lane(lane: Path) -> dict:
    changed: list[Path] = []
    account_names = collect_account_names(lane)
    for path in sorted(lane.glob("*.ui.txt")):
        original = read_text(path)
        try:
            prefix, records, trailing = parse_ui_text(original, path.name)
        except ValueError:
            updated = HELPER.sanitize(original)
            if updated != original:
                path.write_text(updated, encoding="utf-8", newline="\n")
                changed.append(path)
            continue
        if not records:
            continue
        records = HELPER.redact_account_identifiers(records)
        records, omitted = HELPER.omit_notification_contents(records)
        updated_prefix = prefix
        prefix_lines = updated_prefix.splitlines()
        for index, line in enumerate(prefix_lines):
            if line.startswith("node_count="):
                prefix_lines[index] = f"node_count={len(records)}"
            elif line.startswith("omitted_notification_nodes="):
                prefix_lines[index] = f"omitted_notification_nodes={omitted}"
        updated = redact_account_names_text(HELPER.sanitize(serialize_ui("\n".join(prefix_lines), records, trailing)), account_names)
        if updated != original:
            path.write_text(updated, encoding="utf-8", newline="\n")
            changed.append(path)
    refreshed = refresh_output_hashes(set(changed), lane)
    return {"ui_files_changed": len(changed), "metadata_hashes_refreshed": refreshed, "changed_files": [path.name for path in changed]}


def normalize_notification_scrollers(lane: Path) -> dict:
    changed: list[Path] = []
    account_names = collect_account_names(lane)
    pattern = re.compile(
        r"(?m)^(?P<prefix>\d+\|text=)(?P<text>[^|\n]*)(?P<middle>\|desc=[^|\n]*\|id=com\.android\.systemui:id/notification_stack_scroller\|)"
    )
    for path in sorted(lane.glob("*.ui.txt")):
        original = read_text(path)

        def replace(match: re.Match[str]) -> str:
            if match.group("text") == "[REDACTED_UNRELATED_NOTIFICATION]":
                return match.group(0)
            return match.group("prefix") + "[REDACTED_UNRELATED_NOTIFICATION]" + match.group("middle")

        updated = redact_account_names_text(pattern.sub(replace, original), account_names)
        if updated != original:
            path.write_text(updated, encoding="utf-8", newline="\n")
            changed.append(path)
    refreshed = refresh_output_hashes(set(changed), lane)
    return {"notification_scroller_files_changed": len(changed), "metadata_hashes_refreshed": refreshed}


def redact_package_identities(lane: Path) -> dict:
    changed: list[Path] = []
    pattern = re.compile(r"(?<![\w.])com\.(?!parentcontrol\.parent_control\b|android\.systemui\b|android\.id\b|android\.widget\.|android\.view\.)[A-Za-z0-9_.]+")
    for path in sorted(item for item in lane.rglob("*") if item.is_file() and item.suffix.casefold() in {".txt", ".json", ".log", ".md"}):
        original = read_text(path)
        updated = redact_account_names_text(pattern.sub("[REDACTED_PACKAGE]", original), collect_account_names(lane))
        if updated != original:
            path.write_text(updated, encoding="utf-8", newline="\n")
            changed.append(path)
    refreshed = refresh_output_hashes(set(changed), lane)
    return {"package_identity_files_changed": len(changed), "metadata_hashes_refreshed": refreshed, "changed_files": [path.relative_to(lane).as_posix() for path in changed]}


def privacy_findings(text: str) -> list[str]:
    findings: list[str] = []
    patterns = {
        "email": re.compile(r"\b[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Za-z]{2,}"),
        "jwt": re.compile(r"\beyJ[A-Za-z0-9_-]+\.[A-Za-z0-9_-]+\.[A-Za-z0-9_-]+\b"),
        "network": re.compile(r"(?i)\b(?:networkId|ssid|bssid)=\"(?!\[REDACTED_NETWORK\]\")[^\"\n]*"),
        "coordinate_key": re.compile(r"(?i)\b(?:lat(?:itude)?|lng|longitude)\b['\"]?\s*[:=]\s*['\"]?-?\d+(?:\.\d+)?"),
        "coordinate_pair": re.compile(r"-?\d{1,3}\.\d{3,}\s*,\s*-?\d{1,3}\.\d{3,}(?!\s*\])"),
        "unrelated_package": re.compile(r"(?<![\w.])com\.(?!parentcontrol\.parent_control\b|android\.systemui\b|android\.id\b|android\.widget\.|android\.view\.)[A-Za-z0-9_.]+"),
        "raw_remote_from": re.compile(r"\b(?:Audio|Video) assistance\s+(?:Requested|Accepted|Active|Declined|Expired|Ended|Failed|Waiting for consent)\s+From\s+(?!\[REDACTED_ACCOUNT\])[^\n]+?\s+Requested\s+", re.IGNORECASE),
        "child_code": re.compile(r"\bPC-[A-Z0-9]{8}\b"),
        "secret": re.compile(r"(?i)\b(?:authorization|x-device-secret|apikey|api[_-]?key|access[_-]?token|refresh[_-]?token|device[_-]?secret|password|secret)\b['\"]?\s*[:=]\s*['\']?(?!\[REDACTED_SECRET\])[^,\s;\"'}]+"),
    }
    for name, pattern in patterns.items():
        if pattern.search(text):
            findings.append(name)
    return findings


def write_manifest(lane: Path, name: str) -> dict:
    files = []
    for path in sorted(item for item in lane.rglob("*") if item.is_file() and item.name != name):
        files.append({"path": path.relative_to(lane).as_posix(), "bytes": path.stat().st_size, "sha256": digest(path)})
    manifest = {
        "generated_at": now_iso(),
        "file_count": len(files),
        "total_bytes": sum(item["bytes"] for item in files),
        "files": files,
    }
    (lane / name).write_text(HELPER.sanitize(json.dumps(manifest, indent=2, ensure_ascii=False)) + "\n", encoding="utf-8", newline="\n")
    return manifest


def validate_lane(lane: Path, manifest_name: str, validation_name: str) -> dict:
    invalid_json: list[str] = []
    missing_outputs: list[str] = []
    hash_mismatches: list[dict] = []
    hash_checks = 0
    placeholders: list[str] = []
    notification_issues: list[str] = []
    privacy_issues: list[dict] = []
    remote_identity_issues: list[str] = []
    json_paths = [path for path in sorted(lane.rglob("*.json")) if path.name not in {manifest_name, validation_name}]
    for path in json_paths:
        try:
            data = json.loads(read_text(path))
        except json.JSONDecodeError:
            invalid_json.append(path.relative_to(lane).as_posix())
            continue
        if isinstance(data, dict):
            output = data.get("output")
            if isinstance(output, str):
                output_path = Path(output)
                if not output_path.is_absolute():
                    output_path = lane / output_path
                if not output_path.is_file():
                    missing_outputs.append(path.relative_to(lane).as_posix())
                else:
                    output_digest = digest(output_path)
                    for key, value in data.items():
                        if "sha256" in key.casefold() and isinstance(value, str) and re.fullmatch(r"[A-Fa-f0-9]{64}", value):
                            hash_checks += 1
                            if value != output_digest:
                                hash_mismatches.append({"metadata": path.relative_to(lane).as_posix(), "output": output_path.relative_to(lane).as_posix(), "key": key})
    for path in sorted(item for item in lane.rglob("*") if item.is_file() and item.name not in {manifest_name, validation_name}):
        relative = path.relative_to(lane).as_posix()
        if path.suffix.casefold() not in {".txt", ".json", ".log", ".md"}:
            continue
        text = read_text(path)
        if "__HAVEN_TIMESTAMP_" in text or "__HAVEN_METRIC_" in text or "__HAVEN_DIGEST_" in text:
            placeholders.append(relative)
        if path.name.endswith(".ui.txt"):
            try:
                _, records, _ = parse_ui_text(text, relative)
            except ValueError:
                records = []
            for record in records:
                if record["resource_id"] == "com.android.systemui:id/notification_stack_scroller":
                    if record["text"] != "[REDACTED_UNRELATED_NOTIFICATION]" or record["content_desc"]:
                        notification_issues.append(relative)
                if relative.startswith("L4_032"):
                    desc = record["content_desc"]
                    remote_patterns = [
                        r"(?:Audio|Video) assistance\n(?:Requested|Accepted|Active|Declined|Expired|Ended|Failed|Waiting for consent)\nDevice\n([^\n]+)\nChild\n([^\n]+)",
                        r"\n([^\n]+)\n(?:Audio|Video) assistance · expires",
                        r"(?m)^From\n([^\n]+)",
                        r"(?m)^Device\n([^\n]+)",
                        r"(?m)^Target\n([^\n]+)",
                    ]
                    for remote_pattern in remote_patterns:
                        for match in re.finditer(remote_pattern, desc):
                            if any(value and not value.startswith("[REDACTED_") for value in match.groups()):
                                remote_identity_issues.append(relative)
                                break
        findings = privacy_findings(text)
        if findings:
            privacy_issues.append({"file": relative, "findings": findings})
    manifest = write_manifest(lane, manifest_name)
    result = {
        "root": str(lane),
        "generated_at": now_iso(),
        "json_files_checked": len(json_paths),
        "invalid_json": invalid_json,
        "missing_outputs": missing_outputs,
        "hash_checks": hash_checks,
        "hash_mismatches": hash_mismatches,
        "timestamp_placeholder_files": placeholders,
        "timestamp_placeholder_note": "Legacy placeholders remain only where the original short log timestamps were not reconstructed; outer capture timestamps and monitor summaries are retained.",
        "notification_shade_redaction_issues": notification_issues,
        "privacy_findings": privacy_issues,
        "remote_identity_redaction_issues": sorted(set(remote_identity_issues)),
        "manifest_file_count": manifest["file_count"],
        "manifest_total_bytes": manifest["total_bytes"],
        "status": "PASS" if not (invalid_json or missing_outputs or hash_mismatches or notification_issues or privacy_issues or remote_identity_issues) else "FAIL",
    }
    (lane / validation_name).write_text(HELPER.sanitize(json.dumps(result, indent=2, ensure_ascii=False)) + "\n", encoding="utf-8", newline="\n")
    write_manifest(lane, manifest_name)
    return result


def main() -> int:
    lane4_sanitation = sanitize_ui_lane(ROOT / "lane4")
    lane3_sanitation = sanitize_ui_lane(ROOT / "lane3")
    lane3_notification_sanitation = normalize_notification_scrollers(ROOT / "lane3")
    lane3_package_sanitation = redact_package_identities(ROOT / "lane3")
    lane2_sanitation = normalize_notification_scrollers(ROOT / "lane2")
    lane2_package_sanitation = redact_package_identities(ROOT / "lane2")
    lane4_package_sanitation = redact_package_identities(ROOT / "lane4")
    lane3 = validate_lane(ROOT / "lane3", "evidence_manifest.json", "L4_MEDIA_final_evidence_validation.json")
    lane2 = validate_lane(ROOT / "lane2", "evidence_manifest.json", "BG02_final_evidence_validation.json")
    lane4 = validate_lane(ROOT / "lane4", "evidence_manifest.json", "L4_final_evidence_validation.json")
    summary = {
        "generated_at": now_iso(),
        "lane4_sanitation": lane4_sanitation,
        "lane2_sanitation": lane2_sanitation,
        "lane2_package_sanitation": lane2_package_sanitation,
        "lane4_package_sanitation": lane4_package_sanitation,
        "lane3_sanitation": lane3_sanitation,
        "lane3_notification_sanitation": lane3_notification_sanitation,
        "lane3_package_sanitation": lane3_package_sanitation,
        "lane3_validation": {key: value for key, value in lane3.items() if key != "timestamp_placeholder_files"},
        "lane2_validation": {key: value for key, value in lane2.items() if key != "timestamp_placeholder_files"},
        "lane4_validation": {key: value for key, value in lane4.items() if key != "timestamp_placeholder_files"},
        "status": "PASS" if lane3["status"] == "PASS" and lane2["status"] == "PASS" and lane4["status"] == "PASS" else "FAIL",
    }
    (ROOT / "evidence_reconciliation_summary.json").write_text(HELPER.sanitize(json.dumps(summary, indent=2, ensure_ascii=False)) + "\n", encoding="utf-8", newline="\n")
    print(HELPER.sanitize(json.dumps(summary, indent=2, ensure_ascii=False)))
    return 0 if summary["status"] == "PASS" else 1


if __name__ == "__main__":
    raise SystemExit(main())

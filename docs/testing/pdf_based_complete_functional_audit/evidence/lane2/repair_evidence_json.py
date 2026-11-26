#!/usr/bin/env python3
from __future__ import annotations

import hashlib
import json
import re
from pathlib import Path

ROOT = Path(__file__).resolve().parent
SUMMARY_NAME = "evidence_json_repair_summary.json"


def main() -> int:
    records: list[dict] = []
    changed = 0
    invalid_before = 0
    unrepaired = 0
    hashes_recomputed = 0
    hash_files_changed = 0

    for path in sorted(ROOT.glob("*.json")):
        if path.name == SUMMARY_NAME:
            continue
        original = path.read_text(encoding="utf-8")
        try:
            data = json.loads(original)
        except json.JSONDecodeError:
            invalid_before += 1
            repaired, count = re.subn(r"(:\s*)\[REDACTED_[A-Z_]+\]", r"\1null", original)
            try:
                data = json.loads(repaired)
            except json.JSONDecodeError as exc:
                unrepaired += 1
                records.append({"file": path.name, "repaired": False, "error": str(exc)})
                continue
            if isinstance(data, dict):
                data["_evidence_repair"] = {
                    "original_json_valid": False,
                    "bare_redaction_tokens_replaced_with_null": count,
                    "duration_note": "Legacy coordinate sanitization over-redacted decimal metrics; original values were not reconstructed.",
                }
            changed += 1
            records.append({"file": path.name, "repaired": True, "bare_redaction_tokens_replaced": count})
        else:
            records.append({"file": path.name, "repaired": False, "original_json_valid": True})

        if not isinstance(data, dict):
            continue
        output = data.get("output")
        file_hash_changes = 0
        if isinstance(output, str):
            output_path = Path(output)
            if output_path.is_file():
                digest = hashlib.sha256(output_path.read_bytes()).hexdigest()
                for key in list(data):
                    if "sha256" not in key.casefold() or file_hash_changes:
                        continue
                    value = data[key]
                    if value is None or (isinstance(value, str) and value.startswith("[REDACTED_")):
                        data[key] = digest
                        hashes_recomputed += 1
                        file_hash_changes += 1
        if file_hash_changes:
            hash_files_changed += 1
        path.write_text(json.dumps(data, indent=2, ensure_ascii=False) + "\n", encoding="utf-8", newline="\n")

    summary = {
        "root": str(ROOT),
        "json_files_seen": len(records),
        "invalid_before": invalid_before,
        "files_rewritten": changed,
        "unrepaired": unrepaired,
        "hashes_recomputed": hashes_recomputed,
        "hash_files_changed": hash_files_changed,
        "records": records,
    }
    (ROOT / SUMMARY_NAME).write_text(json.dumps(summary, indent=2, ensure_ascii=False) + "\n", encoding="utf-8", newline="\n")
    print(json.dumps({key: value for key, value in summary.items() if key != "records"}))
    return 0 if unrepaired == 0 else 1


if __name__ == "__main__":
    raise SystemExit(main())

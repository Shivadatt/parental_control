import collections
import json
import re
import subprocess
import sys
import time
from pathlib import Path

ROOT = Path(__file__).resolve().parents[4]
REPORT = ROOT / "docs/testing/FINAL_COMPLETE_FUNCTIONAL_AUDIT.md"
MATRIX = ROOT / "docs/testing/final_two_device_audit/backend/FINAL_FEATURE_MATRIX.json"
ARCHIVE = ROOT / "docs/testing/final_two_device_audit"
OUTPUT = ARCHIVE / "backend/FINAL_REPORT_VALIDATION.json"


def unescaped_pipe_count(line):
    return len(re.findall(r"(?<!\\)\|", line))


def main():
    started = time.monotonic()
    errors = []
    warnings = []
    matrix = json.loads(MATRIX.read_text(encoding="utf-8"))
    report = REPORT.read_text(encoding="utf-8")
    features = matrix["features"]
    statuses = collections.Counter(f["status"] for f in features)
    categories = collections.Counter(f["category"] for f in features)

    if len(features) != matrix["feature_count"]:
        errors.append("matrix feature_count does not match features length")
    if dict(statuses) != {k: v for k, v in matrix["status_counts"].items() if v}:
        errors.append("matrix status_counts do not match features")
    if len({f["id"] for f in features}) != len(features):
        errors.append("duplicate matrix feature IDs")
    if len(categories) != 12:
        errors.append("matrix does not contain exactly 12 A-L categories")
    for feature in features:
        for evidence in feature["evidence"]:
            if not (ROOT / evidence).exists():
                errors.append(f"missing matrix evidence: {feature['id']} {evidence}")

    for placeholder in ("<!-- CATEGORY_COUNTS -->", "<!-- A_L_MATRIX -->"):
        if placeholder in report:
            errors.append(f"unreplaced placeholder: {placeholder}")
    for defect in range(1, 13):
        if f"| E-{defect} |" not in report:
            errors.append(f"missing E-{defect} row")
    for feature in features:
        if f"| {feature['id']} |" not in report:
            errors.append(f"missing report matrix row: {feature['id']}")
    for required in (
        "759",
        "6527198670dce54d0bc1cb96df4bc9aac59824ff78a8b25235dccef9b6618ac9",
        "c7b475eb6f0c818a14d298ce4823e69b0d1a55e9",
        "CN=Android Debug",
        "FAIL — not production-ready",
    ):
        if required not in report:
            errors.append(f"missing required report value: {required}")

    table_errors = []
    expected_pipes = None
    for line in report.splitlines():
        if line.startswith("|"):
            count = unescaped_pipe_count(line)
            if expected_pipes is None:
                expected_pipes = count
            elif count != expected_pipes:
                table_errors.append(count)
        else:
            expected_pipes = None
    if table_errors:
        errors.append(f"inconsistent Markdown table column counts: {len(table_errors)} rows")

    missing_links = []
    for target in re.findall(r"\]\(([^)]+)\)", report):
        if target.startswith(("http://", "https://", "#", "mailto:")):
            continue
        clean_target = target.split("#", 1)[0]
        if not (REPORT.parent / clean_target).exists():
            missing_links.append(target)
    if missing_links:
        errors.append(f"missing local report links: {len(missing_links)}")

    git = subprocess.run(
        ["git", "status", "--short"],
        cwd=ROOT,
        capture_output=True,
        text=True,
        encoding="utf-8",
        errors="replace",
    )
    changed_paths = [line[3:] for line in git.stdout.splitlines() if len(line) >= 4]
    outside_scope = [p for p in changed_paths if not p.startswith("docs/testing/")]
    if git.returncode != 0:
        errors.append("git status --short failed")
    if outside_scope:
        errors.append(f"changed paths outside docs/testing: {len(outside_scope)}")

    scan_counts = collections.Counter()
    scan_files = collections.defaultdict(list)
    email = re.compile(r"[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Za-z]{2,}")
    jwt = re.compile(r"eyJ[A-Za-z0-9_-]+\.[A-Za-z0-9_-]+\.[A-Za-z0-9_-]+")
    child_id = re.compile(r"\bPC-[A-Z0-9]{8}\b")
    pairing_uri = re.compile(r"parentcontrol://pair\?(?:id|code)=(?!…)[^\s<\"']+")
    personal_name = re.compile(r"\bankit1?\b", re.I)
    credential_value = re.compile(
        r"\b(?:password|passwd|pwd)\s*[:=]\s*(?:"
        r"\"(?!(?:true|false|null|redacted|\[redacted)\")[^\"]*\"|"
        r"'(?!(?:true|false|null|redacted|\[redacted)')[^']*'|"
        r"(?![\"'])(?!(?:true|false|null|redacted|\[redacted)\b)[^\s,;]+)",
        re.I,
    )
    mojibake = re.compile(r"â€|Â·|Ã©|ðŸ”|âœ“|â˜’|â†’")
    coordinate = re.compile(r"(?<![\w.])[-+]?\d{1,3}\.\d{4,}(?![\w.])")
    iso = re.compile(r"\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2}(?:\.\d+)?(?:Z|[+-]\d{2}:\d{2})?")
    files = [REPORT]
    files += [
        p
        for p in ARCHIVE.rglob("*")
        if p.is_file()
        and p.suffix.lower() in {".md", ".log", ".json", ".txt", ".xml"}
        and p != OUTPUT
    ]
    for path in files:
        try:
            text = path.read_text(encoding="utf-8-sig")
        except Exception:
            warnings.append(f"unreadable scan file: {path.relative_to(ROOT)}")
            continue
        protected = []
        def protect(match):
            protected.append(match.group(0))
            return f"<ISO_{len(protected)-1}>"
        scan_text = iso.sub(protect, text)
        checks = {
            "email": email,
            "jwt": jwt,
            "child_id": child_id,
            "pairing_uri": pairing_uri,
            "personal_name": personal_name,
            "credential_value": credential_value,
            "mojibake": mojibake,
        }
        if path.suffix.lower() in {".md", ".txt", ".xml"}:
            checks["coordinate"] = coordinate
        elif path.suffix.lower() == ".log":
            checks["coordinate"] = re.compile(r"(?<![\w.])[-+]?\d{1,3}\.\d{5,}(?![\w.])")
        for name, pattern in checks.items():
            count = len(pattern.findall(scan_text))
            if count:
                scan_counts[name] += count
                scan_files[name].append(str(path.relative_to(ROOT)))
        for index, value in enumerate(protected):
            scan_text = scan_text.replace(f"<ISO_{index}>", value)
    for name, count in scan_counts.items():
        errors.append(f"residual sensitive-data pattern {name}: {count}")

    result = {
        "timestamp_utc": time.strftime("%Y-%m-%dT%H:%M:%SZ", time.gmtime()),
        "command": "python docs/testing/final_two_device_audit/backend/validate_final_report.py",
        "working_directory": str(ROOT),
        "duration_s": round(time.monotonic() - started, 3),
        "passed": not errors,
        "feature_count": len(features),
        "status_counts": dict(statuses),
        "category_counts": dict(sorted(categories.items())),
        "report_link_count": len(re.findall(r"\]\(([^)]+)\)", report)),
        "changed_path_count": len(changed_paths),
        "changed_paths_outside_docs_testing": outside_scope,
        "scan_file_count": len(files),
        "residual_scan_counts": dict(scan_counts),
        "residual_scan_files": dict(scan_files),
        "errors": errors,
        "warnings": warnings,
    }
    OUTPUT.write_text(json.dumps(result, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
    print(json.dumps({k: result[k] for k in ("passed", "feature_count", "status_counts", "scan_file_count", "residual_scan_counts", "errors", "warnings")}, ensure_ascii=False))
    return 0 if not errors else 1


if __name__ == "__main__":
    sys.exit(main())

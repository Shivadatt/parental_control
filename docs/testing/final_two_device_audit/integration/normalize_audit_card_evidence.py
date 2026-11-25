#!/usr/bin/env python3
import os
import subprocess
import time
from pathlib import Path

source_path = Path('docs/testing/final_two_device_audit/integration/close_snapshot_audit_gaps.py')
prefix = source_path.read_text(encoding='utf-8').split("try:\n    xml, _ = dump('P46_resume_parent')", 1)[0]
exec(prefix, globals())
LOG = OUT / 'integration/H02_audit_card_evidence_normalized.log'

try:
    for index in (5, 6, 7, 12, 13, 14):
        label = f'P46_audit_commands_{index:02d}'
        remote = f'/sdcard/audit_{label}.xml'
        start = time.monotonic()
        result = subprocess.run(
            ['adb', '-s', PARENT, 'exec-out', 'cat', remote],
            env={**os.environ, 'MSYS_NO_PATHCONV': '1'},
            capture_output=True,
            encoding='utf-8',
            errors='replace',
            timeout=45,
        )
        elapsed = time.monotonic() - start
        lines.append(
            f'[{time.strftime("%Y-%m-%dT%H:%M:%SZ", time.gmtime())}] '
            f'cwd={ROOT} exit={result.returncode} duration_s={elapsed:.3f} '
            f'command=MSYS_NO_PATHCONV=1 adb -s {PARENT} exec-out cat {remote}'
        )
        if result.returncode != 0:
            raise RuntimeError(result.stderr)
        filtered = safe_values(values_from(result.stdout))
        path = OUT / 'parent' / f'{label}.txt'
        path.write_text('\n'.join(filtered) + '\n', encoding='utf-8')
        lines.append(f'evidence={path.relative_to(ROOT)} retained_strings={len(filtered)}')
    lines.append('result=audit cards normalized with timestamps and redacted identities')
except Exception as caught:
    lines.append(f'error={type(caught).__name__}: {caught}')
    lines.append('result=script_error')
finally:
    LOG.write_text('\n'.join(lines) + '\n', encoding='utf-8')
    print('\n'.join(lines))

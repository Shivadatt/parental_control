#!/usr/bin/env python3
import html
import os
import re
import subprocess
import time
from pathlib import Path

ROOT = Path.cwd()
LOG = ROOT / 'docs/testing/final_two_device_audit/integration/F02_quota_enforcement_probe.log'
CHILD = '5HXWRGQ4IFU8WS4T'
lines = []


def run(args, note='', timeout=40, stdout_contains=None):
    start = time.monotonic()
    result = subprocess.run(args, capture_output=True, text=True, timeout=timeout)
    elapsed = time.monotonic() - start
    lines.append(f'[{time.strftime("%Y-%m-%dT%H:%M:%SZ", time.gmtime())}] cwd={ROOT} exit={result.returncode} duration_s={elapsed:.3f} command=' + ' '.join(args))
    if note:
        lines.append('note=' + note)
    stdout = result.stdout.strip()
    if stdout_contains is not None:
        stdout = '\n'.join(line for line in stdout.splitlines() if stdout_contains in line).strip()
    if stdout:
        lines.append('stdout=' + stdout)
    if result.stderr.strip():
        lines.append('stderr=' + result.stderr.strip())
    return result


try:
    run(['adb', '-s', CHILD, 'shell', 'cmd', 'package', 'resolve-activity', '--brief', 'com.android.chrome'], 'Resolve only the safe browser target; do not enumerate apps')
    run(['adb', '-s', CHILD, 'shell', 'monkey', '-p', 'com.android.chrome', '-c', 'android.intent.category.LAUNCHER', '1'], 'Launch safe browser while Parent reports reached 60-minute quota')
    time.sleep(4)
    run(['adb', '-s', CHILD, 'shell', 'dumpsys', 'window'], 'Check actual foreground app after quota should have been reached', stdout_contains='mCurrentFocus')
    run(['adb', '-s', CHILD, 'shell', 'uiautomator', 'dump', '/sdcard/audit_C27_browser_quota.xml'], 'Capture only policy/blocking labels in memory')
    xml = subprocess.run(
        ['adb', '-s', CHILD, 'exec-out', 'cat', '/sdcard/audit_C27_browser_quota.xml'],
        env={**os.environ, 'MSYS_NO_PATHCONV': '1'}, capture_output=True, text=True,
    )
    values = [re.sub(r'\s+', ' ', html.unescape(value)).strip() for value in re.findall(r'(?:content-desc|text)="([^"]*)"', xml.stdout)]
    allowed = ('Screen time', 'screen time', 'limit', 'Limit', 'Parent Control', 'parent control', 'blocked', 'Blocked', 'reached', 'Reached', 'Guardian', 'Home', 'Back')
    filtered = [value for value in values if value and value.startswith(allowed)]
    evidence = ROOT / 'docs/testing/final_two_device_audit/child/C27_browser_quota_filtered.txt'
    evidence.write_text('\n'.join(filtered) + '\n', encoding='utf-8')
    lines.append(f'evidence={evidence.relative_to(ROOT)} retained_strings={len(filtered)}')
    run(['adb', '-s', CHILD, 'shell', 'input', 'keyevent', 'KEYCODE_HOME'], 'Return Child to launcher without altering policy')
    lines.append('result=probe completed; inspect foreground package and filtered block labels')
except Exception as caught:
    lines.append(f'error={type(caught).__name__}: {caught}')
    lines.append('result=script_error')
finally:
    LOG.write_text('\n'.join(lines) + '\n', encoding='utf-8')
    print('\n'.join(lines[-16:]))

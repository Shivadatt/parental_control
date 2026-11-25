#!/usr/bin/env python3
import html
import re
import subprocess
import time
from pathlib import Path

ROOT = Path.cwd()
OUT = ROOT / 'docs/testing/final_two_device_audit'
LOG = OUT / 'integration/F02_screen_time_policy_ack.log'
PARENT = 'emulator-5554'
CHILD = '5HXWRGQ4IFU8WS4T'
ADB = 'adb'

lines = []


def run(args, note='', timeout=45):
    command = ' '.join(args)
    start = time.monotonic()
    result = subprocess.run(args, capture_output=True, text=True, timeout=timeout)
    duration = time.monotonic() - start
    lines.append(f'[{time.strftime("%Y-%m-%dT%H:%M:%SZ", time.gmtime())}] cwd={ROOT} exit={result.returncode} duration_s={duration:.3f} command={command}')
    if note:
        lines.append(f'note={note}')
    if result.stdout.strip():
        lines.append('stdout=' + result.stdout.strip())
    if result.stderr.strip():
        lines.append('stderr=' + result.stderr.strip())
    return result


def dump(serial, label):
    remote = f'/sdcard/audit_{label}.xml'
    run([ADB, '-s', serial, 'shell', 'uiautomator', 'dump', remote], label)
    start = time.monotonic()
    result = subprocess.run(
        ['adb', '-s', serial, 'exec-out', 'cat', remote],
        env={**__import__('os').environ, 'MSYS_NO_PATHCONV': '1'},
        capture_output=True,
        text=True,
    )
    elapsed = time.monotonic() - start
    lines.append(f'[{time.strftime("%Y-%m-%dT%H:%M:%SZ", time.gmtime())}] cwd={ROOT} exit={result.returncode} duration_s={elapsed:.3f} command=MSYS_NO_PATHCONV=1 adb -s {serial} exec-out cat {remote}')
    lines.append(f'note=UI capture {label}')
    if result.returncode != 0:
        raise RuntimeError(result.stderr)
    values = []
    for raw in re.findall(r'(?:content-desc|text)="([^"]*)"', result.stdout):
        value = html.unescape(raw)
        for old, new in (('&#10;', ' | '), ('&#8239;', ' '), ('&#8217;', "'"), ('&#8211;', '-'), ('&amp;', '&')):
            value = value.replace(old, new)
        value = re.sub(r'\s+', ' ', value).strip()
        if value:
            values.append(value)
    safe_prefixes = (
        'Back', 'Screen time', 'Refresh screen time', 'Usage Access', 'Last usage upload',
        'Today', 'Last 7 days', 'Screen-time policy', 'Daily limit, bedtime',
        'No policy', 'Policy v', 'Pending device acknowledgement', 'This version is saved',
        'Advisory Mode', 'The device acknowledged', 'Enforcement failed', 'Could not save',
        'Daily screen-time limit', 'No daily limit', '1h', '45m', '30m', '15m',
        'Time remaining today', 'No daily limit set', 'Unknown', 'Limit reached',
        'No limit to reach', 'Reached', 'Not reached', 'Enforcement mode', 'Device admin only',
        'Device owner', 'Bedtime', 'No bedtime window set.', 'Set start', 'Set end',
        'Clear bedtime', 'Remove limit', 'Save screen-time policy', 'Refresh policy state',
        'Decrease limit', 'Increase limit', 'Rules', 'Home', 'Settings', 'No rules',
        'Usage and access', 'Location sharing', 'Guardian', 'Device Admin', 'Device Owner',
    )
    filtered = []
    for value in values:
        if value.startswith(safe_prefixes):
            if value.startswith('Usage |'):
                value = value.split(' | Parent Control')[0] + ' | [PER-APP LABELS OMITTED]'
            filtered.append(value)
    path = OUT / ('parent' if serial == PARENT else 'child') / f'{label}.txt'
    path.write_text('\n'.join(filtered) + '\n', encoding='utf-8')
    lines.append(f'evidence={path.relative_to(ROOT)} retained_strings={len(filtered)}')
    return result.stdout, filtered


def bounds(xml, label):
    for tag in re.findall(r'<node\b[^>]*>', xml):
        decoded = html.unescape(tag)
        if f'content-desc="{label}"' in decoded or f'text="{label}"' in decoded:
            found = re.search(r'bounds="\[(\d+),(\d+)\]\[(\d+),(\d+)\]"', decoded)
            if found:
                x1, y1, x2, y2 = map(int, found.groups())
                return (x1 + x2) // 2, (y1 + y2) // 2
    return None


def tap(xml, label, note):
    point = bounds(xml, label)
    if not point:
        raise RuntimeError(f'Control not found: {label}')
    run([ADB, '-s', PARENT, 'shell', 'input', 'tap', str(point[0]), str(point[1])], note)


try:
    xml, _ = dump(PARENT, 'P37_screen_time_before_limit')
    tap(xml, 'Increase limit', 'Set draft daily limit to 60 minutes')
    time.sleep(1)
    xml, _ = dump(PARENT, 'P37_screen_time_limit_60m')
    for index in range(3):
        run([ADB, '-s', PARENT, 'shell', 'input', 'swipe', '540', '1900', '540', '550'], f'Scroll toward save control {index + 1}')
        time.sleep(0.7)
    xml, _ = dump(PARENT, 'P37_screen_time_save_visible')
    tap(xml, 'Save screen-time policy', 'Save 60-minute daily limit; bedtime remains unset')
    for index in range(12):
        time.sleep(5)
        xml, values = dump(PARENT, f'P37_screen_time_ack_{index + 1:02d}')
        if any('Advisory Mode' in value or 'acknowledged' in value for value in values):
            break
    time.sleep(3)
    dump(CHILD, 'C27_child_after_policy')
    run([ADB, '-s', PARENT, 'shell', 'dumpsys', 'activity', 'services', 'com.parentcontrol.parent_control'], 'Parent service state after save')
    run([ADB, '-s', CHILD, 'shell', 'dumpsys', 'activity', 'services', 'com.parentcontrol.parent_control'], 'Child Guardian and policy service state after save')
    lines.append('result=screen-time policy saved and acknowledgement observed' if any('acknowledged' in value for value in values) else 'result=screen-time policy save attempted; final acknowledgement not observed')
except Exception as caught:
    lines.append(f'error={type(caught).__name__}: {caught}')
    lines.append('result=script_error')
finally:
    LOG.write_text('\n'.join(lines) + '\n', encoding='utf-8')
    print('\n'.join(lines[-20:]))

#!/usr/bin/env python3
import html
import os
import re
import subprocess
import time
from pathlib import Path

ROOT = Path.cwd()
OUT = ROOT / 'docs/testing/final_two_device_audit'
LOG = OUT / 'integration/F02_bedtime_policy_ack.log'
PARENT = 'emulator-5554'
CHILD = '5HXWRGQ4IFU8WS4T'
lines = []


def run(args, note='', timeout=45):
    start = time.monotonic()
    result = subprocess.run(args, capture_output=True, text=True, timeout=timeout)
    elapsed = time.monotonic() - start
    lines.append(f'[{time.strftime("%Y-%m-%dT%H:%M:%SZ", time.gmtime())}] cwd={ROOT} exit={result.returncode} duration_s={elapsed:.3f} command=' + ' '.join(args))
    if note:
        lines.append('note=' + note)
    if result.stdout.strip():
        lines.append('stdout=' + result.stdout.strip())
    if result.stderr.strip():
        lines.append('stderr=' + result.stderr.strip())
    return result


def dump(serial, label):
    remote = f'/sdcard/audit_{label}.xml'
    run(['adb', '-s', serial, 'shell', 'uiautomator', 'dump', remote], label)
    start = time.monotonic()
    result = subprocess.run(
        ['adb', '-s', serial, 'exec-out', 'cat', remote],
        env={**os.environ, 'MSYS_NO_PATHCONV': '1'}, capture_output=True, text=True,
    )
    elapsed = time.monotonic() - start
    lines.append(f'[{time.strftime("%Y-%m-%dT%H:%M:%SZ", time.gmtime())}] cwd={ROOT} exit={result.returncode} duration_s={elapsed:.3f} command=MSYS_NO_PATHCONV=1 adb -s {serial} exec-out cat {remote}')
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
        'Back', 'Screen time', 'Screen-time policy', 'Daily limit, bedtime', 'No policy',
        'Policy v', 'Pending device acknowledgement', 'This version is saved', 'Enforced on device',
        'Advisory Mode', 'The device acknowledged', 'Could not save', 'Daily screen-time limit',
        'No daily limit', '1h', 'Time remaining today', 'No daily limit set', 'Limit reached',
        'No limit to reach', 'Reached', 'Enforcement mode', 'Device admin only', 'Bedtime',
        'No bedtime window set.', '9:00 PM', '7:00 AM', 'Set start', 'Set end', 'Clear bedtime',
        'Remove limit', 'Save screen-time policy', 'Refresh policy state', 'Decrease limit',
        'Increase limit', 'OK', 'Cancel', 'Select time', 'Enter time', 'Bedtime start and end',
        'Rules', 'Home', 'Settings', 'Location sharing', 'Guardian', 'Device Admin', 'Device Owner',
    )
    filtered = [value for value in values if value.startswith(safe_prefixes)]
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


def tap(xml, serial, label, note):
    point = bounds(xml, label)
    if not point:
        raise RuntimeError(f'Control not found: {label}')
    run(['adb', '-s', serial, 'shell', 'input', 'tap', str(point[0]), str(point[1])], note)


def scroll_to(xml, label):
    if bounds(xml, label):
        return xml
    for index in range(3):
        run(['adb', '-s', PARENT, 'shell', 'input', 'swipe', '540', '1900', '540', '550'], f'Scroll toward {label} {index + 1}')
        time.sleep(0.6)
        xml, _ = dump(PARENT, f'P38_scroll_{label.replace(" ", "_")}_{index + 1}')
        if bounds(xml, label):
            return xml
    return xml


try:
    xml, _ = dump(PARENT, 'P38_bedtime_before')
    xml = scroll_to(xml, 'Remove limit')
    tap(xml, PARENT, 'Remove limit', 'Restore original no-daily-limit state')
    time.sleep(1)
    xml, _ = dump(PARENT, 'P38_limit_removed')
    xml = scroll_to(xml, 'Set start')
    tap(xml, PARENT, 'Set start', 'Open bedtime start picker; default 9:00 PM')
    time.sleep(0.8)
    picker, _ = dump(PARENT, 'P38_start_picker')
    tap(picker, PARENT, 'OK', 'Accept bedtime start 9:00 PM')
    time.sleep(0.8)
    xml, _ = dump(PARENT, 'P38_start_set')
    xml = scroll_to(xml, 'Set end')
    tap(xml, PARENT, 'Set end', 'Open bedtime end picker; default 7:00 AM')
    time.sleep(0.8)
    picker, _ = dump(PARENT, 'P38_end_picker')
    tap(picker, PARENT, 'OK', 'Accept bedtime end 7:00 AM')
    time.sleep(0.8)
    xml, _ = dump(PARENT, 'P38_bedtime_set')
    xml = scroll_to(xml, 'Save screen-time policy')
    tap(xml, PARENT, 'Save screen-time policy', 'Save bedtime-only policy 21:00-07:00; daily limit absent')
    final_values = []
    for index in range(12):
        time.sleep(5)
        xml, values = dump(PARENT, f'P38_bedtime_ack_{index + 1:02d}')
        final_values = values
        if any('acknowledged' in value for value in values):
            break
    xml = scroll_to(xml, 'Clear bedtime')
    tap(xml, PARENT, 'Clear bedtime', 'Restore original no-bedtime state')
    time.sleep(0.8)
    xml = scroll_to(xml, 'Save screen-time policy')
    tap(xml, PARENT, 'Save screen-time policy', 'Save cleared bedtime and no daily limit')
    for index in range(12):
        time.sleep(5)
        xml, values = dump(PARENT, f'P38_restored_ack_{index + 1:02d}')
        final_values = values
        if any('acknowledged' in value for value in values):
            break
    dump(CHILD, 'C28_child_after_bedtime_restore')
    run(['adb', '-s', CHILD, 'shell', 'dumpsys', 'activity', 'services', 'com.parentcontrol.parent_control'], 'Child foreground services after bedtime restore')
    lines.append('result=bedtime-only policy saved and acknowledged, then cleared and acknowledged' if any('acknowledged' in value for value in final_values) else 'result=bedtime flow attempted; final acknowledgement not observed')
except Exception as caught:
    lines.append(f'error={type(caught).__name__}: {caught}')
    lines.append('result=script_error')
finally:
    LOG.write_text('\n'.join(lines) + '\n', encoding='utf-8')
    print('\n'.join(lines[-20:]))

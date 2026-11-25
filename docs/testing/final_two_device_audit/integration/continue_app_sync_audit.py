#!/usr/bin/env python3
import html
import os
import re
import subprocess
import time
from pathlib import Path

ROOT = Path.cwd()
OUT = ROOT / 'docs/testing/final_two_device_audit'
LOG = OUT / 'integration/F03_app_snapshot_sync_failure_continued.log'
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
        'Back', 'Refresh device', 'Refresh restrictions', 'realme RMX2161', 'Policy',
        'Saved policy version', 'Version', 'Enforcement status', 'Acknowledged', 'Device permissions',
        'Recent commands', 'Delivery is confirmed', 'No commands', 'Sync policy', 'Apply policy',
        'Request usage', 'Request location', 'End session', 'Succeeded', 'Failed', 'Expired',
        'Delivered', 'Pending', 'Manage', 'App restrictions', 'Screen time', 'Location', 'Safe zones',
        'Alerts', 'Remote assistance', 'Policy state', 'Server version', 'Unverified', 'Unsupported',
        'Enforced', 'Applied apps', 'App suspension unsupported', 'Android only allows',
        'A database flag', 'App snapshot unavailable', 'No app snapshot reported',
        'The device has not reported', 'Request device sync', 'Sync requested', 'Could not request a sync',
        'Save restrictions', 'Search apps', 'No apps', 'Blocked apps', 'Allowed apps', 'Home', 'Rules',
        'Settings', 'Location sharing', 'Guardian', 'Last command check', 'Just now',
        'App list upload failed', 'Background sync', 'Service error', 'Device Admin', 'Device Owner',
        'Usage and access', 'Child mode', 'Parent mode', 'Family', 'Permissions', 'Unlink',
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


def scroll_parent_to(xml, label, prefix):
    if bounds(xml, label):
        return xml
    for index in range(4):
        run(['adb', '-s', PARENT, 'shell', 'input', 'swipe', '540', '1900', '540', '550'], f'Scroll toward {label} {index + 1}')
        time.sleep(0.6)
        xml, _ = dump(PARENT, f'{prefix}_{index + 1}')
        if bounds(xml, label):
            return xml
    return xml


def scroll_parent_up_to(xml, label, prefix):
    if bounds(xml, label):
        return xml
    for index in range(4):
        run(['adb', '-s', PARENT, 'shell', 'input', 'swipe', '540', '550', '540', '1900'], f'Scroll up toward {label} {index + 1}')
        time.sleep(0.6)
        xml, _ = dump(PARENT, f'{prefix}_{index + 1}')
        if bounds(xml, label):
            return xml
    return xml


try:
    run(['adb', '-s', CHILD, 'shell', 'monkey', '-p', 'com.parentcontrol.parent_control', '-c', 'android.intent.category.LAUNCHER', '1'], 'Open Child app before capturing status')
    time.sleep(3)
    dump(CHILD, 'C30_child_home_before_repeat_sync')
    xml, _ = dump(PARENT, 'P41_device_detail_before_repeat_sync')
    xml = scroll_parent_to(xml, 'App restrictions', 'P41_detail_scroll')
    tap(xml, PARENT, 'App restrictions', 'Open app restrictions')
    time.sleep(1)
    xml, _ = dump(PARENT, 'P41_restrictions_before_repeat_sync')
    xml = scroll_parent_to(xml, 'Request device sync', 'P41_restrictions_scroll')
    tap(xml, PARENT, 'Request device sync', 'Create second approved sync_policy command')
    time.sleep(1)
    dump(PARENT, 'P41_second_sync_requested')
    child_values = []
    for index in range(14):
        time.sleep(2)
        _, child_values = dump(CHILD, f'C30_sync_poll_{index + 1:02d}')
        if any('App list upload failed' in value for value in child_values):
            break
    run(['adb', '-s', PARENT, 'shell', 'input', 'keyevent', 'KEYCODE_BACK'], 'Return to device detail')
    time.sleep(0.8)
    xml, _ = dump(PARENT, 'P41_detail_after_repeat_sync')
    tap(xml, PARENT, 'Refresh device', 'Refresh command history')
    time.sleep(3)
    xml, _ = dump(PARENT, 'P41_detail_commands_top')
    xml = scroll_parent_to(xml, 'Sync policy', 'P41_commands_scroll')
    dump(PARENT, 'P41_detail_commands_visible')
    xml = scroll_parent_up_to(xml, 'App restrictions', 'P41_snapshot_detail_scroll')
    dump(PARENT, 'P41_detail_snapshot_recheck')
    tap(xml, PARENT, 'App restrictions', 'Reopen app restrictions')
    time.sleep(1)
    xml, _ = dump(PARENT, 'P41_restrictions_after_repeat_sync')
    tap(xml, PARENT, 'Refresh restrictions', 'Refresh app snapshot')
    time.sleep(3)
    dump(PARENT, 'P41_restrictions_refreshed')
    lines.append(f'result=child_error_seen={str(any("App list upload failed" in value for value in child_values)).lower()}; inspect command and snapshot evidence')
except Exception as caught:
    lines.append(f'error={type(caught).__name__}: {caught}')
    lines.append('result=script_error')
finally:
    LOG.write_text('\n'.join(lines) + '\n', encoding='utf-8')
    print('\n'.join(lines[-20:]))

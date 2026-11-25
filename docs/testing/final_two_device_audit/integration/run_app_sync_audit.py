#!/usr/bin/env python3
import html
import os
import re
import subprocess
import time
from pathlib import Path

ROOT = Path.cwd()
OUT = ROOT / 'docs/testing/final_two_device_audit'
LOG = OUT / 'integration/F03_app_snapshot_sync_failure.log'
PARENT = 'emulator-5554'
CHILD = '5HXWRGQ4IFU8WS4T'
lines = []


def run(args, note='', timeout=45, stdout_contains=None):
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
        'Back', 'Refresh device', 'Refresh policy state', 'Refresh restrictions', 'realme RMX2161',
        'Policy', 'Saved policy version', 'Version', 'Enforcement status', 'No policy acknowledgement',
        'Acknowledged', 'Not yet acknowledged', 'Device permissions', 'Recent commands',
        'Delivery is confirmed', 'No commands', 'sync_policy', 'apply_policy', 'Succeeded', 'Failed',
        'Expired', 'Pending', 'Requested', 'Acknowledged', 'Manage', 'App restrictions', 'Screen time',
        'Location', 'Policy state', 'Server version', 'Unverified', 'Unsupported', 'Enforced',
        'Applied apps', 'App suspension unsupported', 'Android only allows', 'On this device',
        'A database flag', 'Saving only stores', 'App snapshot unavailable', 'No app snapshot reported',
        'The device has not reported an installed-app snapshot', 'Request device sync',
        'Sync requested', 'Could not request a sync', 'Save restrictions', 'Search apps',
        'No apps', 'Blocked apps', 'Allowed apps', 'Home', 'Rules', 'Settings', 'Location sharing',
        'Guardian', 'Last command check', 'Just now', 'App list upload failed', 'Background sync',
        'Service error', 'Device Admin', 'Device Owner', 'Usage and access',
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


try:
    xml, _ = dump(PARENT, 'P40_device_detail_before_sync')
    tap(xml, PARENT, 'App restrictions', 'Open app restrictions from device detail')
    time.sleep(1)
    xml, _ = dump(PARENT, 'P40_restrictions_before_sync')
    xml = scroll_parent_to(xml, 'Request device sync', 'P40_restrictions_scroll')
    dump(PARENT, 'P40_restrictions_sync_visible')
    tap(xml, PARENT, 'Request device sync', 'Create approved sync_policy command')
    time.sleep(2)
    dump(PARENT, 'P40_sync_requested')
    time.sleep(45)
    child_xml, child_values = dump(CHILD, 'C29_child_app_upload_error')
    run(['adb', '-s', PARENT, 'shell', 'input', 'keyevent', 'KEYCODE_BACK'], 'Return to device detail')
    time.sleep(0.8)
    xml, _ = dump(PARENT, 'P40_device_detail_after_sync')
    tap(xml, PARENT, 'Refresh device', 'Refresh command history after Child poll')
    time.sleep(3)
    xml, _ = dump(PARENT, 'P40_device_detail_commands')
    tap(xml, PARENT, 'App restrictions', 'Reopen app restrictions to verify snapshot state')
    time.sleep(2)
    xml, _ = dump(PARENT, 'P40_restrictions_after_sync')
    tap(xml, PARENT, 'Refresh restrictions', 'Refresh app snapshot from server')
    time.sleep(3)
    dump(PARENT, 'P40_restrictions_refreshed')
    run(['adb', '-s', CHILD, 'shell', 'dumpsys', 'activity', 'services', 'com.parentcontrol.parent_control'], 'Child foreground services after forced app upload attempt')
    error_seen = any('App list upload failed' in value for value in child_values)
    lines.append(f'result=child_error_seen={str(error_seen).lower()}; inspect Parent command status and snapshot state')
except Exception as caught:
    lines.append(f'error={type(caught).__name__}: {caught}')
    lines.append('result=script_error')
finally:
    LOG.write_text('\n'.join(lines) + '\n', encoding='utf-8')
    print('\n'.join(lines[-20:]))

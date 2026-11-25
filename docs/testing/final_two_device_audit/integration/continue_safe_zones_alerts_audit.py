#!/usr/bin/env python3
import html
import os
import re
import subprocess
import time
from pathlib import Path

ROOT = Path.cwd()
OUT = ROOT / 'docs/testing/final_two_device_audit'
LOG = OUT / 'integration/G01_safe_zones_and_alerts_continued.log'
PARENT = 'emulator-5554'
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


def dump(label):
    remote = f'/sdcard/audit_{label}.xml'
    run(['adb', '-s', PARENT, 'shell', 'uiautomator', 'dump', remote], label)
    start = time.monotonic()
    result = subprocess.run(
        ['adb', '-s', PARENT, 'exec-out', 'cat', remote],
        env={**os.environ, 'MSYS_NO_PATHCONV': '1'}, capture_output=True, text=True,
    )
    elapsed = time.monotonic() - start
    lines.append(f'[{time.strftime("%Y-%m-%dT%H:%M:%SZ", time.gmtime())}] cwd={ROOT} exit={result.returncode} duration_s={elapsed:.3f} command=MSYS_NO_PATHCONV=1 adb -s {PARENT} exec-out cat {remote}')
    if result.returncode != 0:
        raise RuntimeError(result.stderr)
    values = []
    for raw in re.findall(r'(?:content-desc|text)="([^"]*)"', result.stdout):
        value = html.unescape(raw)
        for old, new in (('&#10;', ' | '), ('&#8239;', ' '), ('&#8217;', "'"), ('&#8211;', '-'), ('&amp;', '&')):
            value = value.replace(old, new)
        value = re.sub(r'\s+', ' ', value).strip()
        value = re.sub(r'-?\d{1,3}\.\d{3,}', '[REDACTED COORDINATE]', value)
        if value:
            values.append(value)
    safe_prefixes = (
        'Back', 'Refresh', 'Safe zones', 'Action failed', 'QA Test Zone', 'QA_Test_Zone_Live',
        'Active', 'Inactive', 'Centre', '[REDACTED COORDINATE]', 'Radius', 'Edit', 'Delete',
        'Create a safe zone', 'Edit safe zone', 'Zone name', 'Latitude', 'Longitude',
        'Radius (metres)', 'Save', 'Cancel', 'Delete zone', 'Delete safe zone',
        'This cannot be undone', 'This removes the zone', 'No safe zones', 'Safety alerts',
        'unacknowledged', 'All', 'Info', 'Warning', 'Critical', 'No alerts',
        'Device battery is low', 'Low battery', 'Offline', 'Geofence', 'App blocked',
        'Permission missing', 'Other', 'Acknowledged', 'Acknowledge', 'Device', 'realme RMX2161',
        'Time', 'Manage', 'App restrictions', 'Screen time', 'Location', 'Remote assistance',
    )
    filtered = [value for value in values if value.startswith(safe_prefixes)]
    path = OUT / 'parent' / f'{label}.txt'
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
    run(['adb', '-s', PARENT, 'shell', 'input', 'tap', str(point[0]), str(point[1])], note)


def scroll_to(xml, label, prefix, direction='down'):
    if bounds(xml, label):
        return xml
    for index in range(4):
        gesture = ['540', '1900', '540', '550'] if direction == 'down' else ['540', '550', '540', '1900']
        run(['adb', '-s', PARENT, 'shell', 'input', 'swipe', *gesture], f'Scroll {direction} toward {label} {index + 1}')
        time.sleep(0.6)
        xml, _ = dump(f'{prefix}_{index + 1}')
        if bounds(xml, label):
            return xml
    return xml


try:
    xml, _ = dump('P43_safe_zone_editor_current')
    tap(xml, 'Save', 'Save existing safe zone unchanged to verify edit persistence')
    time.sleep(3)
    xml, _ = dump('P43_safe_zone_edit_saved')
    tap(xml, 'Delete', 'Open delete confirmation only')
    time.sleep(0.8)
    xml, _ = dump('P43_safe_zone_delete_warning')
    tap(xml, 'Cancel', 'Cancel irreversible safe-zone deletion')
    time.sleep(1)
    xml, _ = dump('P43_safe_zone_delete_cancelled')
    run(['adb', '-s', PARENT, 'shell', 'input', 'keyevent', 'KEYCODE_BACK'], 'Return to device detail')
    time.sleep(0.8)
    xml, _ = dump('P43_device_detail')
    xml = scroll_to(xml, 'Safety alerts', 'P43_alerts_entry_scroll', direction='up')
    tap(xml, 'Safety alerts', 'Open safety alerts')
    time.sleep(1)
    xml, _ = dump('P43_alerts_all')
    for severity in ('Info', 'Warning', 'Critical'):
        tap(xml, severity, f'Filter alerts by {severity}')
        time.sleep(1)
        xml, _ = dump(f'P43_alerts_{severity.lower()}')
    tap(xml, 'All', 'Return to all alerts')
    time.sleep(1)
    xml, _ = dump('P43_alerts_before_ack')
    if bounds(xml, 'Acknowledge'):
        tap(xml, 'Acknowledge', 'Acknowledge one real safety alert')
        time.sleep(3)
        dump('P43_alerts_after_ack')
    lines.append('result=safe-zone edit saved unchanged, delete cancelled, alert filters and acknowledgement exercised')
except Exception as caught:
    lines.append(f'error={type(caught).__name__}: {caught}')
    lines.append('result=script_error')
finally:
    LOG.write_text('\n'.join(lines) + '\n', encoding='utf-8')
    print('\n'.join(lines[-20:]))

#!/usr/bin/env python3
import html
import os
import re
import subprocess
import time
import xml.etree.ElementTree as ET
from pathlib import Path

ROOT = Path.cwd()
OUT = ROOT / 'docs/testing/final_two_device_audit'
LOG = OUT / 'integration/H02_offline_resume_all_radios_verified.log'
SERIAL = 'emulator-5554'
PACKAGE = 'com.parentcontrol.parent_control'
records = []
started_at = time.monotonic()


def run(args, note, timeout=60):
    start = time.monotonic()
    result = subprocess.run(
        args,
        capture_output=True,
        encoding='utf-8',
        errors='replace',
        timeout=timeout,
        env={**os.environ, 'MSYS_NO_PATHCONV': '1'},
    )
    elapsed = time.monotonic() - start
    output = result.stdout.strip()
    if 'uiautomator' in args or ('exec-out' in args and 'cat' in args):
        output = '[captured separately and sanitized]'
    records.append(
        f'[{time.strftime("%Y-%m-%dT%H:%M:%SZ", time.gmtime())}] cwd={ROOT} '
        f'exit={result.returncode} duration_s={elapsed:.3f} command=' + ' '.join(args)
    )
    records.append(f'note={note}')
    if output:
        records.append('stdout=' + output)
    if result.stderr.strip():
        records.append('stderr=' + result.stderr.strip())
    result.stdout = output
    return result


def clean(value):
    value = html.unescape(value)
    value = re.sub(r'\s+', ' ', value).strip()
    value = re.sub(r'[\w.+-]+@[\w.-]+\.[A-Za-z]{2,}', '[REDACTED EMAIL]', value)
    value = re.sub(r'\b(?:ankit1|ankit)\b', '[ACCOUNT]', value, flags=re.I)
    value = re.sub(r'-?\d{1,3}\.\d{3,}', '[REDACTED COORDINATE]', value)
    value = value.replace('â€“', '-').replace('â€”', '-').replace('Â·', '·').replace('â€¯', ' ')
    return value


def dump(label):
    remote = f'/sdcard/audit_{label}.xml'
    run(['adb', '-s', SERIAL, 'shell', 'uiautomator', 'dump', remote], f'Capture {label}')
    start = time.monotonic()
    result = subprocess.run(
        ['adb', '-s', SERIAL, 'exec-out', 'cat', remote],
        capture_output=True,
        encoding='utf-8',
        errors='replace',
        timeout=60,
        env={**os.environ, 'MSYS_NO_PATHCONV': '1'},
    )
    elapsed = time.monotonic() - start
    records.append(
        f'[{time.strftime("%Y-%m-%dT%H:%M:%SZ", time.gmtime())}] cwd={ROOT} '
        f'exit={result.returncode} duration_s={elapsed:.3f} '
        f'command=MSYS_NO_PATHCONV=1 adb -s {SERIAL} exec-out cat {remote}'
    )
    if result.returncode != 0:
        raise RuntimeError(result.stderr)
    values = []
    root = ET.fromstring(result.stdout)
    for node in root.iter('node'):
        for attribute in ('content-desc', 'text'):
            value = clean(node.attrib.get(attribute, ''))
            if value and value not in values:
                values.append(value)
    path = OUT / f'parent/{label}.txt'
    path.write_text('\n'.join(values) + '\n', encoding='utf-8')
    records.append(f'evidence={path.relative_to(ROOT)} retained_strings={len(values)}')
    records.append(f'{label}_offline_marker=' + str(any('offline' in value.lower() for value in values)).lower())
    records.append(f'{label}_internet_marker=' + str(any(('internet' in value.lower() and 'no ' in value.lower()) or 'connection' in value.lower() for value in values)).lower())
    return result.stdout, values


def bounds(xml, label):
    root = ET.fromstring(xml)
    for node in root.iter('node'):
        if any(
            re.fullmatch(rf'{re.escape(label)}(?: Tab \d of \d)?', clean(node.attrib.get(attribute, '')))
            for attribute in ('content-desc', 'text')
        ):
            match = re.search(r'\[(\d+),(\d+)\]\[(\d+),(\d+)\]', node.attrib.get('bounds', ''))
            if match:
                x1, y1, x2, y2 = map(int, match.groups())
                return str((x1 + x2) // 2), str((y1 + y2) // 2)
    return None


def tap(xml, label, note):
    point = bounds(xml, label)
    if point is None:
        raise RuntimeError(f'Control not found: {label}')
    run(['adb', '-s', SERIAL, 'shell', 'input', 'tap', *point], note)


try:
    run(['adb', '-s', SERIAL, 'shell', 'settings', 'get', 'global', 'wifi_on'], 'Record emulator Wi-Fi setting before test')
    run(['adb', '-s', SERIAL, 'shell', 'settings', 'get', 'global', 'mobile_data'], 'Record emulator mobile-data setting before test')
    xml, values = dump('P49c_offline_before')
    tap(xml, 'Dashboard', 'Open Parent Dashboard for offline observation')
    time.sleep(2)
    xml, values = dump('P49c_offline_dashboard_ready')
    run(['adb', '-s', SERIAL, 'shell', 'svc', 'wifi', 'disable'], 'Disable only Parent emulator Wi-Fi')
    run(['adb', '-s', SERIAL, 'shell', 'svc', 'data', 'disable'], 'Disable only Parent emulator mobile data to create a complete network outage')
    time.sleep(15)
    xml, values = dump('P49c_offline_observed')
    if bounds(xml, 'Refresh dashboard'):
        tap(xml, 'Refresh dashboard', 'Exercise dashboard refresh while Parent emulator has no network')
        time.sleep(8)
        xml, values = dump('P49c_offline_refresh_result')
    run(['adb', '-s', SERIAL, 'shell', 'ping', '-c', '2', '-W', '3', '1.1.1.1'], 'Bounded connectivity check while emulator offline; nonzero expected')
    run(['adb', '-s', SERIAL, 'shell', 'svc', 'wifi', 'enable'], 'Restore Parent emulator Wi-Fi')
    run(['adb', '-s', SERIAL, 'shell', 'svc', 'data', 'enable'], 'Restore Parent emulator mobile data')
    time.sleep(18)
    xml, values = dump('P49c_resume_recovered')
    run(['adb', '-s', SERIAL, 'shell', 'ping', '-c', '2', '-W', '3', '1.1.1.1'], 'Bounded connectivity check after Wi-Fi restoration')
    if bounds(xml, 'Refresh dashboard'):
        tap(xml, 'Refresh dashboard', 'Exercise dashboard refresh after connectivity recovery')
    elif bounds(xml, 'Refresh status'):
        tap(xml, 'Refresh status', 'Use visible Refresh status after recovery')
    elif bounds(xml, 'Refresh'):
        tap(xml, 'Refresh', 'Use visible Refresh after recovery')
    time.sleep(8)
    dump('P49c_resume_refresh_result')
finally:
    run(['adb', '-s', SERIAL, 'shell', 'svc', 'wifi', 'enable'], 'Safety cleanup: ensure Parent emulator Wi-Fi is enabled')
    run(['adb', '-s', SERIAL, 'shell', 'svc', 'data', 'enable'], 'Safety cleanup: ensure Parent emulator mobile data is enabled')
    run(['adb', '-s', SERIAL, 'shell', 'settings', 'get', 'global', 'wifi_on'], 'Record final emulator Wi-Fi setting')
    run(['adb', '-s', SERIAL, 'shell', 'settings', 'get', 'global', 'mobile_data'], 'Record final emulator mobile-data setting')

records.append(f'completed=true exit_code=0 duration_s={time.monotonic() - started_at:.3f}')
LOG.write_text('\n'.join(records) + '\n', encoding='utf-8')
print('\n'.join(records[-8:]))

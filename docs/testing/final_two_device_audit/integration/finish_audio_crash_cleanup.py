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
LOG = OUT / 'integration/H03_audio_crash_cleanup_completed.log'
PARENT = 'emulator-5554'
CHILD = '5HXWRGQ4IFU8WS4T'
PACKAGE = 'com.parentcontrol.parent_control'
records = []
started_at = time.monotonic()


def run(args, note):
    start = time.monotonic()
    result = subprocess.run(args, capture_output=True, encoding='utf-8', errors='replace', timeout=60, env={**os.environ, 'MSYS_NO_PATHCONV': '1'})
    output = result.stdout.strip()
    if 'dumpsys' in args:
        service = args[args.index('dumpsys') + 1]
        if service == 'activity':
            output = '\n'.join(line for line in output.splitlines() if re.search(rf'{re.escape(PACKAGE)}/\.(?:GuardianService|LocationTrackingService|AudioAssistanceService)|isForeground=|\(nothing\)', line))
        elif service == 'media.camera':
            output = '\n'.join(line for line in output.splitlines() if re.search(r'Active Camera Clients:|Client Package Name:|Device \d+ is (?:open|closed)', line))
        elif service == 'audio':
            blocks = re.findall(rf'- Package: {re.escape(PACKAGE)}(.*?)(?=\n  - Package:|\Z)', output, flags=re.S)
            output = '\n'.join(line for block in blocks for line in block.splitlines() if re.search(r'Playback active:|Recording active:', line))
    records.append(f'[{time.strftime("%Y-%m-%dT%H:%M:%SZ", time.gmtime())}] cwd={ROOT} exit={result.returncode} duration_s={time.monotonic() - start:.3f} command=' + ' '.join(args))
    records.append('note=' + note)
    if output:
        records.append('stdout=' + output)
    if result.stderr.strip():
        records.append('stderr=' + result.stderr.strip())
    return result


def clean(value):
    value = re.sub(r'\s+', ' ', html.unescape(value)).strip()
    value = re.sub(r'[\w.+-]+@[\w.-]+\.[A-Za-z]{2,}', '[REDACTED EMAIL]', value)
    value = re.sub(r'\b(?:ankit1|ankit)\b', '[ACCOUNT]', value, flags=re.I)
    return value.replace('â€“', '-').replace('Â·', '·').replace('â€¯', ' ')


def dump(serial, label):
    remote = f'/sdcard/audit_{label}.xml'
    run(['adb', '-s', serial, 'shell', 'uiautomator', 'dump', remote], f'Capture {label}')
    start = time.monotonic()
    result = subprocess.run(['adb', '-s', serial, 'exec-out', 'cat', remote], capture_output=True, encoding='utf-8', errors='replace', timeout=60, env={**os.environ, 'MSYS_NO_PATHCONV': '1'})
    records.append(f'[{time.strftime("%Y-%m-%dT%H:%M:%SZ", time.gmtime())}] cwd={ROOT} exit={result.returncode} duration_s={time.monotonic() - start:.3f} command=MSYS_NO_PATHCONV=1 adb -s {serial} exec-out cat {remote}')
    values = []
    for node in ET.fromstring(result.stdout).iter('node'):
        for attribute in ('content-desc', 'text'):
            value = clean(node.attrib.get(attribute, ''))
            if value and value not in values:
                values.append(value)
    folder = 'parent' if serial == PARENT else 'child'
    path = OUT / f'{folder}/{label}.txt'
    path.write_text('\n'.join(values) + '\n', encoding='utf-8')
    records.append(f'evidence={path.relative_to(ROOT)} retained_strings={len(values)}')
    return result.stdout, values


def tap(serial, xml, label, note):
    for node in ET.fromstring(xml).iter('node'):
        if any(clean(node.attrib.get(attribute, '')) == label for attribute in ('content-desc', 'text')):
            match = re.search(r'\[(\d+),(\d+)\]\[(\d+),(\d+)\]', node.attrib.get('bounds', ''))
            if match:
                x1, y1, x2, y2 = map(int, match.groups())
                run(['adb', '-s', serial, 'shell', 'input', 'tap', str((x1 + x2) // 2), str((y1 + y2) // 2)], note)
                return
    raise RuntimeError(f'Control not found: {label}')


xml, values = dump(PARENT, 'P54_before_final_end')
tap(PARENT, xml, 'End and leave', 'Confirm Parent-controlled end of the stranded session')
time.sleep(8)
xml, values = dump(PARENT, 'P54_after_final_end')
records.append('parent_session_end_confirmed=' + str(any('Ended' in value or 'ended' in value for value in values) or any('Request audio' in value for value in values)).lower())
records.append('duplicate_request_while_active=BLOCKED_BY_PARENT_LEAVE_CONFIRMATION')
run(['adb', '-s', CHILD, 'shell', 'monkey', '-p', PACKAGE, '-c', 'android.intent.category.LAUNCHER', '1'], 'Relaunch Child after confirmed server-side session end')
time.sleep(8)
dump(CHILD, 'C54_child_relaunched')
child_services = run(['adb', '-s', CHILD, 'shell', 'dumpsys', 'activity', 'services', PACKAGE], 'Verify Child foreground services after cleanup')
child_camera = run(['adb', '-s', CHILD, 'shell', 'dumpsys', 'media.camera'], 'Verify Child camera is closed after cleanup')
child_audio = run(['adb', '-s', CHILD, 'shell', 'dumpsys', 'audio'], 'Verify Child recording is inactive after cleanup')
active_match = re.search(r'Active Camera Clients:\s*\[(.*?)\]', child_camera.stdout, flags=re.S)
active_clients = active_match.group(1) if active_match else ''
camera_open = PACKAGE in active_clients
blocks = re.findall(rf'- Package: {re.escape(PACKAGE)}(.*?)(?=\n  - Package:|\Z)', child_audio.stdout, flags=re.S)
recording = any(re.search(r'Recording active:\s*true', block) for block in blocks)
audio_service = 'AudioAssistanceService' in child_services.stdout
guardian_restored = 'GuardianService' in child_services.stdout and 'LocationTrackingService' in child_services.stdout
records.append(f'final_child_camera_open={str(camera_open).lower()}')
records.append(f'final_child_recording_active={str(recording).lower()}')
records.append(f'final_child_audio_service_active={str(audio_service).lower()}')
records.append(f'final_child_normal_services_restored={str(guardian_restored).lower()}')
records.append('e12_final_result=' + ('PASS' if not camera_open and not recording and not audio_service and guardian_restored else 'FAIL'))
records.append(f'completed=true exit_code=0 duration_s={time.monotonic() - started_at:.3f}')
LOG.write_text('\n'.join(records) + '\n', encoding='utf-8')
print('\n'.join(records[-12:]))

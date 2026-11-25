#!/usr/bin/env python3
import html
import io
import os
import re
import subprocess
import tempfile
import time
import xml.etree.ElementTree as ET
from pathlib import Path

from PIL import Image

ROOT = Path.cwd()
OUT = ROOT / 'docs/testing/final_two_device_audit'
LOG = OUT / 'integration/H02_qr_scanner_verified.log'
PARENT = 'emulator-5554'
PACKAGE = 'com.parentcontrol.parent_control'
SOURCE_QR_SCREENSHOT = OUT / 'child/c15_qr.png'
records = []
started_at = time.monotonic()


def run(args, note, timeout=60, binary=False):
    start = time.monotonic()
    result = subprocess.run(
        args,
        capture_output=True,
        timeout=timeout,
        env={**os.environ, 'MSYS_NO_PATHCONV': '1'},
    )
    elapsed = time.monotonic() - start
    stdout = result.stdout.decode('utf-8', errors='replace') if isinstance(result.stdout, bytes) else result.stdout
    stderr = result.stderr.decode('utf-8', errors='replace') if isinstance(result.stderr, bytes) else result.stderr
    records.append(
        f'[{time.strftime("%Y-%m-%dT%H:%M:%SZ", time.gmtime())}] cwd={ROOT} '
        f'exit={result.returncode} duration_s={elapsed:.3f} command=' + ' '.join(args)
    )
    records.append(f'note={note}')
    if stdout and not binary:
        records.append('stdout=' + stdout.strip())
    if stderr:
        records.append('stderr=' + stderr.strip())
    result.stdout = stdout
    result.stderr = stderr
    return result


def clean(value):
    value = html.unescape(value)
    value = re.sub(r'\s+', ' ', value).strip()
    value = re.sub(r'[\w.+-]+@[\w.-]+\.[A-Za-z]{2,}', '[REDACTED EMAIL]', value)
    value = re.sub(r'\b(?:ankit1|ankit)\b', '[ACCOUNT]', value, flags=re.I)
    value = re.sub(r'\bPC-[A-Z0-9]{8}\b', '[REDACTED CHILD ID]', value)
    value = value.replace('â€“', '-').replace('â€”', '-').replace('Â·', '·').replace('â€¯', ' ')
    return value


def dump(label):
    remote = f'/sdcard/audit_{label}.xml'
    run(['adb', '-s', PARENT, 'shell', 'uiautomator', 'dump', remote], f'Capture {label}')
    start = time.monotonic()
    result = subprocess.run(
        ['adb', '-s', PARENT, 'exec-out', 'cat', remote],
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
        f'command=MSYS_NO_PATHCONV=1 adb -s {PARENT} exec-out cat {remote}'
    )
    records.append(f'note=Sanitized UI capture {label}')
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
    return result.stdout, values


def bounds(xml, label, required=(), prefix=False):
    root = ET.fromstring(xml)
    for node in root.iter('node'):
        for attribute in ('content-desc', 'text'):
            value = clean(node.attrib.get(attribute, ''))
            matches = value.startswith(label) if prefix else value == label
            if matches and all(item in value for item in required):
                match = re.search(r'\[(\d+),(\d+)\]\[(\d+),(\d+)\]', node.attrib.get('bounds', ''))
                if match:
                    x1, y1, x2, y2 = map(int, match.groups())
                    return str((x1 + x2) // 2), str((y1 + y2) // 2)
    return None


def tap(xml, label, note, required=(), prefix=False):
    point = bounds(xml, label, required, prefix)
    if point is None:
        raise RuntimeError(f'Parent control not found: {label}')
    run(['adb', '-s', PARENT, 'shell', 'input', 'tap', *point], note)


def qr_only_image():
    with Image.open(SOURCE_QR_SCREENSHOT) as source:
        image = source.convert('RGB')
    width, height = image.size
    crop = image.crop((int(width * 0.25), int(height * 0.62), int(width * 0.75), int(height * 0.90)))
    canvas = Image.new('RGB', (1200, 1200), 'white')
    crop.thumbnail((1000, 1000), Image.Resampling.NEAREST)
    canvas.paste(crop, ((1200 - crop.width) // 2, (1200 - crop.height) // 2))
    buffer = io.BytesIO()
    canvas.save(buffer, format='PNG')
    return buffer.getvalue()


temporary_path = None
try:
    xml, values = dump('P50_pairing_navigation_start')
    if bounds(xml, 'Pair a device', prefix=True):
        tap(xml, 'Pair a device', 'Open Parent pairing QR scanner', prefix=True)
        time.sleep(5)
        xml, values = dump('P50_parent_scanner_ready')
    for permission_label in ('While using the app', 'Only this time', 'Allow'):
        if bounds(xml, permission_label):
            tap(xml, permission_label, f'Grant scanner camera permission using {permission_label}')
            time.sleep(4)
            xml, values = dump('P50_parent_scanner_permission_result')
            break
    if not any('Point the camera at the child' in value for value in values):
        raise RuntimeError('Parent QR scanner camera surface did not become ready')
    records.append('scanner_camera_ready=true')

    temporary = tempfile.NamedTemporaryFile(prefix='parentcontrol_qr_only_', suffix='.png', delete=False)
    temporary_path = Path(temporary.name)
    temporary.write(qr_only_image())
    temporary.close()
    records.append('temporary_qr_crop=created_from_existing_child_screenshot; crop_contains_only_qr_and_card_margin; payload_not_printed')
    run(
        ['adb', '-s', PARENT, 'emu', 'virtualscene-image', 'table', str(temporary_path)],
        'Show the existing Child QR crop as the Parent emulator virtual camera table image',
    )
    time.sleep(12)
    xml, values = dump('P50_parent_scan_result')
    joined = '\n'.join(values)
    already_linked = 'Child already linked' in joined
    invalid = 'Child ID or code not recognised' in joined
    pairing_request = any('Waiting for consent' in value or 'request' in value.lower() for value in values)
    records.append(f'scan_result_already_linked={str(already_linked).lower()}')
    records.append(f'scan_result_invalid_code={str(invalid).lower()}')
    records.append(f'scan_result_request_visible={str(pairing_request).lower()}')
    records.append('qr_scanner_runtime_result=' + ('PASS' if already_linked or pairing_request else 'PARTIAL' if invalid else 'FAIL'))
finally:
    run(['adb', '-s', PARENT, 'emu', 'virtualscene-image', 'table'], 'Restore default Parent emulator virtual camera table image')
    if temporary_path is not None and temporary_path.exists():
        temporary_path.unlink()
        records.append('temporary_qr_crop=deleted')
    xml, values = dump('P50_qr_cleanup_state')
    if bounds(xml, 'Back'):
        tap(xml, 'Back', 'Leave pairing scanner and return to Parent shell')

records.append(f'completed=true exit_code=0 duration_s={time.monotonic() - started_at:.3f}')
LOG.write_text('\n'.join(records) + '\n', encoding='utf-8')
print('\n'.join(records[-12:]))

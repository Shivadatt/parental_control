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
PARENT = 'emulator-5554'
LOG = OUT / 'integration/H02_snapshot_audit_gap_closure_continued8.log'
lines = []


def run(args, note='', timeout=45):
    start = time.monotonic()
    result = subprocess.run(
        args,
        capture_output=True,
        encoding='utf-8',
        errors='replace',
        timeout=timeout,
    )
    elapsed = time.monotonic() - start
    lines.append(
        f'[{time.strftime("%Y-%m-%dT%H:%M:%SZ", time.gmtime())}] '
        f'cwd={ROOT} exit={result.returncode} duration_s={elapsed:.3f} '
        f'command={" ".join(args)}'
    )
    if note:
        lines.append('note=' + note)
    if result.stdout.strip():
        lines.append('stdout=' + result.stdout.strip())
    if result.stderr.strip():
        lines.append('stderr=' + result.stderr.strip())
    return result


def normalized(raw):
    value = html.unescape(raw)
    for old, new in (
        ('&#8239;', ' '),
        ('&#8217;', "'"),
        ('&#8211;', '-'),
        ('&amp;', '&'),
    ):
        value = value.replace(old, new)
    value = value.replace('\r\n', '\n').replace('\r', '\n').replace('\n', ' | ')
    return re.sub(r'\s+', ' ', value).strip()


def values_from(xml):
    values = []
    root = ET.fromstring(xml)
    for node in root.iter('node'):
        for attribute in ('content-desc', 'text'):
            value = normalized(node.attrib.get(attribute, ''))
            if value and (not values or values[-1] != value):
                values.append(value)
    return values


SAFE_EXACT = {
    'Back', 'Refresh', 'Manage', 'App restrictions', 'Screen time', 'Location',
    'Safe zones', 'Remote assistance', 'Family', 'Dashboard', 'Devices', 'Alerts',
    'Settings', 'Audit log (read-only)', 'Audit & retention', 'Refresh device',
    'Installed apps', 'No app snapshot reported', 'App snapshot unavailable',
    'No installed apps were reported for this device.',
    'The device has not reported its installed apps.',
    'Family overview', 'Family actions', 'Events', 'Append-only history', 'Read-only',
    'Load more', 'Showing up to 500 recent events.',
    'Device acknowledged command', 'Device reported command failure',
    'Restriction policy updated', 'Assistance requested', 'Assistance accepted',
    'Assistance session started', 'Assistance session ended', 'Assistance declined',
    'Settings updated', 'Alert acknowledged', 'Child account linked',
    'Child account unlinked', 'Device credential revoked', 'Historical data purged',
    'Family created', 'Linking code generated', 'Linking code redeemed',
    'Pairing approved', 'Pairing declined', 'Device enrolled',
    'Device acknowledged command', 'Actor', 'Device', 'Time', 'Target',
}
SAFE_PREFIXES = (
    'Installed apps |',
    'No app snapshot reported |',
    'The device has not reported',
    'This screen cannot list installed apps',
    'it does not mean the phone has no apps',
    'App snapshot',
    'Could not load',
    'No audit events',
    'Actions such as pairing',
    'sessions, and retention updates',
    'server records them',
    'Only the family owner',
    'No family was supplied',
    'The server enforces this',
    'Showing up to 500',
    'The server deleted',
    'The server deletes',
    'Those are the keep windows',
    'applies its own stored window',
    'This cannot be undone',
    'The audit log is append-only',
    'Only the count the server reports',
)


AUDIT_EVENTS = {
    'Device acknowledged command', 'Device reported command failure',
    'Restriction policy updated', 'Assistance requested', 'Assistance accepted',
    'Assistance session started', 'Assistance session ended', 'Assistance declined',
    'Settings updated', 'Alert acknowledged', 'Child account linked',
    'Child account unlinked', 'Device credential revoked', 'Historical data purged',
    'Family created', 'Linking code generated', 'Linking code redeemed',
    'Pairing approved', 'Pairing declined', 'Device enrolled',
}


def sanitized_audit_card(value):
    parts = [part.strip() for part in value.split(' | ')]
    kept = [parts[0]]
    index = 1
    while index < len(parts):
        label = parts[index]
        if label in {'Actor', 'Device', 'Time', 'Target'} and index + 1 < len(parts):
            if label == 'Time':
                timestamp = re.search(r'[A-Z][a-z]{2} \d{1,2}, \d{4} \d{1,2}:\d{2} [AP]M', parts[index + 1])
                kept.append('Time: ' + (timestamp.group(0) if timestamp else '[REDACTED TIME]'))
            elif label == 'Target':
                target_type = parts[index + 1].split(' · ')[0]
                kept.append('Target: ' + (target_type if target_type in {'device_command', 'device_policy', 'remote_session', 'device', 'family', 'family_member', 'alert'} else '[REDACTED TARGET TYPE]'))
            else:
                kept.append(label + ': [REDACTED]')
            index += 2
            continue
        index += 1
    return ' | '.join(kept)


def safe_values(values):
    kept = []
    previous = None
    for value in values:
        event = next((item for item in AUDIT_EVENTS if value.startswith(item + ' | ')), None)
        if event:
            kept.append(sanitized_audit_card(value))
            previous = value
            continue
        if value.startswith('Installed apps |'):
            parts = [part.strip() for part in value.split(' | ')]
            kept.extend(part for part in parts if part in SAFE_EXACT or part.startswith(SAFE_PREFIXES))
            previous = value
            continue
        if previous in {'Actor', 'Device', 'Target'}:
            kept.append({
                'Actor': '[REDACTED ACTOR]',
                'Device': '[REDACTED DEVICE ID]',
                'Target': '[REDACTED TARGET ID]',
            }[previous])
            previous = value
            continue
        if previous == 'Time':
            timestamp = re.search(r'\d{4}-\d{2}-\d{2}T\d{2}:\d{2}', value)
            relative = re.search(r'(?:Just now|\d+\s+(?:second|minute|hour|day)s?\s+ago)', value)
            kept.append(timestamp.group(0) if timestamp else relative.group(0) if relative else '[REDACTED TIME]')
            previous = value
            continue
        if value in SAFE_EXACT or value.startswith(SAFE_PREFIXES):
            kept.append(value)
        previous = value
    return kept


def dump(label):
    remote = f'/sdcard/audit_{label}.xml'
    run(
        ['adb', '-s', PARENT, 'shell', 'uiautomator', 'dump', remote],
        label,
    )
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
    return result.stdout, filtered


def bounds(xml, label, required=()):
    root = ET.fromstring(xml)
    for node in root.iter('node'):
        node_values = [normalized(node.attrib.get(attribute, '')) for attribute in ('content-desc', 'text')]
        if any(
            (value == label or value.startswith(label + ' | ') or value.startswith(label + ' ') or re.fullmatch(rf'{re.escape(label)}\s+Tab \d of \d', value))
            and all(item in value for item in required)
            for value in node_values
        ):
            found = re.search(r'\[(\d+),(\d+)\]\[(\d+),(\d+)\]', node.attrib.get('bounds', ''))
            if found:
                x1, y1, x2, y2 = map(int, found.groups())
                return (x1 + x2) // 2, (y1 + y2) // 2
    return None


def has_label(xml, label):
    return any(label in value for value in values_from(xml))


def tap(xml, label, note, required=()):
    point = bounds(xml, label, required)
    if not point:
        raise RuntimeError(f'Control not found: {label}')
    run(['adb', '-s', PARENT, 'shell', 'input', 'tap', str(point[0]), str(point[1])], note)


def tap_online_device(xml, note):
    online_seen = False
    root = ET.fromstring(xml)
    for node in root.iter('node'):
        node_values = [normalized(node.attrib.get(attribute, '')) for attribute in ('content-desc', 'text')]
        if any(value.startswith('realme RMX2161') for value in node_values):
            online_seen = any('Online' in value for value in node_values)
            continue
        if online_seen and 'Open device' in node_values:
            found = re.search(r'\[(\d+),(\d+)\]\[(\d+),(\d+)\]', node.attrib.get('bounds', ''))
            if found:
                x1, y1, x2, y2 = map(int, found.groups())
                run(['adb', '-s', PARENT, 'shell', 'input', 'tap', str((x1 + x2) // 2), str((y1 + y2) // 2)], note)
                return
    raise RuntimeError('Open device control for the online realme was not found')


def back(note):
    run(['adb', '-s', PARENT, 'shell', 'input', 'keyevent', 'KEYCODE_BACK'], note)


def scroll(direction, note):
    gesture = ['540', '2100', '540', '150', '900'] if direction == 'down' else ['540', '150', '540', '2100', '900']
    run(['adb', '-s', PARENT, 'shell', 'input', 'swipe', *gesture], note)


def scroll_to(xml, label, prefix, direction='down', limit=10):
    if has_label(xml, label):
        return xml
    for index in range(limit):
        scroll(direction, f'Scroll {direction} toward {label} {index + 1}')
        time.sleep(0.45)
        xml, _ = dump(f'{prefix}_{index + 1}')
        if has_label(xml, label):
            return xml
    return xml


try:
    xml, _ = dump('P46_resume_parent')
    on_app_restrictions = has_label(xml, 'Policy state') and has_label(xml, 'App restrictions')
    on_device_detail = has_label(xml, 'Device identity') or (has_label(xml, 'Manage') and has_label(xml, 'App restrictions'))
    on_parent_shell = has_label(xml, 'Dashboard') and has_label(xml, 'Devices')
    if on_app_restrictions:
        lines.append('resume_point=app_restrictions')
    else:
        if on_parent_shell:
            lines.append('resume_point=parent_shell')
            tap(xml, 'Devices', 'Select Parent devices tab')
            time.sleep(0.8)
            xml, _ = dump('P46_devices_tab_parent')
            xml = scroll_to(xml, 'realme RMX2161', 'P46_device_entry', direction='up')
            for reveal_index in range(3):
                try:
                    tap_online_device(xml, 'Open online realme device detail')
                    break
                except RuntimeError:
                    scroll('down', f'Reveal full online device card {reveal_index + 1}')
                    time.sleep(0.45)
                    xml, _ = dump(f'P46_device_card_reveal_{reveal_index + 1}')
            else:
                raise RuntimeError('Online realme device action remained off-screen')
            time.sleep(0.8)
            xml, _ = dump('P46_device_detail_parent')
        elif not on_device_detail:
            back('Leave ended assistance session')
            time.sleep(0.8)
            xml, _ = dump('P46_remote_assistance_parent')
            back('Return to device detail')
            time.sleep(0.8)
            xml, _ = dump('P46_device_detail_parent')
        else:
            lines.append('resume_point=device_detail')
        xml = scroll_to(xml, 'App restrictions', 'P46_app_entry', direction='down')
        tap(xml, 'App restrictions', 'Open app restrictions')
        time.sleep(0.8)
        xml, _ = dump('P46_app_restrictions_top')
        xml = scroll_to(xml, 'Installed apps', 'P46_apps_scroll')
        xml = scroll_to(xml, 'No app snapshot reported', 'P46_snapshot_scroll', limit=4)
        dump('P46_app_snapshot_current')
        values = values_from(xml)
        lines.append('snapshot_title_visible=' + str(has_label(xml, 'Installed apps')).lower())
        lines.append('no_snapshot_message_visible=' + str(has_label(xml, 'No app snapshot reported')).lower())
        lines.append('snapshot_error_visible=' + str(any('snapshot unavailable' in value.lower() or 'could not load' in value.lower() for value in values)).lower())
        back('Return to device detail')
        time.sleep(0.8)
        back('Return to parent shell')
        time.sleep(0.8)

    xml, _ = dump('P46_parent_shell_current')
    if not has_label(xml, 'Dashboard'):
        raise RuntimeError('Parent shell navigation is not visible')
    if not bounds(xml, 'Dashboard'):
        raise RuntimeError('Dashboard navigation control not found')
    tap(xml, 'Dashboard', 'Select Parent dashboard tab')
    time.sleep(0.8)
    xml, _ = dump('P46_dashboard_parent')
    xml = scroll_to(xml, 'Family', 'P46_family_entry', direction='down')
    tap(xml, 'Family', 'Open family management')
    time.sleep(0.8)
    xml, _ = dump('P46_family_top')
    xml = scroll_to(xml, 'Audit log (read-only)', 'P46_audit_entry', limit=8)
    tap(xml, 'Audit log (read-only)', 'Open read-only audit log')
    time.sleep(1)
    xml, _ = dump('P46_audit_log_top')

    command_pages = 0
    acknowledged = 0
    failed = 0
    all_events = []
    for index in range(14):
        values = values_from(xml)
        page_ack = sum(value == 'Device acknowledged command' or value.startswith('Device acknowledged command | ') for value in values)
        page_failed = sum(value == 'Device reported command failure' or value.startswith('Device reported command failure | ') for value in values)
        all_events.extend(value.split(' | ')[0] for value in values if value in AUDIT_EVENTS or any(value.startswith(event + ' | ') for event in AUDIT_EVENTS))
        if page_ack or page_failed:
            command_pages += 1
            dump(f'P46_audit_commands_{index + 1:02d}')
            acknowledged += page_ack
            failed += page_failed
        if acknowledged >= 2 and failed >= 1:
            break
        if 'Load more' in values:
            tap(xml, 'Load more', 'Load additional audit events')
        else:
            scroll('down', f'Scroll audit log {index + 1}')
        time.sleep(0.65)
        xml, _ = dump(f'P46_audit_scroll_{index + 1:02d}')
    lines.append(f'command_event_pages={command_pages}')
    lines.append(f'command_acknowledged_visible={acknowledged}')
    lines.append(f'command_failed_visible={failed}')
    lines.append('audit_event_sequence=' + ' > '.join(all_events))
    lines.append('result=snapshot state and audit command evidence captured')
except Exception as caught:
    lines.append(f'error={type(caught).__name__}: {caught}')
    lines.append('result=script_error')
finally:
    LOG.write_text('\n'.join(lines) + '\n', encoding='utf-8')
    print('\n'.join(lines[-30:]))

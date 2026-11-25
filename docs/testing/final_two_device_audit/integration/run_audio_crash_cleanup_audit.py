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
LOG = OUT / 'integration/H03_audio_crash_cleanup_final.log'
PARENT = 'emulator-5554'
CHILD = '5HXWRGQ4IFU8WS4T'
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
    if 'dumpsys' in args:
        service = args[args.index('dumpsys') + 1] if args.index('dumpsys') + 1 < len(args) else ''
        if service == 'audio':
            kept = []
            in_target = False
            for line in output.splitlines():
                if re.search(r'^\s*- Package:', line):
                    in_target = PACKAGE in line
                    kept.append(line if in_target else '  - Package: [OTHER PACKAGE]')
                if in_target and re.search(rf'{re.escape(PACKAGE)}|Playback active:|Recording active:|^\s*- Update time:', line):
                    kept.append(line)
                elif re.search(rf'rec (?:update|stop).*pack:{re.escape(PACKAGE)}', line):
                    kept.append(line)
            output = '\n'.join(kept)
        elif service == 'media.camera':
            output = '\n'.join(
                line for line in output.splitlines()
                if re.search(rf'{re.escape(PACKAGE)}|Active Camera Clients:|Device \d+ is (?:open|closed)', line)
            )
        elif service == 'activity':
            output = '\n'.join(
                line for line in output.splitlines()
                if re.search(rf'{re.escape(PACKAGE)}/\.(?:GuardianService|LocationTrackingService|AudioAssistanceService)|isForeground=|foregroundId=|\(nothing\)', line)
            )
    if 'appops' in args:
        output = '\n'.join(line.strip().split(';')[0] for line in output.splitlines() if re.match(r'\s*(?:CAMERA|RECORD_AUDIO):', line))
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
    value = re.sub(r'\bPC-[A-Z0-9]{8}\b', '[REDACTED CHILD ID]', value)
    value = re.sub(r'-?\d{1,3}\.\d{3,}', '[REDACTED COORDINATE]', value)
    value = value.replace('â€“', '-').replace('â€”', '-').replace('Â·', '·').replace('â€¯', ' ')
    return value


def dump(serial, label):
    remote = f'/sdcard/audit_{label}.xml'
    run(['adb', '-s', serial, 'shell', 'uiautomator', 'dump', remote], f'Capture {label}')
    start = time.monotonic()
    result = subprocess.run(
        ['adb', '-s', serial, 'exec-out', 'cat', remote],
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
        f'command=MSYS_NO_PATHCONV=1 adb -s {serial} exec-out cat {remote}'
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
    folder = 'parent' if serial == PARENT else 'child'
    path = OUT / f'{folder}/{label}.txt'
    path.write_text('\n'.join(values) + '\n', encoding='utf-8')
    records.append(f'evidence={path.relative_to(ROOT)} retained_strings={len(values)}')
    return result.stdout, values


def bounds(xml, label, required=(), prefix=False):
    root = ET.fromstring(xml)
    for node in root.iter('node'):
        for attribute in ('content-desc', 'text'):
            value = clean(node.attrib.get(attribute, ''))
            matches = value.startswith(label) if prefix else (value == label or re.fullmatch(rf'{re.escape(label)} Tab \d+ of \d+', value) is not None)
            if matches and all(item in value for item in required):
                match = re.search(r'\[(\d+),(\d+)\]\[(\d+),(\d+)\]', node.attrib.get('bounds', ''))
                if match:
                    x1, y1, x2, y2 = map(int, match.groups())
                    return str((x1 + x2) // 2), str((y1 + y2) // 2)
    return None


def has(xml, label, required=(), prefix=False):
    return bounds(xml, label, required, prefix) is not None


def tap(serial, xml, label, note, required=(), prefix=False):
    point = bounds(xml, label, required, prefix)
    if point is None:
        raise RuntimeError(f'{serial} control not found: {label}')
    run(['adb', '-s', serial, 'shell', 'input', 'tap', *point], note)


def scroll_to(serial, xml, label, prefix, direction='down', limit=10):
    if has(xml, label):
        return xml
    for index in range(limit):
        gesture = ['540', '2000', '540', '500', '800'] if direction == 'down' else ['540', '500', '540', '2000', '800']
        run(['adb', '-s', serial, 'shell', 'input', 'swipe', *gesture], f'Scroll {direction} toward {label} {index + 1}')
        time.sleep(0.6)
        xml, _ = dump(serial, f'{prefix}_{index + 1}')
        if has(xml, label):
            return xml
    return xml


def tap_online_device(xml, note):
    online_seen = False
    for node in ET.fromstring(xml).iter('node'):
        node_values = [clean(node.attrib.get(attribute, '')) for attribute in ('content-desc', 'text')]
        if any(value.startswith('realme RMX2161') for value in node_values):
            online_seen = any('Online' in value for value in node_values)
            continue
        if online_seen and 'Open device' in node_values:
            match = re.search(r'\[(\d+),(\d+)\]\[(\d+),(\d+)\]', node.attrib.get('bounds', ''))
            if match:
                x1, y1, x2, y2 = map(int, match.groups())
                run(['adb', '-s', PARENT, 'shell', 'input', 'tap', str((x1 + x2) // 2), str((y1 + y2) // 2)], note)
                return
    raise RuntimeError('Open device control for the online Realme was not found')


def native_state(serial, label):
    services = run(['adb', '-s', serial, 'shell', 'dumpsys', 'activity', 'services', PACKAGE], f'{label} foreground services')
    camera = run(['adb', '-s', serial, 'shell', 'dumpsys', 'media.camera'], f'{label} native camera service')
    audio = run(['adb', '-s', serial, 'shell', 'dumpsys', 'audio'], f'{label} native audio service')
    mic = run(['adb', '-s', serial, 'shell', 'cmd', 'appops', 'get', PACKAGE, 'RECORD_AUDIO'], f'{label} microphone app-op mode')
    service_names = [name for name in ('GuardianService', 'LocationTrackingService', 'AudioAssistanceService') if name in services.stdout]
    blocks = re.findall(rf'- Package: {re.escape(PACKAGE)}(.*?)(?=\n  - Package:|\Z)', audio.stdout, flags=re.S)
    recording = any(re.search(r'Recording active:\s*true', block) for block in blocks)
    playback = any(re.search(r'Playback active:\s*true', block) for block in blocks)
    active_match = re.search(r'Active Camera Clients:\s*\[(.*?)\]', camera.stdout, flags=re.S)
    active_clients = active_match.group(1) if active_match else ''
    camera_open = bool(re.search(rf'Client Package Name: {re.escape(PACKAGE)}', active_clients))
    mic_mode = next((line.strip() for line in mic.stdout.splitlines() if line.strip().startswith('RECORD_AUDIO:')), 'unknown')
    summary = {
        'services': service_names,
        'camera_open': camera_open,
        'recording_active': recording,
        'playback_active': playback,
        'microphone_mode': mic_mode.split(';')[0],
    }
    records.append(f'{label}_native_summary=' + ';'.join(f'{key}={",".join(value) if isinstance(value, list) else str(value).lower()}' for key, value in summary.items()))
    return summary


def parent_audio_live(values):
    return any('Audio live' in value or 'One-way audio live' in value for value in values) and any('Media connected' in value for value in values)


def child_audio_live(values):
    return any('Microphone is live' in value or 'Microphone live' in value for value in values) and any('Media connected' in value for value in values)


def end_parent_session():
    xml, values = dump(PARENT, 'P53_cleanup_session_current')
    if not has(xml, 'End') and not any(value == 'Active' or value.startswith('Audio assistance') for value in values):
        records.append('cleanup_no_active_session_visible=true')
        return False
    if has(xml, 'End'):
        tap(PARENT, xml, 'End', 'Open end-session confirmation during cleanup')
    else:
        xml = scroll_to(PARENT, xml, 'End session', 'P53_cleanup_end_scroll')
        tap(PARENT, xml, 'End session', 'Open end-session confirmation during cleanup')
    time.sleep(0.8)
    xml, _ = dump(PARENT, 'P53_cleanup_end_confirmation')
    tap(PARENT, xml, 'End session', 'Confirm server-side session end during cleanup')
    time.sleep(6)


try:
    parent_pre = native_state(PARENT, 'pre_parent')
    child_pre = native_state(CHILD, 'pre_child')
    records.append('precondition=' + ('clean' if not parent_pre['camera_open'] and not child_pre['camera_open'] and not child_pre['recording_active'] and 'AudioAssistanceService' not in child_pre['services'] else 'not_clean'))

    xml, values = dump(PARENT, 'P53_navigation_start')
    if has(xml, 'Back') and not has(xml, 'Dashboard'):
        tap(PARENT, xml, 'Back', 'Leave prior non-shell Parent page')
        time.sleep(1)
        xml, values = dump(PARENT, 'P53_parent_shell')
    if not (has(xml, 'Dashboard') and has(xml, 'Devices')):
        run(['adb', '-s', PARENT, 'shell', 'monkey', '-p', PACKAGE, '-c', 'android.intent.category.LAUNCHER', '1'], 'Relaunch Parent app from launcher without changing the signed-in session')
        time.sleep(6)
        xml, values = dump(PARENT, 'P53_parent_relaunched')
    if not (has(xml, 'Dashboard') and has(xml, 'Devices')):
        raise RuntimeError('Parent shell was not restored after relaunch')
    if has(xml, 'Devices'):
        tap(PARENT, xml, 'Devices', 'Open Parent Devices tab')
        time.sleep(1)
        xml, values = dump(PARENT, 'P53_devices_tab')
    tap_online_device(xml, 'Open the current online Realme device')
    time.sleep(2)
    xml, values = dump(PARENT, 'P53_device_detail')
    xml = scroll_to(PARENT, xml, 'Remote assistance', 'P53_remote_entry_scroll')
    tap(PARENT, xml, 'Remote assistance', 'Open remote assistance')
    time.sleep(2)
    xml, values = dump(PARENT, 'P53_remote_assistance')
    tap(PARENT, xml, 'Request audio', 'Request audio assistance')
    time.sleep(1)
    xml, values = dump(PARENT, 'P53_audio_request_confirmation')
    tap(PARENT, xml, 'Send request', 'Send audio request; child media must remain off')
    time.sleep(3)
    xml, values = dump(PARENT, 'P53_waiting_for_child')
    native_state(CHILD, 'child_after_request_before_accept')

    xml, values = dump(CHILD, 'C53_child_initial')
    for index in range(2):
        if not any(value.startswith('Session ended') for value in values):
            break
        tap(CHILD, xml, 'Back', 'Leave prior ended child session')
        time.sleep(1)
        xml, values = dump(CHILD, f'C53_after_ended_session_{index + 1}')
    if has(xml, 'Review requests'):
        tap(CHILD, xml, 'Review requests', 'Review pending assistance request')
    elif has(xml, 'Requests'):
        tap(CHILD, xml, 'Requests', 'Open Child Requests tab')
    else:
        tap(CHILD, xml, 'Home', 'Open Child Home before Requests')
        time.sleep(1)
        xml, values = dump(CHILD, 'C53_child_home')
        tap(CHILD, xml, 'Requests', 'Open Child Requests tab')
    time.sleep(1)
    xml, values = dump(CHILD, 'C53_requests_tab')
    if not has(xml, 'Review and respond') and not has(xml, 'Accept'):
        tap(CHILD, xml, 'Refresh requests', 'Refresh Child requests')
        time.sleep(3)
        xml, values = dump(CHILD, 'C53_requests_refreshed')
    if has(xml, 'Review and respond'):
        tap(CHILD, xml, 'Review and respond', 'Review audio request')
        time.sleep(1)
        xml, values = dump(CHILD, 'C53_request_detail')
    xml = scroll_to(CHILD, xml, 'Accept', 'C53_accept_scroll')
    accept_label = 'Accept request' if has(xml, 'Accept request') else 'Accept'
    tap(CHILD, xml, accept_label, 'Open explicit Child consent confirmation')
    time.sleep(0.8)
    xml, values = dump(CHILD, 'C53_accept_confirmation')
    tap(CHILD, xml, 'Accept request' if has(xml, 'Accept request') else 'Accept', 'Record explicit Child consent; media must remain off before Join')
    time.sleep(2)
    native_state(CHILD, 'child_after_accept_before_join')
    xml, values = dump(CHILD, 'C53_join_card')
    xml = scroll_to(CHILD, xml, 'Join with microphone', 'C53_join_scroll')
    tap(CHILD, xml, 'Join with microphone', 'Open explicit microphone Join confirmation')
    time.sleep(0.8)
    xml, values = dump(CHILD, 'C53_join_confirmation')
    tap(CHILD, xml, 'Join now', 'Explicitly join with Child microphone only')
    time.sleep(4)

    parent_join_mode = 'unknown'
    for index in range(15):
        xml, values = dump(PARENT, f'P53_parent_ready_{index + 1:02d}')
        if has(xml, 'Listen to audio'):
            parent_join_mode = 'explicit_parent_join'
            tap(PARENT, xml, 'Listen to audio', 'Join as receive-only Parent')
            time.sleep(0.8)
            xml, values = dump(PARENT, 'P53_parent_join_confirmation')
            tap(PARENT, xml, 'Join now', 'Confirm receive-only Parent Join')
            break
        if parent_audio_live(values):
            parent_join_mode = 'automatic_receive_only_parent_join'
            break
        time.sleep(2)
    records.append('parent_join_mode=' + parent_join_mode)
    if parent_join_mode == 'unknown':
        raise RuntimeError('Parent neither exposed Listen to audio nor joined automatically')

    live_ready = False
    for index in range(20):
        _, parent_values = dump(PARENT, f'P53_live_wait_{index + 1:02d}')
        _, child_values = dump(CHILD, f'C53_live_wait_{index + 1:02d}')
        if parent_audio_live(parent_values) and child_audio_live(child_values):
            live_ready = True
            break
        time.sleep(2)
    if not live_ready:
        raise RuntimeError('Live audio markers did not appear on both endpoints')

    samples = []
    for index in range(3):
        _, parent_values = dump(PARENT, f'P53_audio_live_{index + 1:02d}')
        _, child_values = dump(CHILD, f'C53_audio_live_{index + 1:02d}')
        parent_state = native_state(PARENT, f'live_parent_{index + 1:02d}')
        child_state = native_state(CHILD, f'live_child_{index + 1:02d}')
        sample = {
            'parent_audio_live': parent_audio_live(parent_values),
            'child_microphone_live': child_audio_live(child_values),
            'parent_camera_open': parent_state['camera_open'],
            'parent_recording_active': parent_state['recording_active'],
            'child_camera_open': child_state['camera_open'],
            'child_recording_active': child_state['recording_active'],
            'child_audio_service': 'AudioAssistanceService' in child_state['services'],
        }
        samples.append(sample)
        records.append(f'live_sample_{index + 1:02d}=' + ';'.join(f'{key}={str(value).lower()}' for key, value in sample.items()))
        if index < 2:
            time.sleep(5)
    if not all(sample['parent_audio_live'] and sample['child_microphone_live'] and sample['child_recording_active'] and not sample['parent_recording_active'] and not sample['parent_camera_open'] and not sample['child_camera_open'] for sample in samples):
        raise RuntimeError('Audio live/native privacy invariants were not all satisfied')

    run(['adb', '-s', CHILD, 'shell', 'am', 'force-stop', PACKAGE], 'Abruptly terminate only the Child app during explicitly consented live audio')
    native_state(CHILD, 'child_after_force_stop_immediate')
    time.sleep(5)
    native_state(CHILD, 'child_after_force_stop_5s')
    xml, values = dump(PARENT, 'P53_parent_after_child_crash_5s')
    records.append(f'parent_audio_live_5s_after_child_crash={str(parent_audio_live(values)).lower()}')
    time.sleep(30)
    xml, values = dump(PARENT, 'P53_parent_after_child_crash_35s')
    records.append(f'parent_audio_live_35s_after_child_crash={str(parent_audio_live(values)).lower()}')
    time.sleep(60)
    xml, values = dump(PARENT, 'P53_parent_after_child_crash_95s')
    records.append(f'parent_audio_live_95s_after_child_crash={str(parent_audio_live(values)).lower()}')
    time.sleep(35)
    xml, values = dump(PARENT, 'P53_parent_after_child_crash_130s')
    stale_parent_live = parent_audio_live(values)
    records.append(f'parent_audio_live_130s_after_child_crash={str(stale_parent_live).lower()}')
    native_state(CHILD, 'child_after_crash_130s')

    tap(PARENT, xml, 'Back', 'Return from stranded session to remote assistance')
    time.sleep(2)
    xml, values = dump(PARENT, 'P53_remote_after_stranded_session')
    if not has(xml, 'Request audio'):
        xml = scroll_to(PARENT, xml, 'Request audio', 'P53_remote_after_crash_scroll')
    tap(PARENT, xml, 'Request audio', 'Attempt a new audio request while prior session is stranded')
    time.sleep(1)
    xml, values = dump(PARENT, 'P53_duplicate_request_confirmation')
    tap(PARENT, xml, 'Send request', 'Send duplicate request to observe server conflict behavior')
    time.sleep(6)
    xml, values = dump(PARENT, 'P53_duplicate_request_result')
    joined = '\n'.join(values)
    duplicate_rejected = any('active' in value.lower() and ('session' in value.lower() or 'request' in value.lower()) for value in values) or 'Request failed' in joined
    duplicate_pending = has(xml, 'Cancel')
    records.append(f'duplicate_request_rejected={str(duplicate_rejected).lower()}')
    records.append(f'duplicate_request_pending={str(duplicate_pending).lower()}')

    if duplicate_pending:
        tap(PARENT, xml, 'Cancel', 'Cancel any duplicate pending request before cleanup')
        time.sleep(1)
        xml, values = dump(PARENT, 'P53_duplicate_cancelled')
        if has(xml, 'Cancel request'):
            tap(PARENT, xml, 'Cancel request', 'Confirm duplicate request cancellation')
            time.sleep(3)
            xml, values = dump(PARENT, 'P53_duplicate_cancel_confirmed')
    if not has(xml, 'Tap to open'):
        tap(PARENT, xml, 'Back', 'Return to device detail to reopen stranded session')
        time.sleep(1)
        xml, values = dump(PARENT, 'P53_cleanup_device_detail')
        xml = scroll_to(PARENT, xml, 'Remote assistance', 'P53_cleanup_remote_scroll')
        tap(PARENT, xml, 'Remote assistance', 'Reopen remote assistance for stranded-session cleanup')
        time.sleep(2)
        xml, values = dump(PARENT, 'P53_cleanup_remote_assistance')
    xml = scroll_to(PARENT, xml, 'Tap to open', 'P53_cleanup_recent_scroll')
    tap(PARENT, xml, 'Tap to open', 'Open the stranded audio session for Parent-controlled cleanup')
    time.sleep(2)
    xml, values = dump(PARENT, 'P53_cleanup_stranded_session')
    end_parent_session()
    xml, values = dump(PARENT, 'P53_after_cleanup_end')
    parent_ended = any(value.startswith('Session ended') for value in values)

    run(['adb', '-s', CHILD, 'shell', 'monkey', '-p', PACKAGE, '-c', 'android.intent.category.LAUNCHER', '1'], 'Relaunch Child app after crash test to restore normal foreground services')
    time.sleep(8)
    xml, values = dump(CHILD, 'C53_child_relaunched_after_cleanup')
    parent_post = native_state(PARENT, 'post_parent')
    child_post = native_state(CHILD, 'post_child')
    capture_stopped = not child_post['recording_active'] and not child_post['camera_open'] and 'AudioAssistanceService' not in child_post['services']
    records.append(f'parent_ended_after_cleanup={str(parent_ended).lower()}')
    records.append(f'child_capture_stopped_after_cleanup={str(capture_stopped).lower()}')
    records.append(f'child_services_restored={str("GuardianService" in child_post["services"] and "LocationTrackingService" in child_post["services"]).lower()}')
    records.append('e12_result=' + ('PASS_WITH_STALE_UI_DEFECT' if capture_stopped and parent_ended and stale_parent_live and duplicate_rejected else 'REVIEW_REQUIRED'))
except Exception as caught:
    records.append(f'error={type(caught).__name__}: {caught}')
    try:
        run(['adb', '-s', CHILD, 'shell', 'am', 'force-stop', PACKAGE], 'Safety cleanup: guarantee Child capture is stopped')
        native_state(CHILD, 'error_cleanup_child')
        end_parent_session()
        native_state(PARENT, 'error_cleanup_parent')
    except Exception as cleanup_error:
        records.append(f'cleanup_error={type(cleanup_error).__name__}: {cleanup_error}')
    records.append('e12_result=SCRIPT_ERROR')
finally:
    try:
        run(['adb', '-s', CHILD, 'shell', 'monkey', '-p', PACKAGE, '-c', 'android.intent.category.LAUNCHER', '1'], 'Final safety cleanup: ensure Child app is relaunched')
        time.sleep(5)
        native_state(CHILD, 'final_child')
    except Exception as final_error:
        records.append(f'final_cleanup_error={type(final_error).__name__}: {final_error}')
    records.append(f'completed=true exit_code=0 duration_s={time.monotonic() - started_at:.3f}')
    LOG.write_text('\n'.join(records) + '\n', encoding='utf-8')
    print('\n'.join(records[-40:]))

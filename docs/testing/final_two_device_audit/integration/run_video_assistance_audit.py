#!/usr/bin/env python3
import html
import io
import math
import os
import re
import subprocess
import time
from pathlib import Path

from PIL import Image, ImageOps

ROOT = Path.cwd()
OUT = ROOT / 'docs/testing/final_two_device_audit'
LOG = OUT / 'integration/H01_video_assistance_flow_verified.log'
PARENT = 'emulator-5554'
CHILD = '5HXWRGQ4IFU8WS4T'
PACKAGE = 'com.parentcontrol.parent_control'
lines = []
started_at = time.monotonic()


def safe_output(args, output):
    if not args:
        return output
    if 'dumpsys' in args:
        service = args[args.index('dumpsys') + 1] if args.index('dumpsys') + 1 < len(args) else ''
        if service == 'activity':
            kept = [line for line in output.splitlines() if re.search(rf'ServiceRecord\{{[^}}]*{re.escape(PACKAGE)}/\.(?:GuardianService|LocationTrackingService|AudioAssistanceService)\}}|isForeground=|foregroundId=|\(nothing\)', line)]
            return '\n'.join(kept)
        if service == 'media.camera':
            kept = [line for line in output.splitlines() if re.search(rf'{re.escape(PACKAGE)}|Active Camera Clients:|== Camera device .* dynamic info:|== Camera Provider HAL|Device \d+ is (?:open|closed)', line)]
            return '\n'.join(kept)
        if service == 'audio':
            kept = []
            in_target_block = False
            for line in output.splitlines():
                if re.search(r'^\s*- Package:', line):
                    in_target_block = PACKAGE in line
                    kept.append(line if in_target_block else '  - Package: [OTHER PACKAGE]')
                if in_target_block and re.search(rf'{re.escape(PACKAGE)}|Playback active:|Recording active:|^\s*- Update time:', line):
                    kept.append(line)
                elif re.search(rf'rec (?:update|stop).*pack:{re.escape(PACKAGE)}', line):
                    kept.append(line)
            return '\n'.join(kept)
    if 'appops' in args:
        return '\n'.join(line.strip().split(';')[0] for line in output.splitlines() if re.match(r'\s*(?:CAMERA|RECORD_AUDIO):', line))
    return output


def run(args, note='', timeout=45):
    start = time.monotonic()
    result = subprocess.run(
        args,
        capture_output=True,
        encoding='utf-8',
        errors='replace',
        timeout=timeout,
        env={**os.environ, 'MSYS_NO_PATHCONV': '1'},
    )
    duration = time.monotonic() - start
    lines.append(
        f'[{time.strftime("%Y-%m-%dT%H:%M:%SZ", time.gmtime())}] '
        f'cwd={ROOT} exit={result.returncode} duration_s={duration:.3f} '
        f'command=' + ' '.join(args)
    )
    if note:
        lines.append('note=' + note)
    output = safe_output(args, result.stdout).strip()
    if output:
        lines.append('stdout=' + output)
    if result.stderr.strip():
        lines.append('stderr=' + result.stderr.strip())
    result.stdout = output
    return result


def clean(value):
    value = html.unescape(value)
    value = re.sub(r'\s+', ' ', value).strip()
    value = re.sub(r'-?\d{1,3}\.\d{3,}', '[REDACTED COORDINATE]', value)
    value = re.sub(r'[\w.+-]+@[\w.-]+\.[A-Za-z]{2,}', '[REDACTED EMAIL]', value)
    value = re.sub(r'\b(?:ankit1|ankit)\b', '[ACCOUNT]', value, flags=re.I)
    value = value.replace('â€“', '-').replace('â€”', '-').replace('Â·', '·').replace('â€¯', ' ')
    return value


SAFE_PREFIXES = (
    'Back', 'Refresh', 'Refresh requests', 'Home', 'Requests', 'Review requests', 'Waiting for you', 'Rules', 'Settings',
    'Remote assistance', 'Request audio', 'Request video', 'Assistance with explicit consent',
    'Audio and video come from', 'Recent sessions', 'Tap to open', 'Video', 'Active',
    'Waiting for consent', 'Waiting for the child', 'The child device is not sending video', 'Child consent', 'Recorded', 'Accepted', 'Session duration',
    'Requested', 'Elapsed', 'Relay not configured', 'No TURN relay',
    'Request video assistance?', 'Sending this request', 'Send request', 'Cancel',
    'Cancel request', 'Assistance session', 'This phone\'s camera', 'This app does not record',
    'You accepted this request', 'Ready when you are', 'Join with camera and microphone',
    'Accept', 'Decline', 'Review and respond', 'Linking requests', 'Assistance requests',
    'A parent is asking', 'Camera and microphone stay off', 'Accept this assistance request?',
    'Accepting records your consent', 'Start the live session?',
    'Your camera and microphone will be used', 'Join now', 'Stop sharing',
    'This turns off your camera', 'The session stays open', 'Media connected',
    'Connecting media', 'Video live', 'Video connecting', 'Camera and microphone are live',
    'Camera and microphone live', 'Camera and microphone are on', 'Camera and microphone starting',
    'Camera and microphone off', 'Starting the camera', 'Session ended', 'Request ended',
    'This session is over', 'No camera or microphone', 'End', 'End session', 'Ending stops video',
    'End assistance session?', 'This stops audio playback', 'Safety alerts',
)


def dump(serial, label):
    remote = f'/sdcard/audit_{label}.xml'
    run(['adb', '-s', serial, 'shell', 'uiautomator', 'dump', remote], label)
    start = time.monotonic()
    result = subprocess.run(
        ['adb', '-s', serial, 'exec-out', 'cat', remote],
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
        f'command=MSYS_NO_PATHCONV=1 adb -s {serial} exec-out cat {remote}'
    )
    lines.append(f'note=UI capture {label}')
    if result.returncode != 0:
        raise RuntimeError(result.stderr)
    values = []
    for raw in re.findall(r'(?:content-desc|text)="([^"]*)"', result.stdout):
        value = clean(raw)
        if value and value.startswith(SAFE_PREFIXES):
            values.append(value)
    values = list(dict.fromkeys(values))
    folder = 'parent' if serial == PARENT else 'child'
    path = OUT / folder / f'{label}.txt'
    path.write_text('\n'.join(values) + '\n', encoding='utf-8')
    renderer_classes = sorted(set(re.findall(r'class="([^"]*(?:TextureView|SurfaceView|RTCVideoView)[^"]*)"', result.stdout)))
    if renderer_classes:
        lines.append(f'{label}_renderer_classes=' + ','.join(renderer_classes))
    else:
        lines.append(f'{label}_renderer_classes=none')
    lines.append(f'evidence={path.relative_to(ROOT)} retained_strings={len(values)}')
    return result.stdout, values


def bounds(xml, label):
    for tag in re.findall(r'<node\b[^>]*>', xml):
        decoded = html.unescape(tag)
        label_pattern = rf'(?:content-desc|text)="(?:\d+\s+)?{re.escape(label)}(?: Tab \d of \d)?"'
        if re.search(label_pattern, decoded):
            found = re.search(r'bounds="\[(\d+),(\d+)\]\[(\d+),(\d+)\]"', decoded)
            if found:
                x1, y1, x2, y2 = map(int, found.groups())
                return (x1 + x2) // 2, (y1 + y2) // 2
    return None


def tap(serial, xml, label, note):
    point = bounds(xml, label)
    if not point:
        raise RuntimeError(f'{serial} control not found: {label}')
    run(['adb', '-s', serial, 'shell', 'input', 'tap', str(point[0]), str(point[1])], note)


def scroll_to(serial, xml, label, prefix, direction='down'):
    if bounds(xml, label):
        return xml
    for index in range(5):
        gesture = ['540', '1900', '540', '550'] if direction == 'down' else ['540', '550', '540', '1900']
        run(['adb', '-s', serial, 'shell', 'input', 'swipe', *gesture], f'Scroll {direction} toward {label} {index + 1}')
        time.sleep(0.7)
        xml, _ = dump(serial, f'{prefix}_{index + 1}')
        if bounds(xml, label):
            return xml
    return xml


def native_state(serial, label):
    services = run(
        ['adb', '-s', serial, 'shell', 'dumpsys', 'activity', 'services', PACKAGE],
        f'{label} foreground services',
    )
    camera = run(
        ['adb', '-s', serial, 'shell', 'dumpsys', 'media.camera'],
        f'{label} native camera service',
    )
    audio = run(
        ['adb', '-s', serial, 'shell', 'dumpsys', 'audio'],
        f'{label} native audio service',
    )
    mic = run(
        ['adb', '-s', serial, 'shell', 'cmd', 'appops', 'get', PACKAGE, 'RECORD_AUDIO'],
        f'{label} microphone app-op mode',
    )
    cam = run(
        ['adb', '-s', serial, 'shell', 'cmd', 'appops', 'get', PACKAGE, 'CAMERA'],
        f'{label} camera app-op mode',
    )
    service_names = [name for name in ('GuardianService', 'LocationTrackingService', 'AudioAssistanceService') if name in services.stdout]
    package_blocks = re.findall(
        rf'- Package: {re.escape(PACKAGE)}(.*?)(?=\n  - Package:|\Z)',
        audio.stdout,
        flags=re.S,
    )
    recording_active = any(re.search(r'Recording active:\s*true', block) for block in package_blocks)
    playback_active = any(re.search(r'Playback active:\s*true', block) for block in package_blocks)
    record_events = [
        line for line in audio.stdout.splitlines()
        if re.search(rf'rec (?:update|stop).*pack:{re.escape(PACKAGE)}', line)
    ]
    latest_recording = None
    if record_events:
        latest_recording = 'update' if 'rec update' in record_events[-1] else 'stop'
    open_camera_clients = []
    camera_section = camera.stdout.split('Active Camera Clients:', 1)[-1].split('== Camera Provider HAL', 1)[0]
    current_open_devices = sorted(set(re.findall(r'Device (\d+) is open', camera_section)))
    if re.search(rf'Client package: {re.escape(PACKAGE)}', camera_section):
        open_camera_clients = current_open_devices or ['unknown']
    mic_mode = next((line.strip() for line in mic.stdout.splitlines() if line.strip().startswith('RECORD_AUDIO:')), 'unknown')
    cam_mode = next((line.strip() for line in cam.stdout.splitlines() if line.strip().startswith('CAMERA:')), 'unknown')
    lines.append(
        f'{label} native_summary services={",".join(service_names) or "none"}; '
        f'camera_open_packages={len(open_camera_clients)}; recording_active={str(recording_active).lower()}; '
        f'latest_recording_event={latest_recording or "none"}; playback_active={str(playback_active).lower()}; '
        f'microphone_mode={mic_mode.split(";")[0]}; camera_mode={cam_mode.split(";")[0]}'
    )
    return {
        'services': service_names,
        'camera_open_packages': open_camera_clients,
        'recording_active': recording_active,
        'latest_recording': latest_recording,
        'playback_active': playback_active,
        'microphone_mode': mic_mode,
        'camera_mode': cam_mode,
    }


def video_pixel_metrics(xml, label):
    command = ['adb', '-s', PARENT, 'exec-out', 'screencap', '-p']
    start = time.monotonic()
    result = subprocess.run(
        command,
        capture_output=True,
        timeout=45,
        env={**os.environ, 'MSYS_NO_PATHCONV': '1'},
    )
    duration = time.monotonic() - start
    lines.append(
        f'[{time.strftime("%Y-%m-%dT%H:%M:%SZ", time.gmtime())}] '
        f'cwd={ROOT} exit={result.returncode} duration_s={duration:.3f} '
        f'command=' + ' '.join(command)
    )
    lines.append(f'note={label} in-memory pixel metrics only; image bytes discarded and no image file written')
    if result.returncode != 0:
        raise RuntimeError(result.stderr.decode('utf-8', errors='replace'))
    with Image.open(io.BytesIO(result.stdout)) as source:
        image = source.convert('RGB')
    width, height = image.size
    chip_top = None
    for tag in re.findall(r'<node\b[^>]*>', xml):
        decoded = html.unescape(tag)
        if 'Video live' not in decoded:
            continue
        found = re.search(r'bounds="\[(\d+),(\d+)\]\[(\d+),(\d+)\]"', decoded)
        if found:
            chip_top = int(found.group(2))
            break
    left, right = 48, max(49, width - 48)
    region_height = int((right - left) * 9 / 16)
    bottom = (chip_top - 24) if chip_top else min(height - 48, 1150)
    top = max(180, bottom - region_height)
    bottom = min(height - 32, top + region_height)
    if bottom <= top:
        raise RuntimeError('Could not derive a valid video region')
    region = image.crop((left, top, right, bottom))
    gray = ImageOps.grayscale(region)
    sampled = list(gray.resize((160, 90)).getdata())
    mean = sum(sampled) / len(sampled)
    variance = sum((value - mean) ** 2 for value in sampled) / len(sampled)
    bright_fraction = sum(value > 80 for value in sampled) / len(sampled)
    signature = list(gray.resize((64, 36)).getdata())
    metrics = {
        'width': width,
        'height': height,
        'region': [left, top, right, bottom],
        'mean_luma': round(mean, 3),
        'stddev_luma': round(math.sqrt(variance), 3),
        'bright_fraction': round(bright_fraction, 4),
        'signature': signature,
    }
    lines.append(
        f'{label} pixel_summary dimensions={width}x{height}; region={left},{top},{right},{bottom}; '
        f'mean_luma={mean:.3f}; stddev_luma={math.sqrt(variance):.3f}; bright_fraction={bright_fraction:.4f}'
    )
    return metrics


def end_from_parent():
    xml, _ = dump(PARENT, 'H01_cleanup_parent_current')
    if bounds(xml, 'End'):
        tap(PARENT, xml, 'End', 'Emergency end from app bar')
    else:
        xml = scroll_to(PARENT, xml, 'End session', 'H01_cleanup_end_scroll')
        tap(PARENT, xml, 'End session', 'Emergency end from session controls')
    time.sleep(0.8)
    xml, _ = dump(PARENT, 'H01_cleanup_end_confirmation')
    tap(PARENT, xml, 'End session', 'Confirm emergency server-confirmed end')
    time.sleep(8)


try:
    parent_pre = native_state(PARENT, 'pre_parent')
    child_pre = native_state(CHILD, 'pre_child')
    lines.append(
        'precondition=' + ('clean' if not parent_pre['camera_open_packages'] and not child_pre['camera_open_packages']
                           and not child_pre['recording_active'] and 'AudioAssistanceService' not in child_pre['services']
                           else 'not_clean')
    )
    xml, values = dump(PARENT, 'P45_navigation_start')
    existing_request = bounds(xml, 'Cancel') and 'Request expired' not in values
    if any(value.startswith('Session ended') for value in values):
        tap(PARENT, xml, 'Back', 'Return from ended session to remote assistance')
        time.sleep(1)
        xml, values = dump(PARENT, 'P45_after_ended_session')
    if bounds(xml, 'Cancel') and 'Request expired' in values:
        tap(PARENT, xml, 'Back', 'Leave expired request and create a fresh request')
        time.sleep(1)
        xml, _ = dump(PARENT, 'P45_after_expired_request')
    if bounds(xml, 'Safety alerts'):
        tap(PARENT, xml, 'Back', 'Return from safety alerts to device detail')
        time.sleep(1)
        xml, _ = dump(PARENT, 'P45_device_detail')
    if not existing_request:
        xml = scroll_to(PARENT, xml, 'Remote assistance', 'P45_remote_entry_scroll', direction='up')
        tap(PARENT, xml, 'Remote assistance', 'Open remote assistance')
        time.sleep(2)
        xml, _ = dump(PARENT, 'P45_remote_assistance')
        xml = scroll_to(PARENT, xml, 'Request video', 'P45_request_video_scroll')
        tap(PARENT, xml, 'Request video', 'Request video assistance')
        time.sleep(1)
        xml, _ = dump(PARENT, 'P45_video_request_confirmation')
        tap(PARENT, xml, 'Send request', 'Send video request; this must not open media')
        time.sleep(2)
        xml, _ = dump(PARENT, 'P45_waiting_for_child_consent')
    else:
        lines.append('request_source=existing_pending_request_from_prior_attempt; no duplicate request created')
    child_after_request = native_state(CHILD, 'child_after_request_before_accept')
    lines.append(f'after_request_camera_open={len(child_after_request["camera_open_packages"])} recording_active={str(child_after_request["recording_active"]).lower()}')

    xml, child_values = dump(CHILD, 'C31_child_home_before_request')
    for index in range(2):
        if not any(value.startswith('Session ended') for value in child_values):
            break
        tap(CHILD, xml, 'Back', 'Leave ended child session')
        time.sleep(1)
        xml, child_values = dump(CHILD, f'C31_after_ended_session_{index + 1}')
    if bounds(xml, 'Review requests'):
        tap(CHILD, xml, 'Review requests', 'Review the pending assistance request')
    else:
        tap(CHILD, xml, 'Requests', 'Open child Requests tab')
    time.sleep(1)
    xml, _ = dump(CHILD, 'C31_requests_tab')
    if not bounds(xml, 'Review and respond') and not bounds(xml, 'Accept'):
        tap(CHILD, xml, 'Refresh requests', 'Refresh child requests')
        time.sleep(3)
        xml, _ = dump(CHILD, 'C31_requests_tab_refreshed')
    if bounds(xml, 'Review and respond'):
        tap(CHILD, xml, 'Review and respond', 'Review the video request')
    elif bounds(xml, 'Accept'):
        pass
    else:
        raise RuntimeError('Child pending video request was not visible')
    time.sleep(1)
    xml, _ = dump(CHILD, 'C31_video_request_detail')
    xml = scroll_to(CHILD, xml, 'Accept', 'C31_accept_scroll')
    accept_label = 'Accept request' if bounds(xml, 'Accept request') else 'Accept'
    tap(CHILD, xml, accept_label, 'Open explicit consent confirmation')
    time.sleep(0.8)
    xml, _ = dump(CHILD, 'C31_accept_confirmation')
    tap(CHILD, xml, 'Accept request' if bounds(xml, 'Accept request') else 'Accept', 'Record child consent; media must remain off before Join')
    time.sleep(2)
    child_after_accept = native_state(CHILD, 'child_after_accept_before_join')
    lines.append(f'after_accept_camera_open={len(child_after_accept["camera_open_packages"])} recording_active={str(child_after_accept["recording_active"]).lower()}')
    xml, _ = dump(CHILD, 'C31_join_card')
    xml = scroll_to(CHILD, xml, 'Join with camera and microphone', 'C31_join_scroll')
    tap(CHILD, xml, 'Join with camera and microphone', 'Open explicit Join confirmation')
    time.sleep(0.8)
    xml, _ = dump(CHILD, 'C31_join_confirmation')
    tap(CHILD, xml, 'Join now', 'Explicitly join with child camera and microphone')
    time.sleep(4)

    parent_join_mode = 'unknown'
    for index in range(15):
        xml, values = dump(PARENT, f'P45_parent_ready_{index + 1:02d}')
        if bounds(xml, 'Start video session'):
            parent_join_mode = 'explicit_parent_join'
            tap(PARENT, xml, 'Start video session', 'Join as receive-only parent')
            time.sleep(0.8)
            xml, _ = dump(PARENT, 'P45_parent_join_confirmation')
            tap(PARENT, xml, 'Join now', 'Confirm receive-only parent Join')
            break
        if any('Video live' in value for value in values) or (any('Media connected' in value for value in values) and bounds(xml, 'End')):
            parent_join_mode = 'automatic_receive_only_parent_join'
            break
        time.sleep(2)
    if parent_join_mode == 'unknown':
        raise RuntimeError('Parent neither exposed Start video session nor joined automatically')
    lines.append('parent_join_mode=' + parent_join_mode)
    time.sleep(4)

    samples = []
    previous_signature = None
    live_ready = False
    for index in range(15):
        parent_xml, parent_values = dump(PARENT, f'P45_live_wait_{index + 1:02d}')
        child_xml, child_values = dump(CHILD, f'C31_live_wait_{index + 1:02d}')
        if any('Video live' in value for value in parent_values) and any('Camera and microphone are live' in value for value in child_values):
            live_ready = True
            break
        time.sleep(2)
    if not live_ready:
        raise RuntimeError('Live video markers did not appear on both endpoints')
    parent_xml, parent_values = dump(PARENT, 'P45_video_live_01')
    child_xml, child_values = dump(CHILD, 'C31_video_live_01')
    for index in range(3):
        parent_xml, parent_values = dump(PARENT, f'P45_video_live_{index + 1:02d}')
        child_xml, child_values = dump(CHILD, f'C31_video_live_{index + 1:02d}')
        parent_state = native_state(PARENT, f'live_parent_{index + 1:02d}')
        child_state = native_state(CHILD, f'live_child_{index + 1:02d}')
        frame = video_pixel_metrics(parent_xml, f'live_parent_frame_{index + 1:02d}')
        frame_delta = None
        if previous_signature is not None:
            frame_delta = sum(abs(a - b) for a, b in zip(previous_signature, frame['signature'])) / len(previous_signature)
        previous_signature = frame['signature']
        sample = {
            'parent_media_connected': any('Media connected' in value for value in parent_values),
            'parent_video_live': any('Video live' in value for value in parent_values),
            'parent_placeholder': any('child device is not sending video' in value for value in parent_values),
            'parent_renderer': bool(re.search(r'class="[^"]*(?:TextureView|SurfaceView|RTCVideoView)', parent_xml)),
            'parent_nonblack_frame': frame['stddev_luma'] > 15 and frame['bright_fraction'] > 0.10,
            'parent_frame_stddev': frame['stddev_luma'],
            'parent_frame_bright_fraction': frame['bright_fraction'],
            'parent_frame_delta': None if frame_delta is None else round(frame_delta, 3),
            'parent_camera_open': bool(parent_state['camera_open_packages']),
            'parent_recording': parent_state['recording_active'],
            'child_camera_live': any('Camera and microphone are live' in value for value in child_values),
            'child_media_connected': any('Media connected' in value for value in child_values),
            'child_camera_open': bool(child_state['camera_open_packages']),
            'child_recording': child_state['recording_active'],
            'child_audio_service': 'AudioAssistanceService' in child_state['services'],
        }
        samples.append(sample)
        lines.append(f'live_sample_{index + 1:02d}=' + ';'.join(f'{key}={str(value).lower()}' for key, value in sample.items()))
        if index < 2:
            time.sleep(10)

    xml, _ = dump(PARENT, 'P45_before_end')
    if bounds(xml, 'End'):
        tap(PARENT, xml, 'End', 'Open end-session confirmation')
    else:
        xml = scroll_to(PARENT, xml, 'End session', 'P45_end_scroll')
        tap(PARENT, xml, 'End session', 'Open end-session confirmation')
    time.sleep(0.8)
    xml, _ = dump(PARENT, 'P45_end_confirmation')
    tap(PARENT, xml, 'End session', 'End session for both participants')
    ended = False
    for index in range(12):
        time.sleep(2)
        parent_xml, parent_values = dump(PARENT, f'P45_ended_poll_{index + 1:02d}')
        child_xml, child_values = dump(CHILD, f'C31_ended_poll_{index + 1:02d}')
        if any(value.startswith('Session ended') for value in parent_values) and any(value.startswith('Session ended') for value in child_values):
            ended = True
            break
    parent_post = native_state(PARENT, 'post_parent')
    child_post = native_state(CHILD, 'post_child')
    lines.append(
        'teardown=' + ('verified' if ended and not parent_post['camera_open_packages'] and not child_post['camera_open_packages']
                       and not parent_post['recording_active'] and not child_post['recording_active']
                       and 'AudioAssistanceService' not in child_post['services'] else 'not_fully_verified')
    )
    lines.append(f'parent_live_ui_samples={sum(s["parent_media_connected"] and s["parent_video_live"] for s in samples)}/{len(samples)}')
    lines.append(f'child_live_ui_samples={sum(s["child_camera_live"] and s["child_media_connected"] for s in samples)}/{len(samples)}')
    lines.append(f'parent_camera_open_samples={sum(s["parent_camera_open"] for s in samples)}/{len(samples)}')
    lines.append(f'parent_recording_samples={sum(s["parent_recording"] for s in samples)}/{len(samples)}')
    lines.append(f'parent_nonblack_frame_samples={sum(s["parent_nonblack_frame"] for s in samples)}/{len(samples)}')
    lines.append(f'parent_renderer_samples={sum(s["parent_renderer"] for s in samples)}/{len(samples)}')
    lines.append(f'child_camera_open_samples={sum(s["child_camera_open"] for s in samples)}/{len(samples)}')
    lines.append(f'child_recording_samples={sum(s["child_recording"] for s in samples)}/{len(samples)}')
    lines.append('result=video flow attempted; inspect live samples, renderer evidence, native states, and teardown before assigning status')
except Exception as caught:
    lines.append(f'error={type(caught).__name__}: {caught}')
    try:
        state = native_state(CHILD, 'cleanup_child')
        if 'AudioAssistanceService' in state['services'] or state['camera_open_packages'] or state['recording_active']:
            end_from_parent()
            time.sleep(4)
            native_state(PARENT, 'cleanup_parent_after_end')
            native_state(CHILD, 'cleanup_child_after_end')
    except Exception as cleanup_error:
        lines.append(f'cleanup_error={type(cleanup_error).__name__}: {cleanup_error}')
    lines.append('result=script_error')
finally:
    lines.append(f'total_duration_s={time.monotonic() - started_at:.3f}')
    LOG.write_text('\n'.join(lines) + '\n', encoding='utf-8')
    print('\n'.join(lines[-35:]))

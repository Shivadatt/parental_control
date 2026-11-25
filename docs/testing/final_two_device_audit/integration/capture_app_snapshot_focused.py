#!/usr/bin/env python3
from pathlib import Path

source_path = Path('docs/testing/final_two_device_audit/integration/close_snapshot_audit_gaps.py')
prefix = source_path.read_text(encoding='utf-8').split("try:\n    xml, _ = dump('P46_resume_parent')", 1)[0]
exec(prefix, globals())
LOG = OUT / 'integration/H02_app_snapshot_focused.log'


def scroll(direction, note):
    gesture = ['540', '1900', '540', '1100', '500'] if direction == 'down' else ['540', '1100', '540', '1900', '500']
    run(['adb', '-s', PARENT, 'shell', 'input', 'swipe', *gesture], note)


try:
    xml, _ = dump('P47_audit_resume')
    if not has_label(xml, 'Audit & retention'):
        raise RuntimeError('Expected to resume from the audit page')
    back('Return to family page')
    time.sleep(0.7)
    back('Return to Parent dashboard')
    time.sleep(0.7)
    xml, _ = dump('P47_dashboard_parent')
    tap(xml, 'Devices', 'Select Parent devices tab')
    time.sleep(0.7)
    xml, _ = dump('P47_devices_tab_parent')
    for reveal_index in range(4):
        try:
            tap_online_device(xml, 'Open online realme device detail')
            break
        except RuntimeError:
            scroll('down', f'Reveal online device card {reveal_index + 1}')
            time.sleep(0.4)
            xml, _ = dump(f'P47_device_card_{reveal_index + 1}')
    else:
        raise RuntimeError('Online realme device action not found')
    time.sleep(0.7)
    xml, _ = dump('P47_device_detail_parent')
    xml = scroll_to(xml, 'App restrictions', 'P47_app_entry', direction='down', limit=7)
    tap(xml, 'App restrictions', 'Open app restrictions')
    time.sleep(0.7)
    xml, _ = dump('P47_app_restrictions_top')
    xml = scroll_to(xml, 'Installed apps', 'P47_apps_scroll', direction='down', limit=10)
    xml = scroll_to(xml, 'No app snapshot reported', 'P47_snapshot_scroll', direction='down', limit=4)
    dump('P47_app_snapshot_current')
    values = values_from(xml)
    lines.append('snapshot_title_visible=' + str(has_label(xml, 'Installed apps')).lower())
    lines.append('no_snapshot_message_visible=' + str(has_label(xml, 'No app snapshot reported')).lower())
    lines.append('snapshot_error_visible=' + str(any('snapshot unavailable' in value.lower() or 'could not load' in value.lower() for value in values)).lower())
    if not has_label(xml, 'Installed apps'):
        raise RuntimeError('Installed apps section was not captured')
    back('Return to device detail')
    time.sleep(0.7)
    back('Return to Parent shell')
    time.sleep(0.7)
    xml, _ = dump('P47_parent_shell_final')
    tap(xml, 'Dashboard', 'Leave Parent on dashboard tab')
    time.sleep(0.5)
    dump('P47_dashboard_final')
    lines.append('result=current installed-app snapshot section captured with short scroll steps')
except Exception as caught:
    lines.append(f'error={type(caught).__name__}: {caught}')
    lines.append('result=script_error')
finally:
    LOG.write_text('\n'.join(lines) + '\n', encoding='utf-8')
    print('\n'.join(lines[-30:]))

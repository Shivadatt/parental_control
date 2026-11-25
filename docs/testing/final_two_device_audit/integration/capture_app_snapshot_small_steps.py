#!/usr/bin/env python3
from pathlib import Path

source_path = Path('docs/testing/final_two_device_audit/integration/close_snapshot_audit_gaps.py')
prefix = source_path.read_text(encoding='utf-8').split("try:\n    xml, _ = dump('P46_resume_parent')", 1)[0]
exec(prefix, globals())
LOG = OUT / 'integration/H02_app_snapshot_small_steps_continued2.log'


def scroll(direction, note):
    gesture = ['540', '1800', '540', '1500', '350'] if direction == 'down' else ['540', '1500', '540', '1800', '350']
    run(['adb', '-s', PARENT, 'shell', 'input', 'swipe', *gesture], note)


try:
    xml, _ = dump('P48_app_restrictions_resume')
    if not has_label(xml, 'App restrictions') or not has_label(xml, 'Policy state'):
        if has_label(xml, 'App restrictions'):
            xml = scroll_to(xml, 'Policy state', 'P48_policy_return', direction='up', limit=12)
        else:
            raise RuntimeError('Expected to resume from App restrictions')
    dump('P48_policy_top')
    for index in range(16):
        if has_label(xml, 'Installed apps'):
            break
        scroll('down', f'Small scroll toward Installed apps {index + 1}')
        time.sleep(0.35)
        xml, _ = dump(f'P48_apps_step_{index + 1:02d}')
    if not has_label(xml, 'Installed apps'):
        raise RuntimeError('Installed apps section not found after small scroll steps')
    xml = scroll_to(xml, 'No app snapshot reported', 'P48_snapshot_step', direction='down', limit=4)
    dump('P48_app_snapshot_current')
    values = values_from(xml)
    lines.append('snapshot_title_visible=' + str(has_label(xml, 'Installed apps')).lower())
    lines.append('no_snapshot_message_visible=' + str(has_label(xml, 'No app snapshot reported')).lower())
    lines.append('snapshot_error_visible=' + str(any('snapshot unavailable' in value.lower() or 'could not load' in value.lower() for value in values)).lower())
    back('Return to device detail')
    time.sleep(0.7)
    back('Return to Parent shell')
    time.sleep(0.7)
    xml, _ = dump('P48_parent_shell_final')
    tap(xml, 'Dashboard', 'Leave Parent on dashboard tab')
    time.sleep(0.5)
    dump('P48_dashboard_final')
    lines.append('result=installed-app snapshot section captured with 300-pixel scroll steps')
except Exception as caught:
    lines.append(f'error={type(caught).__name__}: {caught}')
    lines.append('result=script_error')
finally:
    LOG.write_text('\n'.join(lines) + '\n', encoding='utf-8')
    print('\n'.join(lines[-30:]))

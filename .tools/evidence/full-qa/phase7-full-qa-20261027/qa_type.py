"""Reliable text entry for the realme: types in small chunks and verifies the
field content via the uiautomator hierarchy, retrying until it matches.
`adb shell input text` drops characters on this device under the soft keyboard.
"""
import qa_ui as q
import time

S = '5HXWRGQ4IFU8WS4T'


def dump_app(retries=6):
    """Dump the hierarchy, dismissing the Google autofill overlay that steals
    the window on this device and makes the app's nodes disappear."""
    import re
    for _ in range(retries):
        x = q.hierarchy(S)
        pk = set(re.findall(r'package="([^"]+)"', x))
        if 'com.parentcontrol.parent_control' in pk:
            return x
        if 'com.google.android.gms' in pk:
            q.adb(S, 'shell', 'input', 'keyevent', '4')
            time.sleep(1.2)
            continue
        time.sleep(1.0)
    return ""


def edits(retries=6):
    for _ in range(retries):
        e = [n for n in q.nodes(dump_app()) if 'Edit' in n['class']]
        if e:
            return e
        time.sleep(1.2)
    return []


def field(idx, retries=6):
    e = edits(retries)
    return e[idx] if idx < len(e) else None


def clear(idx, n=80):
    f = field(idx)
    if not f:
        return
    q.adb(S, 'shell', 'input', 'tap', str(f['x']), str(f['y']))
    time.sleep(1.0)
    q.clear_field(S, n)


def type_verified(idx, value, tries=4, chunk=3, gap=0.12):
    for attempt in range(tries):
        clear(idx, len(value) + 25)
        f = field(idx)
        q.adb(S, 'shell', 'input', 'tap', str(f['x']), str(f['y']))
        time.sleep(1.0)
        for i in range(0, len(value), chunk):
            q.adb(S, 'shell', "input text '" + value[i:i + chunk] + "'")
            time.sleep(gap)
        time.sleep(0.6)
        f = field(idx)
        got = f['text'] if f else ''
        if idx == 1:  # password field is masked -> compare bullet count
            ok = len(got) == len(value)
        else:
            ok = got == value
        print(f'  field{idx} attempt{attempt+1}: match={ok} (len {len(got)})')
        if ok:
            return True
    return False


def tap_text(label, occurrence=0, retries=5):
    ns = []
    for _ in range(retries):
        ns = [n for n in q.nodes(dump_app()) if n['text'] == label and n['clickable']]
        if ns:
            break
        time.sleep(1.2)
    if not ns:
        print('!! label not found:', label)
        return False
    n = ns[occurrence] if occurrence < len(ns) else ns[-1]
    q.adb(S, 'shell', 'input', 'tap', str(n['x']), str(n['y']))
    return True


def dismiss_error(label='Dismiss'):
    if tap_text(label):
        time.sleep(1.0)
        return True
    return False

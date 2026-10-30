#!/usr/bin/env python3
"""QA UI helper: dump uiautomator hierarchy, tap by text/id, screenshot.
Read-only against the app; does not modify project sources.
"""
import os, re, subprocess, sys, time
import xml.etree.ElementTree as ET

ENV = dict(os.environ, MSYS_NO_PATHCONV="1", MSYS2_ARG_CONV_EXCL="*")
EVID = os.path.dirname(os.path.abspath(__file__))
_seq = {}


def adb(serial, *args, timeout=30):
    return subprocess.run(["adb", "-s", serial, *args], capture_output=True,
                          text=True, encoding="utf-8", errors="replace",
                          env=ENV, timeout=timeout)


def next_n(prefix="shot"):
    key = prefix
    _seq[key] = _seq.get(key, 0) + 1
    return f"{prefix}-{_seq[key]:03d}"


def shot(serial, name):
    if not name.endswith(".png"):
        name += ".png"
    path = os.path.join(EVID, name)
    r = subprocess.run(["adb", "-s", serial, "exec-out", "screencap", "-p"],
                       capture_output=True, env=ENV, timeout=60)
    with open(path, "wb") as f:
        f.write(r.stdout)
    print(f"SHOT {name} ({len(r.stdout)} bytes)")
    return path


def hierarchy(serial, name=None, retries=4):
    """Dump the hierarchy, deleting the stale file first so failures are visible.

    uiautomator dump intermittently returns nothing useful while a window or
    animation is settling, so retry with a short backoff.
    """
    xml = ""
    for attempt in range(retries):
        adb(serial, "shell", "rm", "-f", "/sdcard/ui_dump.xml")
        time.sleep(0.25)
        r = adb(serial, "shell", "uiautomator", "dump", "/sdcard/ui_dump.xml")
        if "dumped to" in (r.stdout or ""):
            xml = adb(serial, "shell", "cat", "/sdcard/ui_dump.xml").stdout
            if xml.lstrip().startswith("<?xml") and xml.count("<node") > 0:
                break
        time.sleep(0.9 + attempt * 0.5)
    if name:
        with open(os.path.join(EVID, name if name.endswith(".xml") else name + ".xml"),
                  "w", encoding="utf-8") as f:
            f.write(xml)
    return xml


def nodes(xml):
    out = []
    try:
        root = ET.fromstring(xml)
    except Exception:
        return out
    for el in root.iter("node"):
        a = el.attrib
        b = a.get("bounds", "")
        m = re.findall(r"\[(-?\d+),(-?\d+)\]", b)
        cx = cy = 0
        if len(m) == 2:
            x1, y1 = map(int, m[0]); x2, y2 = map(int, m[1])
            cx, cy = (x1 + x2) // 2, (y1 + y2) // 2
        out.append({
            "text": a.get("text", ""), "desc": a.get("content-desc", ""),
            "rid": a.get("resource-id", ""), "class": a.get("class", ""),
            "clickable": a.get("clickable") == "true",
            "enabled": a.get("enabled") == "true",
            "x": cx, "y": cy, "bounds": b,
        })
    return out


def listing(serial, name=None, grep=None):
    xml = hierarchy(serial, name)
    ns = nodes(xml)
    for n in ns:
        label = n["text"] or n["desc"]
        if not label:
            continue
        if grep and grep.lower() not in label.lower():
            continue
        print(f'  ({n["x"]},{n["y"]}) {"[TAP]" if n["clickable"] else "     "} '
              f'{"[off]" if not n["enabled"] else "     "} {n["class"].split(".")[-1]:12} {label[:95]!r}')
    return ns


def find(serial, needle, kind="contains"):
    ns = nodes(hierarchy(serial))
    needle_l = needle.lower()
    cands = []
    for n in ns:
        label = (n["text"] or n["desc"]).strip()
        if not label:
            continue
        ok = (needle_l in label.lower()) if kind == "contains" else (label.lower() == needle_l)
        if ok:
            cands.append(n)
    return cands


def tap(serial, needle, exact=False, wait=1.2, index=0, prefer_clickable=True):
    cands = find(serial, needle, "exact" if exact else "contains")
    if not cands:
        print(f"!! not found: {needle!r}")
        return False
    ordered = [c for c in cands if c["clickable"]] or cands
    picked = ordered[index] if index < len(ordered) else ordered[-1]
    if prefer_clickable and not picked["clickable"]:
        print(f"   note: target not clickable, tapping anyway at ({picked['x']},{picked['y']})")
    print(f"TAP {needle!r} -> ({picked['x']},{picked['y']}) {picked['text'] or picked['desc']!r}")
    adb(serial, "shell", "input", "tap", str(picked["x"]), str(picked["y"]))
    time.sleep(wait)
    return True


def swipe(serial, x1, y1, x2, y2, dur=350):
    adb(serial, "shell", "input", "swipe", str(x1), str(y1), str(x2), str(y2), str(dur))
    time.sleep(1)


def scroll_to(serial, needle, max_scrolls=6):
    for i in range(max_scrolls):
        if find(serial, needle):
            return True
        w, h = size(serial)
        swipe(serial, w // 2, int(h * 0.72), w // 2, int(h * 0.28))
    return bool(find(serial, needle))


_size_cache = {}


def size(serial):
    if serial in _size_cache:
        return _size_cache[serial]
    r = adb(serial, "shell", "wm", "size")
    m = re.search(r"(\d+)x(\d+)", r.stdout)
    v = (int(m.group(1)), int(m.group(2))) if m else (1080, 2400)
    _size_cache[serial] = v
    return v


def text(serial, s):
    """Type ASCII text via adb input text."""
    adb(serial, "shell", "input", "text", s)
    time.sleep(0.5)


def clear_field(serial, taps=12):
    adb(serial, "shell", "input", "keyevent", "KEYCODE_MOVE_END")
    for _ in range(taps):
        adb(serial, "shell", "input", "keyevent", "KEYCODE_DEL")


def back(serial, wait=1.0):
    adb(serial, "shell", "input", "keyevent", "KEYCODE_BACK")
    time.sleep(wait)


def resumed(serial):
    r = adb(serial, "shell", "dumpsys", "activity", "activities")
    hits = re.findall(r"(mResumedActivity.*|mFocusedApp.*)", r.stdout)
    return "\n".join(h.strip() for h in hits)


if __name__ == "__main__":
    cmd = sys.argv[1]
    serial = sys.argv[2]
    if cmd == "ls":
        listing(serial, sys.argv[3] if len(sys.argv) > 3 else None,
                sys.argv[4] if len(sys.argv) > 4 else None)
    elif cmd == "tap":
        tap(serial, sys.argv[3], exact=(len(sys.argv) > 4 and sys.argv[4] == "exact"))
    elif cmd == "shot":
        shot(serial, sys.argv[3])
    elif cmd == "scrollto":
        print(scroll_to(serial, sys.argv[3]))
    elif cmd == "resumed":
        print(resumed(serial))
    elif cmd == "find":
        for c in find(serial, sys.argv[3]):
            print(c["bounds"], c["clickable"], repr(c["text"] or c["desc"]))

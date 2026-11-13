#!/usr/bin/env python
import re, html, sys, subprocess, os

dev, folder, name = sys.argv[1], sys.argv[2], sys.argv[3]
base = "docs/testing/final_two_device_audit/%s" % folder
remote = "/sdcard/u_%s.xml" % name
local = os.path.join(base, name + ".xml")
subprocess.run(["adb", "-s", dev, "shell", "uiautomator", "dump", remote], capture_output=True)
subprocess.run(["adb", "-s", dev, "pull", remote, local], capture_output=True)
subprocess.run(["adb", "-s", dev, "exec-out", "screencap", "-p"],
               stdout=open(os.path.join(base, name + ".png"), "wb"))
s = open(local, encoding="utf-8").read()
for m in re.finditer(r'<node\b[^>]*>', s):
    t = m.group(0)
    d = re.search(r'content-desc="([^"]*)"', t)
    x = re.search(r'text="([^"]*)"', t)
    b = re.search(r'bounds="([^"]*)"', t)
    lbl = html.unescape((d.group(1) if d else "") or (x.group(1) if x else "")).strip()
    if not lbl:
        continue
    cx = cy = ""
    if b:
        g = re.match(r"\[(\d+),(\d+)\]\[(\d+),(\d+)\]", b.group(1))
        if g:
            cx = (int(g.group(1)) + int(g.group(3))) // 2
            cy = (int(g.group(2)) + int(g.group(4))) // 2
    print("%-56s | %s | %s,%s" % (lbl[:56].replace("\n", "\\n"), b.group(1) if b else "", cx, cy))

#!/bin/bash
# Usage: dump.sh <serial> <out.xml>
set -e
S="$1"; OUT="$2"
MSYS_NO_PATHCONV=1 adb -s "$S" shell uiautomator dump /sdcard/ui.xml >/dev/null 2>&1
MSYS_NO_PATHCONV=1 adb -s "$S" shell cat /sdcard/ui.xml > "$OUT"
node -e '
const fs=require("fs");
const x=fs.readFileSync(process.argv[1],"utf8");
const re=/<node[^>]*>/g;let m;
while((m=re.exec(x))){
  const t=/text="([^"]*)"/.exec(m[0]);
  const c=/content-desc="([^"]*)"/.exec(m[0]);
  const b=/bounds="([^"]*)"/.exec(m[0]);
  const v=[t&&t[1],c&&c[1]].filter(Boolean).join(" | ");
  if(v.trim()) console.log(v, b?b[1]:"");
}' "$OUT"

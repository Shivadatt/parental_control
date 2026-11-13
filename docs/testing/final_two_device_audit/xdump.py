import io
import re
import sys

xml_path, txt_path = sys.argv[1], sys.argv[2]
s = io.open(xml_path, encoding="utf-8").read()
lines = []
for m in re.finditer(r'(?:content-desc|text)="([^"]*)"', s):
    t = m.group(1)
    for a, b in (
        ("&#10;", " | "),
        ("&#8239;", " "),
        ("&#8217;", "'"),
        ("&#8211;", "-"),
        ("&amp;", "&"),
        ("&lt;", "<"),
        ("&gt;", ">"),
    ):
        t = t.replace(a, b)
    t = re.sub(r"\s+", " ", t).strip()
    if t:
        lines.append(t)
io.open(txt_path, "w", encoding="utf-8").write("\n".join(lines) + "\n")
print(f"{len(lines)} strings -> {txt_path}")

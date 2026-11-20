import os

base = r"C:\Users\ASUS\.gemini\antigravity\brain\5bf6b230-ca23-4e0f-a559-554a1904a50a\.system_generated\steps"
screenshots = []
for root, dirs, files in os.walk(base):
    for f in files:
        if f.endswith(".png") or f.endswith(".jpg"):
            p = os.path.join(root, f)
            screenshots.append((p, os.path.getsize(p)))

print(f"Total screenshots found: {len(screenshots)}")
for p, s in screenshots:
    print(f"{p} ({s} bytes)")

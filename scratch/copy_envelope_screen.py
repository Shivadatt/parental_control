import os
import shutil

dest_dir = r"D:\parentcontrol_app\docs\testing\phase_3_4_5_editor_transfer_recovery\screenshots"
os.makedirs(dest_dir, exist_ok=True)

src = r"C:\Users\ASUS\.gemini\antigravity\brain\5bf6b230-ca23-4e0f-a559-554a1904a50a\.system_generated\steps\778\media_0.png"
dst = os.path.join(dest_dir, "01_shared_envelope_ts_complete_lines_90_111.png")
if os.path.exists(src):
    shutil.copy2(src, dst)
    print(f"Copied shared-envelope screenshot: {os.path.getsize(dst)} bytes")
else:
    print(f"Source not found at {src}")

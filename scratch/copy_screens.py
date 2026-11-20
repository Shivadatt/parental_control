import os
import shutil

dest_dir = r"D:\parentcontrol_app\docs\testing\phase_3_4_4_account_browser_deployment\screenshots"
os.makedirs(dest_dir, exist_ok=True)

src3 = r"C:\Users\ASUS\.gemini\antigravity\brain\5bf6b230-ca23-4e0f-a559-554a1904a50a\.system_generated\steps\567\media_0.png"
dst3 = os.path.join(dest_dir, "03_functions_list_post_deployment_attempt.png")
if os.path.exists(src3):
    shutil.copy2(src3, dst3)
    print(f"Copied 03: {os.path.getsize(dst3)} bytes")

for f in sorted(os.listdir(dest_dir)):
    p = os.path.join(dest_dir, f)
    print(f"{f}: {os.path.getsize(p)} bytes")

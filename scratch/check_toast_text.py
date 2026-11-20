import json

path = r"C:\Users\ASUS\.gemini\antigravity\brain\5bf6b230-ca23-4e0f-a559-554a1904a50a\.system_generated\logs\transcript.jsonl"
with open(path, "r", encoding="utf-8") as f:
    lines = f.readlines()

for line in lines:
    d = json.loads(line)
    step = d.get("step_index")
    if step in [505, 507, 508, 511]:
        print(f"=== Step {step} ===")
        c = d.get("content", "")
        # Look for toast or alert or error in content
        for l in c.split("\n"):
            if any(k in l.lower() for k in ["alert", "toast", "error", "fail", "deploy", "region", "notification"]):
                print("  ", l)

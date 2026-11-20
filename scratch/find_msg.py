import json

path = r"C:\Users\ASUS\.gemini\antigravity\brain\5bf6b230-ca23-4e0f-a559-554a1904a50a\.system_generated\logs\transcript.jsonl"
with open(path, "r", encoding="utf-8") as f:
    lines = f.readlines()

for line in lines:
    d = json.loads(line)
    if d.get("source") == "SYSTEM" and d.get("type") == "SYSTEM_MESSAGE":
        c = d.get("content", "")
        if "shared-envelope" in c:
            print(f"Step {d.get('step_index')}: {len(c)} chars")
            print(c[-500:])

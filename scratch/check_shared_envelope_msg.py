import json

path = r"C:\Users\ASUS\.gemini\antigravity\brain\5bf6b230-ca23-4e0f-a559-554a1904a50a\.system_generated\logs\transcript.jsonl"
with open(path, "r", encoding="utf-8") as f:
    lines = f.readlines()

for line in lines:
    d = json.loads(line)
    step = d.get("step_index")
    c = d.get("content", "")
    if "shared-envelope" in c and d.get("source") == "USER_EXPLICIT":
        print(f"Step {step} USER_EXPLICIT: length {len(c)}")
        print(c[-500:])

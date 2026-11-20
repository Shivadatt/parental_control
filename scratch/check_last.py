import json

path = r"C:\Users\ASUS\.gemini\antigravity\brain\5bf6b230-ca23-4e0f-a559-554a1904a50a\.system_generated\logs\transcript.jsonl"

with open(path, "r", encoding="utf-8") as f:
    lines = f.readlines()

print(f"Total lines: {len(lines)}")
last = json.loads(lines[-1])
print(f"Last step {last.get('step_index')}: {last.get('source')}, {last.get('type')}, status={last.get('status')}")

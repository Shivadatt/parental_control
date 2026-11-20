import json

path = r"C:\Users\ASUS\.gemini\antigravity\brain\5bf6b230-ca23-4e0f-a559-554a1904a50a\.system_generated\logs\transcript.jsonl"
with open(path, "r", encoding="utf-8") as f:
    lines = f.readlines()

types = set()
for line in lines:
    d = json.loads(line)
    types.add((d.get("source"), d.get("type")))
print("Sources and types:", types)

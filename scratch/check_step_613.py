import json

path = r"C:\Users\ASUS\.gemini\antigravity\brain\5bf6b230-ca23-4e0f-a559-554a1904a50a\.system_generated\logs\transcript.jsonl"

with open(path, "r", encoding="utf-8") as f:
    lines = f.readlines()

for l in lines:
    d = json.loads(l)
    step = d.get("step_index", 0)
    if step == 613:
        c = d.get("content", "")
        # print all lines in the snapshot that have numbers or code
        for line in c.split("\n"):
            if any(k in line for k in ["uid=243_", "uid=47_", "handleAccountRequest", "608", "641", "export", "deletion.ts"]):
                print(line)

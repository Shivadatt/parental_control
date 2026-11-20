import json

path = r"C:\Users\ASUS\.gemini\antigravity\brain\5bf6b230-ca23-4e0f-a559-554a1904a50a\.system_generated\logs\transcript.jsonl"

with open(path, "r", encoding="utf-8") as f:
    lines = f.readlines()

for l in lines[-5:]:
    d = json.loads(l)
    step = d.get("step_index", 0)
    t = d.get("type")
    print(f"Step {step}: ({d.get('source')}, {t})")
    if "content" in d and d["content"] and t != "EPHEMERAL_MESSAGE":
        print(d["content"][:300])

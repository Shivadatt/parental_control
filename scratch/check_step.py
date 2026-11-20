import json

path = r"C:\Users\ASUS\.gemini\antigravity\brain\5bf6b230-ca23-4e0f-a559-554a1904a50a\.system_generated\logs\transcript.jsonl"
with open(path, "r", encoding="utf-8") as f:
    lines = f.readlines()

for line in lines[-5:]:
    d = json.loads(line)
    step = d.get("step_index")
    print(f"Step {step}:")
    if "content" in d and d["content"]:
        print(d["content"][:400])

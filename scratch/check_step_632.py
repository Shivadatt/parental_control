import json

path = r"C:\Users\ASUS\.gemini\antigravity\brain\5bf6b230-ca23-4e0f-a559-554a1904a50a\.system_generated\logs\transcript.jsonl"

with open(path, "r", encoding="utf-8") as f:
    lines = f.readlines()

for l in lines:
    d = json.loads(l)
    step = d.get("step_index", 0)
    if step in [630, 631, 632, 633, 634, 635, 636]:
        print(f"=== Step {step} ===")
        if "tool_calls" in d:
            print("Tool calls:", d["tool_calls"])
        if "content" in d and d["content"]:
            print("Content:", d["content"][:300])

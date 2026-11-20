import json

path = r"C:\Users\ASUS\.gemini\antigravity\brain\5bf6b230-ca23-4e0f-a559-554a1904a50a\.system_generated\logs\transcript.jsonl"

with open(path, "r", encoding="utf-8") as f:
    lines = f.readlines()

for l in lines[-10:]:
    d = json.loads(l)
    step = d.get("step_index", 0)
    t = d.get("type")
    if t == "PLANNER_RESPONSE":
        print(f"=== Step {step} ===")
        if "thinking" in d and d["thinking"]:
            print("Thinking:", d["thinking"][:250])
        if "tool_calls" in d:
            print("Tools:", [tc.get("name") for tc in d["tool_calls"]])

import json

path = r"C:\Users\ASUS\.gemini\antigravity\brain\5bf6b230-ca23-4e0f-a559-554a1904a50a\.system_generated\logs\transcript.jsonl"
with open(path, "r", encoding="utf-8") as f:
    lines = f.readlines()

for line in lines[-15:]:
    d = json.loads(line)
    step = d.get("step_index")
    t = d.get("type")
    print(f"=== Step {step} ({t}) ===")
    if t == "PLANNER_RESPONSE":
        if "thinking" in d and d["thinking"]:
            print("Thinking:", d["thinking"][:300])
        if "tool_calls" in d:
            print("Tool calls:", [tc.get("name") for tc in d["tool_calls"]])
    elif t == "GENERIC":
        c = d.get("content", "")
        for l in c.split("\n"):
            if any(k in l.lower() for k in ["post", "functions", "deploy", "200", "400", "500", "status", "slug"]):
                print("  ", l[:120])

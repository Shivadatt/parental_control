import json

path = r"C:\Users\ASUS\.gemini\antigravity\brain\5bf6b230-ca23-4e0f-a559-554a1904a50a\.system_generated\logs\transcript.jsonl"

with open(path, "r", encoding="utf-8") as f:
    lines = f.readlines()

print(f"Total steps: {len(lines)}")
for l in lines:
    d = json.loads(l)
    step = d.get("step_index", 0)
    if step >= 580:
        if d.get("type") == "PLANNER_RESPONSE":
            tcs = d.get("tool_calls", [])
            for tc in tcs:
                name = tc.get("name")
                args = tc.get("args", {})
                summary = args.get("toolSummary", "")
                p = args.get("Path", "")
                val = args.get("value", "")
                text = args.get("text", "")
                print(f"Step {step}: {name} | summary='{summary}' | Path='{p}' | text='{text}'")
        elif d.get("type") == "MODEL" and d.get("content"):
            c = d.get("content", "")
            if "media" in c or "screenshot" in c.lower():
                print(f"Step {step}: [Screenshot taken]")

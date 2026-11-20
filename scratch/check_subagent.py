import json

path = r"C:\Users\ASUS\.gemini\antigravity\brain\5bf6b230-ca23-4e0f-a559-554a1904a50a\.system_generated\logs\transcript.jsonl"
with open(path, "r", encoding="utf-8") as f:
    lines = f.readlines()

print(f"Total entries: {len(lines)}")
for line in lines[-10:]:
    d = json.loads(line)
    step = d.get("step_index")
    source = d.get("source")
    t = d.get("type")
    print(f"Step {step}: {source}, {t}")
    if t == "PLANNER_RESPONSE":
        if "content" in d and d["content"]:
            print(f"  Content: {d['content'][:300]}")
        if "tool_calls" in d:
            print(f"  Tool calls: {d['tool_calls']}")

import json
import time

path = r"C:\Users\ASUS\.gemini\antigravity\brain\5bf6b230-ca23-4e0f-a559-554a1904a50a\.system_generated\logs\transcript.jsonl"

def check():
    with open(path, "r", encoding="utf-8") as f:
        lines = f.readlines()
    last = json.loads(lines[-1])
    print(f"Total lines: {len(lines)}, Last step {last.get('step_index')}: {last.get('source')}, {last.get('type')}")
    # Print recent planner responses
    for l in lines[-10:]:
        d = json.loads(l)
        if d.get("type") == "PLANNER_RESPONSE":
            tc = [t.get("name") for t in d.get("tool_calls", [])]
            content = d.get("content", "")[:120] if d.get("content") else ""
            print(f"  Step {d.get('step_index')}: tools={tc} {content}")

check()

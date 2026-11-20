import json
import time

path = r"C:\Users\ASUS\.gemini\antigravity\brain\5bf6b230-ca23-4e0f-a559-554a1904a50a\.system_generated\logs\transcript.jsonl"

for i in range(5):
    with open(path, "r", encoding="utf-8") as f:
        lines = f.readlines()
    last = json.loads(lines[-1])
    print(f"Check {i}: Total {len(lines)}, Last step {last.get('step_index')}: {last.get('type')}")
    if last.get("type") == "PLANNER_RESPONSE" and "content" in last and last.get("content"):
        print("Final content:")
        print(last["content"])
        break
    time.sleep(3)

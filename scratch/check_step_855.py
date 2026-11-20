import json

path = r"C:/Users/ASUS/.gemini/antigravity/brain/5bf6b230-ca23-4e0f-a559-554a1904a50a/.system_generated/logs/transcript.jsonl"
with open(path, "r", encoding="utf-8") as f:
    for line in f:
        data = json.loads(line)
        idx = data.get("step_index")
        if idx and idx >= 880:
            print(f"=== STEP {idx} [{data.get('source')}] [{data.get('type')}] ===")
            if "tool_calls" in data:
                print("Tool calls:", json.dumps(data["tool_calls"], indent=2))
            if "content" in data:
                print("Content:", data["content"][:300])

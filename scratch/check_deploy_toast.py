import json

path = r"C:\Users\ASUS\.gemini\antigravity\brain\5bf6b230-ca23-4e0f-a559-554a1904a50a\.system_generated\logs\transcript.jsonl"
with open(path, "r", encoding="utf-8") as f:
    lines = f.readlines()

for line in lines:
    d = json.loads(line)
    step = d.get("step_index")
    if step in [504, 505, 506, 507, 508, 509, 510, 511, 512]:
        print(f"=== Step {step} ===")
        if "content" in d and d["content"]:
            print(d["content"][:1000])
        if "thinking" in d and d["thinking"]:
            print("Thinking:", d["thinking"][:500])

import json

path = r"C:\Users\ASUS\.gemini\antigravity\brain\5bf6b230-ca23-4e0f-a559-554a1904a50a\.system_generated\logs\transcript.jsonl"
with open(path, "r", encoding="utf-8") as f:
    lines = f.readlines()

for line in lines:
    d = json.loads(line)
    step = d.get("step_index")
    if step in range(530, 555):
        t = d.get("type")
        source = d.get("source")
        print(f"=== Step {step} ({source}, {t}) ===")
        if "thinking" in d and d["thinking"]:
            print("Thinking:", d["thinking"][:400])
        if "content" in d and d["content"] and t != "EPHEMERAL_MESSAGE":
            print("Content:", d["content"][:400])

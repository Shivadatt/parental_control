import json

path = r"C:\Users\ASUS\.gemini\antigravity\brain\5bf6b230-ca23-4e0f-a559-554a1904a50a\.system_generated\logs\transcript.jsonl"

with open(path, "r", encoding="utf-8") as f:
    lines = f.readlines()

for l in lines:
    d = json.loads(l)
    step = d.get("step_index", 0)
    if step in [611, 612, 613, 614, 615, 627, 628]:
        print(f"=== Step {step} ===")
        c = d.get("content", "")
        for line in c.split("\n"):
            if "textbox" in line and "Editor content" in line:
                print("Editor content line:", line[:200])
                if "value=" in line:
                    idx = line.find("value=")
                    val = line[idx+7:]
                    print("Length of value preview:", len(val))
                    print("Start of value:", val[:100])
                    print("End of value:", val[-200:])

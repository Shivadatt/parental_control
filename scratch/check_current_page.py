import json

path = r"C:\Users\ASUS\.gemini\antigravity\brain\5bf6b230-ca23-4e0f-a559-554a1904a50a\.system_generated\logs\transcript.jsonl"
with open(path, "r", encoding="utf-8") as f:
    lines = f.readlines()

for line in lines[-5:]:
    d = json.loads(line)
    if d.get("type") == "EPHEMERAL_MESSAGE":
        c = d.get("content", "")
        for l in c.split("\n"):
            if any(k in l.lower() for k in ["tree", "treeitem", "textbox", "files", "deploy"]):
                print(l[:100])

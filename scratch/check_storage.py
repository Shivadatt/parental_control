import os
import glob
import re

for root, dirs, files in os.walk('.'):
    if any(p in root for p in ['.git', '.dart_tool', 'build', '.idea']):
        continue
    for f in files:
        if f.endswith(('.sql', '.ts', '.dart', '.md', '.json')):
            fpath = os.path.join(root, f)
            with open(fpath, 'r', encoding='utf-8', errors='ignore') as fl:
                content = fl.read()
            if 'storage' in content.lower():
                matches = [l.strip() for l in content.split('\n') if 'storage' in l.lower() and not l.strip().startswith('//') and not l.strip().startswith('*')]
                if matches:
                    for m in matches[:3]:
                        print(f"{fpath}: {m[:100]}")

import os
import glob
import re

files_to_check = [
    'lib/data/repositories/supabase_device_repository.dart',
    'lib/data/repositories/supabase_pairing_repository.dart',
    'lib/data/repositories/supabase_policy_repository.dart',
    'lib/data/repositories/supabase_usage_repository.dart',
    'lib/data/repositories/supabase_location_repository.dart',
]

for fp in files_to_check:
    print(f"\n=================== {os.path.basename(fp)} ===================")
    with open(fp, 'r', encoding='utf-8') as f:
        content = f.read()
    # Find all methods
    matches = re.finditer(r'Future<[^>]+>\s+([a-zA-Z0-9_]+)\s*\(([^)]*)\)\s*async\s*\{', content)
    for m in matches:
        mname = m.group(1)
        start = m.start()
        # Find closing brace
        brace = 0
        end = start
        for idx in range(start, len(content)):
            if content[idx] == '{':
                brace += 1
            elif content[idx] == '}':
                brace -= 1
                if brace == 0:
                    end = idx
                    break
        mbody = content[start:end+1]
        
        # print what it invokes
        # check EdgeApi, rpc, from
        calls = []
        for line in mbody.split('\n'):
            line_str = line.strip()
            if any(k in line_str for k in ['_edgeApi', 'postJson', '.rpc(', '.from(', 'functions.invoke', '_invoke']):
                calls.append(line_str)
        print(f"Method: {mname}")
        for c in calls[:6]:
            print(f"    {c}")

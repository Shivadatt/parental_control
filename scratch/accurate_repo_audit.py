import os
import glob
import re

def analyze_file_methods(filepath):
    print(f"\n========================================================")
    print(f"FILE: {os.path.basename(filepath)}")
    print(f"========================================================")
    with open(filepath, 'r', encoding='utf-8') as f:
        content = f.read()
        
    # Split content by "@override"
    chunks = content.split('@override')
    for chunk in chunks[1:]:
        # First line is method signature
        lines = chunk.strip().split('\n')
        sig = ""
        body_start_idx = 0
        for idx, line in enumerate(lines):
            sig += " " + line.strip()
            if '{' in line or '=>' in line:
                body_start_idx = idx
                break
        sig = sig.strip()
        body = "\n".join(lines[body_start_idx:])
        
        # Method name
        # match returnType methodName(args)
        m = re.match(r'^(?:Future<[^>]+>|Stream<[^>]+>|void|[A-Za-z0-9_<>?]+)\s+([a-zA-Z0-9_]+)\s*\((.*?)\)', sig)
        mname = m.group(1) if m else sig[:40]
        
        # Detect calls
        pg_tables = sorted(list(set(re.findall(r"\.from\(['\"]([a-zA-Z0-9_]+)['\"]\)", body))))
        rpcs = sorted(list(set(re.findall(r"\.rpc\(['\"]([a-zA-Z0-9_]+)['\"]", body))))
        
        # Edge function
        # e.g. 'edge-function-name', action: 'action_name'
        # or _invokeMap('action_name')
        ef_calls = []
        for ef in re.finditer(r"['\"](account|auth-bootstrap|cron|device-command|device-policy|device-register|device-telemetry|family-admin|pairing|remote-session)['\"](?:\s*,\s*action:\s*['\"]([a-zA-Z0-9_-]+)['\"])?", body):
            fn = ef.group(1)
            act = ef.group(2) if ef.group(2) else ""
            ef_calls.append(f"{fn}:{act}" if act else fn)
            
        for act in re.finditer(r"(?:_invokeMap|_invokeList|_invokeVoid|_fetchList)\s*\(\s*['\"]([a-zA-Z0-9_-]+)['\"]", body):
            ef_calls.append(f"pairing:{act.group(1)}")
            
        # check action: 'xxx'
        for act in re.finditer(r"action:\s*['\"]([a-zA-Z0-9_-]+)['\"]", body):
            ef_calls.append(f"action={act.group(1)}")
            
        # Realtime
        rt_channels = sorted(list(set(re.findall(r"\.channel\(['\"]([^'\"]+)['\"]\)", body))))
        rt_tables = sorted(list(set(re.findall(r"table:\s*['\"]([a-zA-Z0-9_]+)['\"]", body))))
        
        auth_call = 'auth.' in body
        
        desc = []
        if pg_tables: desc.append(f"PostgREST Table(s): {pg_tables}")
        if rpcs: desc.append(f"RPC(s): {rpcs}")
        if ef_calls: desc.append(f"Edge Function: {sorted(list(set(ef_calls)))}")
        if rt_tables: desc.append(f"Realtime Table(s): {rt_tables}")
        if rt_channels: desc.append(f"Realtime Channel(s): {rt_channels}")
        if auth_call: desc.append("Supabase Auth API")
        
        print(f"* Method: {mname}")
        print(f"    Signature: {sig.split('{')[0].split('=>')[0].strip()}")
        if desc:
            for d in desc:
                print(f"    {d}")
        else:
            print("    Local computation / in-memory")

for fp in sorted(glob.glob('lib/data/repositories/supabase_*.dart')):
    analyze_file_methods(fp)

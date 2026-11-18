import os
import glob
import re

def audit_repo_methods():
    repo_files = sorted(glob.glob('lib/data/repositories/supabase_*.dart'))
    for rf in repo_files:
        fname = os.path.basename(rf)
        print(f"\n========================================================")
        print(f"REPOSITORY: {fname}")
        print(f"========================================================")
        with open(rf, 'r', encoding='utf-8') as f:
            lines = f.readlines()
            
        current_method = None
        method_body = []
        for line in lines:
            # Detect method start (e.g., Future<...>, Stream<...>, void, etc.)
            m = re.match(r'^\s*(?:@override\s+)?(Future<[^>]+>|Stream<[^>]+>|void|String|bool|int)\s+([a-zA-Z0-9_]+)\s*\((.*?)\)\s*(?:async\s*)?\{?', line)
            if m:
                if current_method:
                    analyze_method(current_method, "".join(method_body))
                current_method = f"{m.group(2)}({m.group(3)})"
                method_body = [line]
            else:
                if current_method:
                    method_body.append(line)
        if current_method:
            analyze_method(current_method, "".join(method_body))

def analyze_method(mname, body):
    tables = list(set(re.findall(r"\.from\(['\"]([a-zA-Z0-9_]+)['\"]\)", body)))
    rpcs = list(set(re.findall(r"\.rpc\(['\"]([a-zA-Z0-9_]+)['\"]", body)))
    ef_calls = []
    
    # Check EdgeApi calls: _edgeApi.post / postJson / call / invoke
    for ef in re.finditer(r"['\"](auth-bootstrap|family-admin|device-command|device-policy|device-register|device-telemetry|pairing|remote-session|account|cron)['\"](?:\s*,\s*(?:action:\s*)?['\"]([a-zA-Z0-9_-]+)['\"])?", body):
        fn = ef.group(1)
        act = ef.group(2) if ef.group(2) else ""
        ef_calls.append(f"{fn}:{act}" if act else fn)
        
    # Also check if body has action: 'xxx'
    act_matches = re.findall(r"['\"]action['\"]\s*:\s*['\"]([a-zA-Z0-9_-]+)['\"]", body)
    if act_matches:
        for a in act_matches:
            ef_calls.append(f"action={a}")
            
    # Check channel/realtime
    channels = list(set(re.findall(r"\.channel\(['\"]([^'\"]+)['\"]\)", body)))
    
    details = []
    if tables:
        details.append(f"PostgREST: {tables}")
    if rpcs:
        details.append(f"RPC: {rpcs}")
    if ef_calls:
        details.append(f"EdgeFunction: {list(set(ef_calls))}")
    if channels:
        details.append(f"Realtime Channels: {channels}")
        
    print(f"  * {mname}")
    if details:
        for d in details:
            print(f"      {d}")
    else:
        # Check if it calls other methods or local
        print("      (local / auth sdk / helper)")

if __name__ == '__main__':
    audit_repo_methods()

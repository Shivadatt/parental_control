import os
import glob
import re

def parse_full_repo(filepath):
    fname = os.path.basename(filepath)
    with open(filepath, 'r', encoding='utf-8') as f:
        content = f.read()
        
    print(f"\n================================================================================")
    print(f"FILE: {fname}")
    print(f"================================================================================")
    
    # We want to find method definitions in the main class
    # Regex to find: @override followed by method signature
    method_pattern = re.compile(r'(@override\s+(?:Future<[^>]+>|Stream<[^>]+>|void|[A-Za-z0-9_<>?]+)\s+([a-zA-Z0-9_]+)\s*\((.*?)\)\s*(?:async\s*)?\{)', re.DOTALL)
    
    # Let's split into methods by locating @override or public methods
    # Better: scan lines tracking braces
    lines = content.split('\n')
    i = 0
    while i < len(lines):
        line = lines[i]
        # Check if line contains a method start
        # e.g. @override or Future<...> methodName(
        m = re.match(r'^\s*(?:@override\s+)?(Future<[^>]+>|Stream<[^>]+>|void|[A-Za-z0-9_<>?]+)\s+([a-zA-Z0-9_]+)\s*\((.*)', line)
        if m and not line.strip().startswith('return ') and not line.strip().startswith('final ') and not '=>' in line:
            ret_type = m.group(1)
            method_name = m.group(2)
            # collect until {
            full_sig = line.strip()
            while '{' not in full_sig and i < len(lines) - 1:
                i += 1
                full_sig += " " + lines[i].strip()
            
            # collect body tracking braces
            brace_count = 0
            body_lines = []
            start_brace = False
            while i < len(lines):
                cur = lines[i]
                for char in cur:
                    if char == '{':
                        brace_count += 1
                        start_brace = True
                    elif char == '}':
                        brace_count -= 1
                body_lines.append(cur)
                if start_brace and brace_count == 0:
                    break
                i += 1
                
            body_text = "\n".join(body_lines)
            
            # Analyze body_text
            postgrest_tables = set(re.findall(r"\.from\(['\"]([a-zA-Z0-9_]+)['\"]\)", body_text))
            postgrest_rpcs = set(re.findall(r"\.rpc\(['\"]([a-zA-Z0-9_]+)['\"]", body_text))
            
            # Edge function calls
            # edgeApi.postJson('endpoint', action: 'action')
            edge_calls = []
            for ef in re.finditer(r"['\"](auth-bootstrap|family-admin|device-command|device-policy|device-register|device-telemetry|pairing|remote-session|account|cron)['\"](?:\s*,\s*(?:action:\s*)?['\"]([a-zA-Z0-9_-]+)['\"])?", body_text):
                endpoint = ef.group(1)
                action = ef.group(2)
                edge_calls.append(f"{endpoint} (action: {action})" if action else endpoint)
                
            # Direct action in body
            act_in_body = re.findall(r"['\"]action['\"]\s*:\s*['\"]([a-zA-Z0-9_-]+)['\"]", body_text)
            for a in act_in_body:
                edge_calls.append(f"action: {a}")
                
            # Realtime / channel
            rt_channels = set(re.findall(r"\.channel\(['\"]([^'\"]+)['\"]\)", body_text))
            
            print(f"Method: {method_name}")
            print(f"  Signature: {ret_type} {method_name}")
            if postgrest_tables:
                print(f"  PostgREST Tables: {list(postgrest_tables)}")
            if postgrest_rpcs:
                print(f"  RPCs: {list(postgrest_rpcs)}")
            if edge_calls:
                print(f"  Edge Functions: {list(set(edge_calls))}")
            if rt_channels:
                print(f"  Realtime: {list(rt_channels)}")
            if not (postgrest_tables or postgrest_rpcs or edge_calls or rt_channels):
                # Check for auth/storage/local
                if 'auth.' in body_text:
                    print(f"  Supabase Auth API")
                elif 'storage.' in body_text:
                    print(f"  Supabase Storage API")
                else:
                    print(f"  Local/In-Memory/Delegate")
        i += 1

if __name__ == '__main__':
    for r in sorted(glob.glob('lib/data/repositories/supabase_*.dart')):
        parse_full_repo(r)

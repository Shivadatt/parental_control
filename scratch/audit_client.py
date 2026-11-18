import os
import glob
import re

def audit_client_connections():
    repo_files = sorted(glob.glob('lib/data/repositories/*.dart'))
    service_files = sorted(glob.glob('lib/data/services/*.dart'))
    
    all_files = repo_files + service_files
    print(f"Auditing {len(all_files)} Dart files in repositories & services...\n")
    
    for fpath in all_files:
        fname = os.path.basename(fpath)
        with open(fpath, 'r', encoding='utf-8') as f:
            content = f.read()
            
        print(f"==================================================")
        print(f"FILE: {fname}")
        print(f"==================================================")
        
        # PostgREST table queries: .from('table_name')
        from_matches = re.findall(r"\.from\(['\"]([a-zA-Z0-9_]+)['\"]\)", content)
        if from_matches:
            print(f"  PostgREST Tables: {sorted(list(set(from_matches)))}")
            
        # RPC calls: .rpc('rpc_name', ...)
        rpc_matches = re.findall(r"\.rpc\(['\"]([a-zA-Z0-9_]+)['\"]", content)
        if rpc_matches:
            print(f"  RPC Calls: {sorted(list(set(rpc_matches)))}")
            
        # Edge Function calls: edgeApi.call('func_name', action: 'action_name'...) or functions.invoke('func_name'...)
        ef_matches = re.findall(r"functions\.invoke\(['\"]([a-zA-Z0-9_-]+)['\"]", content)
        edge_api_calls = re.findall(r"edgeApi\.call[a-zA-Z0-9_]*\s*\(\s*['\"]([a-zA-Z0-9_-]+)['\"](?:\s*,\s*action:\s*['\"]([a-zA-Z0-9_-]+)['\"])?", content)
        post_json_calls = re.findall(r"postJson\s*\(\s*['\"]([a-zA-Z0-9_-]+)['\"](?:\s*,\s*action:\s*['\"]([a-zA-Z0-9_-]+)['\"])?", content)
        invoke_edge_calls = re.findall(r"_invokeEdge\s*\(\s*['\"]([a-zA-Z0-9_-]+)['\"](?:\s*,\s*action:\s*['\"]([a-zA-Z0-9_-]+)['\"])?", content)
        
        all_ef = set(ef_matches)
        for ef, act in edge_api_calls + post_json_calls + invoke_edge_calls:
            all_ef.add(f"{ef}:{act}" if act else ef)
            
        if all_ef:
            print(f"  Edge Function Calls: {sorted(list(all_ef))}")
            
        # Methods in class
        # Find method signatures
        methods = re.findall(r'(\w+[\?<>\w]*\s+([a-zA-Z0-9_]+)\s*\([^)]*\)\s*(?:async\s*)?\{)', content)
        # Or parse method blocks to see exactly what each method calls
        # Let's inspect class name and methods
        class_match = re.search(r'class\s+([a-zA-Z0-9_]+)', content)
        if class_match:
            cname = class_match.group(1)
            print(f"  Class: {cname}")

if __name__ == '__main__':
    audit_client_connections()

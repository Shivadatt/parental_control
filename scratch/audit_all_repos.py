import os
import glob
import re

def audit_all_repositories():
    repo_files = sorted(glob.glob('lib/data/repositories/supabase_*.dart'))
    for rf in repo_files:
        fname = os.path.basename(rf)
        print(f"\n========================================================")
        print(f"REPOSITORY: {fname}")
        print(f"========================================================")
        with open(rf, 'r', encoding='utf-8') as f:
            content = f.read()
            
        # Match all @override methods or public methods
        # Pattern matches:
        # @override
        # returnType methodName(args) [=> _guard(() async { | async {]
        pattern = re.compile(
            r'(@override\s+)?(Future<[^>]+>|Stream<[^>]+>|void|[A-Za-z0-9_<>?]+)\s+([a-zA-Z0-9_]+)\s*\((.*?)\)\s*(?:=>[^{;]*\{|\s*async\s*\{|\s*\{)',
            re.DOTALL
        )
        
        for m in pattern.finditer(content):
            is_override = bool(m.group(1))
            ret_type = m.group(2).strip()
            mname = m.group(3).strip()
            args = ' '.join(m.group(4).split())
            
            # Find the body of this method
            start_brace = m.end() - 1
            brace_count = 1
            i = start_brace + 1
            while i < len(content) and brace_count > 0:
                if content[i] == '{':
                    brace_count += 1
                elif content[i] == '}':
                    brace_count -= 1
                i += 1
            body = content[start_brace:i]
            
            # PostgREST tables
            pg_tables = list(set(re.findall(r"\.from\(['\"]([a-zA-Z0-9_]+)['\"]\)", body)))
            
            # RPCs
            rpcs = list(set(re.findall(r"\.rpc\(['\"]([a-zA-Z0-9_]+)['\"]", body)))
            
            # Edge function calls
            # Matches _edgeApi.invokeMap('device-register', action: 'register', ...)
            # or _edgeApi.invokeList, invoke, call, postJson
            ef_calls = []
            for ef in re.finditer(r"['\"](account|auth-bootstrap|cron|device-command|device-policy|device-register|device-telemetry|family-admin|pairing|remote-session)['\"](?:\s*,\s*action:\s*['\"]([a-zA-Z0-9_-]+)['\"])?", body):
                ef_fn = ef.group(1)
                ef_act = ef.group(2) if ef.group(2) else ""
                ef_calls.append(f"{ef_fn}:{ef_act}" if ef_act else ef_fn)
                
            # In pairing repo, _invokeMap('action_name') or _fetchList('action_name')
            if 'pairing' in fname:
                for act in re.finditer(r"(?:_invokeMap|_invokeList|_invokeVoid|_fetchList)\s*\(\s*['\"]([a-zA-Z0-9_-]+)['\"]", body):
                    ef_calls.append(f"pairing:{act.group(1)}")
                    
            # Check for Realtime
            realtime_matches = list(set(re.findall(r"\.channel\(['\"]([^'\"]+)['\"]\)", body)))
            realtime_tables = list(set(re.findall(r"table:\s*['\"]([a-zA-Z0-9_]+)['\"]", body)))
            
            print(f"- Method: `{mname}({args})` -> `{ret_type}`")
            if pg_tables:
                print(f"    PostgREST Table(s): {pg_tables}")
            if rpcs:
                print(f"    PostgREST RPC(s): {rpcs}")
            if ef_calls:
                print(f"    Edge Function Action(s): {sorted(list(set(ef_calls)))}")
            if realtime_matches or realtime_tables:
                print(f"    Realtime: channels={realtime_matches}, tables={realtime_tables}")
            if not (pg_tables or rpcs or ef_calls or realtime_matches or realtime_tables):
                if 'auth.' in body:
                    print(f"    Supabase Auth SDK")
                else:
                    print(f"    Internal / Local logic")

if __name__ == '__main__':
    audit_all_repositories()

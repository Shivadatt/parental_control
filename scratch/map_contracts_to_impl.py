import os
import glob
import re

def map_repository_contracts_to_impl():
    # Read repository_contracts.dart
    with open('lib/data/repositories/repository_contracts.dart', 'r', encoding='utf-8') as f:
        contracts_code = f.read()
        
    repos = {
        'AuthRepository': 'lib/data/repositories/supabase_auth_repository.dart',
        'FamilyRepository': 'lib/data/repositories/supabase_family_repository.dart',
        'PairingRepository': 'lib/data/repositories/supabase_pairing_repository.dart',
        'DeviceRepository': 'lib/data/repositories/supabase_device_repository.dart',
        'PolicyRepository': 'lib/data/repositories/supabase_policy_repository.dart',
        'UsageRepository': 'lib/data/repositories/supabase_usage_repository.dart',
        'LocationRepository': 'lib/data/repositories/supabase_location_repository.dart',
        'AlertRepository': 'lib/data/repositories/supabase_alert_repository.dart',
        'RemoteSessionRepository': 'lib/data/repositories/supabase_remote_session_repository.dart',
        'AuditRepository': 'lib/data/repositories/supabase_audit_repository.dart',
    }
    
    # Extract interface methods for each abstract class
    interface_methods = {}
    for cname in repos.keys():
        match = re.search(r'abstract\s+class\s+' + cname + r'\s*\{(.*?)\n\}', contracts_code, re.DOTALL)
        if match:
            cbody = match.group(1)
            # Find methods: retType name(args)
            # Methods might span multiple lines
            # Split by ';'
            m_list = []
            for stmt in cbody.split(';'):
                stmt = stmt.strip()
                if not stmt or stmt.startswith('//'):
                    continue
                # Match method name
                m = re.search(r'([A-Za-z0-9_<>?]+)\s+([a-zA-Z0-9_]+)\s*\((.*?)\)', stmt, re.DOTALL)
                if m:
                    m_list.append((m.group(2), m.group(1), ' '.join(m.group(3).split())))
            interface_methods[cname] = m_list
            
    # Now inspect implementations
    for cname, filepath in repos.items():
        with open(filepath, 'r', encoding='utf-8') as f:
            code = f.read()
            
        print(f"\n========================================================")
        print(f"INTERFACE: {cname} (File: {os.path.basename(filepath)})")
        print(f"========================================================")
        
        methods = interface_methods.get(cname, [])
        for mname, mret, margs in methods:
            # Find implementation in code
            # Look for: mname(
            pattern = re.compile(rf'\b{mname}\s*\(', re.MULTILINE)
            pos = pattern.search(code)
            if not pos:
                print(f"  [MISSING] {mname}({margs}) -> {mret}")
                continue
                
            # Find the body around pos
            start = pos.start()
            # find '{'
            brace_pos = code.find('{', start)
            if brace_pos == -1:
                print(f"  [ERROR FINDING BRACE] {mname}")
                continue
            
            # Find matching brace
            brace = 1
            i = brace_pos + 1
            while i < len(code) and brace > 0:
                if code[i] == '{':
                    brace += 1
                elif code[i] == '}':
                    brace -= 1
                i += 1
            body = code[brace_pos:i]
            
            # Now detect what it invokes
            pg_tables = list(set(re.findall(r"\.from\(['\"]([a-zA-Z0-9_]+)['\"]\)", body)))
            rpcs = list(set(re.findall(r"\.rpc\(['\"]([a-zA-Z0-9_]+)['\"]", body)))
            
            ef_calls = []
            # EdgeApi calls:
            for ef in re.finditer(r"['\"](account|auth-bootstrap|cron|device-command|device-policy|device-register|device-telemetry|family-admin|pairing|remote-session)['\"](?:\s*,\s*action:\s*['\"]([a-zA-Z0-9_-]+)['\"])?", body):
                fn = ef.group(1)
                act = ef.group(2) if ef.group(2) else ""
                ef_calls.append(f"{fn}:{act}" if act else fn)
                
            if 'pairing' in filepath:
                for act in re.finditer(r"(?:_invokeMap|_invokeList|_invokeVoid|_fetchList)\s*\(\s*['\"]([a-zA-Z0-9_-]+)['\"]", body):
                    ef_calls.append(f"pairing:{act.group(1)}")
                    
            rt_channels = list(set(re.findall(r"\.channel\(['\"]([^'\"]+)['\"]\)", body)))
            rt_tables = list(set(re.findall(r"table:\s*['\"]([a-zA-Z0-9_]+)['\"]", body)))
            
            auth_call = 'auth.' in body
            
            invocation_desc = []
            if pg_tables:
                invocation_desc.append(f"PostgREST Table(s): {', '.join(pg_tables)}")
            if rpcs:
                invocation_desc.append(f"RPC: {', '.join(rpcs)}")
            if ef_calls:
                invocation_desc.append(f"Edge Function: {', '.join(sorted(list(set(ef_calls))))}")
            if rt_tables or rt_channels:
                rt_desc = []
                if rt_tables: rt_desc.append(f"table={rt_tables}")
                if rt_channels: rt_desc.append(f"channel={rt_channels}")
                invocation_desc.append(f"Realtime: {', '.join(rt_desc)}")
            if auth_call:
                invocation_desc.append("Supabase Auth SDK")
            if not invocation_desc:
                invocation_desc.append("Local Cache / Stream Transformer")
                
            print(f"  * `{mname}({margs})` -> `{mret}`")
            for inv in invocation_desc:
                print(f"      -> {inv}")

if __name__ == '__main__':
    map_repository_contracts_to_impl()

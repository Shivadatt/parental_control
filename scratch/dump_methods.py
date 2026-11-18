import os
import glob
import re

def parse_full_repo():
    out_lines = []
    for filepath in sorted(glob.glob('lib/data/repositories/supabase_*.dart')):
        fname = os.path.basename(filepath)
        out_lines.append(f"\n================================================================================")
        out_lines.append(f"FILE: {fname}")
        out_lines.append(f"================================================================================")
        with open(filepath, 'r', encoding='utf-8') as f:
            content = f.read()
            
        lines = content.split('\n')
        i = 0
        while i < len(lines):
            line = lines[i]
            m = re.match(r'^\s*(?:@override\s+)?(Future<[^>]+>|Stream<[^>]+>|void|[A-Za-z0-9_<>?]+)\s+([a-zA-Z0-9_]+)\s*\((.*)', line)
            if m and not line.strip().startswith('return ') and not line.strip().startswith('final ') and not '=>' in line:
                ret_type = m.group(1)
                method_name = m.group(2)
                full_sig = line.strip()
                while '{' not in full_sig and i < len(lines) - 1:
                    i += 1
                    full_sig += " " + lines[i].strip()
                
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
                
                postgrest_tables = set(re.findall(r"\.from\(['\"]([a-zA-Z0-9_]+)['\"]\)", body_text))
                postgrest_rpcs = set(re.findall(r"\.rpc\(['\"]([a-zA-Z0-9_]+)['\"]", body_text))
                
                edge_calls = []
                for ef in re.finditer(r"['\"](auth-bootstrap|family-admin|device-command|device-policy|device-register|device-telemetry|pairing|remote-session|account|cron)['\"](?:\s*,\s*(?:action:\s*)?['\"]([a-zA-Z0-9_-]+)['\"])?", body_text):
                    endpoint = ef.group(1)
                    action = ef.group(2)
                    edge_calls.append(f"{endpoint}:{action}" if action else endpoint)
                    
                act_in_body = re.findall(r"['\"]action['\"]\s*:\s*['\"]([a-zA-Z0-9_-]+)['\"]", body_text)
                for a in act_in_body:
                    edge_calls.append(f"action:{a}")
                    
                rt_channels = set(re.findall(r"\.channel\(['\"]([^'\"]+)['\"]\)", body_text))
                
                out_lines.append(f"\nMethod: {method_name}")
                out_lines.append(f"  Signature: {full_sig.split('{')[0].strip()}")
                if postgrest_tables:
                    out_lines.append(f"  PostgREST: {sorted(list(postgrest_tables))}")
                if postgrest_rpcs:
                    out_lines.append(f"  RPC: {sorted(list(postgrest_rpcs))}")
                if edge_calls:
                    out_lines.append(f"  EdgeFunction: {sorted(list(set(edge_calls)))}")
                if rt_channels:
                    out_lines.append(f"  Realtime: {sorted(list(rt_channels))}")
                if not (postgrest_tables or postgrest_rpcs or edge_calls or rt_channels):
                    if 'auth.' in body_text:
                        out_lines.append(f"  Auth: Supabase Auth SDK")
                    elif 'storage.' in body_text:
                        out_lines.append(f"  Storage: Supabase Storage SDK")
                    else:
                        out_lines.append(f"  Local / Cache / Stream Helper")
            i += 1
            
    with open('scratch/repo_methods_detail_utf8.txt', 'w', encoding='utf-8') as f:
        f.write("\n".join(out_lines))
    print(f"Wrote {len(out_lines)} lines to scratch/repo_methods_detail_utf8.txt")

if __name__ == '__main__':
    parse_full_repo()

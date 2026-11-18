import os
import glob
import re

def parse_all_functions():
    migration_files = sorted(glob.glob('supabase/migrations/*.sql'))
    
    # We want to identify every CREATE FUNCTION (schema, name, args, returns, security, language, file)
    fn_map = {}
    
    pattern = re.compile(
        r'create\s+(?:or\s+replace\s+)?function\s+((?:public|private)\.)?([a-zA-Z0-9_]+)\s*\((.*?)\)\s*returns\s+(.*?)\s+(?:language|as|\$\$)',
        re.IGNORECASE | re.DOTALL
    )
    
    for mf in migration_files:
        fname = os.path.basename(mf)
        with open(mf, 'r', encoding='utf-8') as f:
            content = f.read()
            
        for m in pattern.finditer(content):
            schema = m.group(1).replace('.', '') if m.group(1) else 'public'
            name = m.group(2).lower()
            args = ' '.join(m.group(3).split())
            returns = ' '.join(m.group(4).split())
            
            # Find definition up to $$;
            pos = m.start()
            end = content.find('$$;', pos)
            fn_body = content[pos:end+3] if end != -1 else content[pos:pos+1500]
            sec = "SECURITY DEFINER" if "security definer" in fn_body.lower() else "SECURITY INVOKER"
            search_path = ""
            sp_match = re.search(r'set\s+search_path\s*=\s*([^;]+)', fn_body, re.IGNORECASE)
            if sp_match:
                search_path = sp_match.group(1).strip()
                
            key = f"{schema}.{name}"
            if key not in fn_map:
                fn_map[key] = []
            fn_map[key].append({
                'file': fname,
                'args': args,
                'returns': returns,
                'security': sec,
                'search_path': search_path
            })
            
    print(f"Total Unique Functions: {len(fn_map)}")
    public_rpcs = []
    private_funcs = []
    for k in sorted(fn_map.keys()):
        schema, name = k.split('.')
        history = fn_map[k]
        latest = history[-1]
        print(f"\n{k} (latest in {latest['file']}):")
        print(f"  Args: {latest['args']}")
        print(f"  Returns: {latest['returns']}")
        print(f"  Security: {latest['security']}")
        print(f"  Search Path: {latest['search_path']}")
        if len(history) > 1:
            print(f"  Versions across files: {[h['file'] for h in history]}")
        if schema == 'public':
            public_rpcs.append(name)
        else:
            private_funcs.append(name)
            
    print(f"\nPublic RPCs count: {len(public_rpcs)}: {public_rpcs}")
    print(f"\nPrivate Functions count: {len(private_funcs)}: {private_funcs}")

if __name__ == '__main__':
    parse_all_functions()

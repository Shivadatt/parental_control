import os
import glob
import re

def audit_migrations():
    migration_files = sorted(glob.glob('supabase/migrations/*.sql'))
    print(f"Found {len(migration_files)} migration files:")
    for m in migration_files:
        print(f"  - {os.path.basename(m)}")
    
    # Detailed scan
    tables = {}
    functions = []
    policies = []
    triggers = []
    indexes = []
    alter_tables = []
    
    for mf in migration_files:
        fname = os.path.basename(mf)
        with open(mf, 'r', encoding='utf-8') as f:
            content = f.read()
            
        # Matches create table
        for m in re.finditer(r'create\s+table\s+(?:if\s+not\s+exists\s+)?(?:public\.)?([a-zA-Z0-9_]+)\s*\((.*?)\n\);', content, re.IGNORECASE | re.DOTALL):
            tbl = m.group(1).lower()
            body = m.group(2)
            tables[tbl] = {'file': fname, 'body': body}
            
        # Matches create or replace function
        for m in re.finditer(r'create\s+(?:or\s+replace\s+)?function\s+(?:public\.)?([a-zA-Z0-9_]+)\s*\((.*?)\)\s*returns\s+(.*?)(?:language|as|\$\$)', content, re.IGNORECASE | re.DOTALL):
            fn_name = m.group(1).lower()
            args = m.group(2).strip().replace('\n', ' ')
            ret = m.group(3).strip().replace('\n', ' ')
            # Check security definer
            # Find the rest of function definition up to $$;
            fn_pos = m.start()
            end_pos = content.find('$$;', fn_pos)
            fn_full = content[fn_pos:end_pos+3] if end_pos != -1 else content[fn_pos:fn_pos+500]
            sec = "SECURITY DEFINER" if "security definer" in fn_full.lower() else "SECURITY INVOKER"
            functions.append({
                'name': fn_name,
                'file': fname,
                'args': args,
                'returns': ret,
                'security': sec
            })
            
        # Matches create policy
        for m in re.finditer(r'create\s+policy\s+"([^"]+)"\s+on\s+(?:public\.)?([a-zA-Z0-9_]+)(.*?)(?:;|\n\n)', content, re.IGNORECASE | re.DOTALL):
            pol_name = m.group(1)
            pol_tbl = m.group(2).lower()
            pol_body = m.group(3).strip().replace('\n', ' ')
            policies.append({
                'name': pol_name,
                'table': pol_tbl,
                'file': fname,
                'body': pol_body
            })

        # Matches create trigger
        for m in re.finditer(r'create\s+trigger\s+([a-zA-Z0-9_]+)\s+(.*?)\s+on\s+(?:public\.)?([a-zA-Z0-9_]+)\s+(.*?);', content, re.IGNORECASE | re.DOTALL):
            trig_name = m.group(1)
            timing = m.group(2).strip().replace('\n', ' ')
            tbl = m.group(3).lower()
            rest = m.group(4).strip().replace('\n', ' ')
            triggers.append({
                'name': trig_name,
                'table': tbl,
                'timing': timing,
                'rest': rest,
                'file': fname
            })
            
        # Matches create index
        for m in re.finditer(r'create\s+(?:unique\s+)?index\s+(?:if\s+not\s+exists\s+)?([a-zA-Z0-9_]+)\s+on\s+(?:public\.)?([a-zA-Z0-9_]+)\s*(.*?);', content, re.IGNORECASE | re.DOTALL):
            idx_name = m.group(1)
            idx_tbl = m.group(2).lower()
            idx_body = m.group(3).strip().replace('\n', ' ')
            indexes.append({
                'name': idx_name,
                'table': idx_tbl,
                'body': idx_body,
                'file': fname
            })
            
        # Matches alter table
        for m in re.finditer(r'alter\s+table\s+(?:public\.)?([a-zA-Z0-9_]+)\s+(.*?);', content, re.IGNORECASE | re.DOTALL):
            tbl = m.group(1).lower()
            stmt = m.group(2).strip().replace('\n', ' ')
            alter_tables.append({
                'table': tbl,
                'stmt': stmt,
                'file': fname
            })
            
    print(f"\nTotal Tables: {len(tables)}")
    for t in sorted(tables.keys()):
        print(f"  - {t} (defined in {tables[t]['file']})")
        
    print(f"\nTotal Functions: {len(functions)}")
    for f in functions:
        print(f"  - {f['name']}({f['args']}) -> {f['returns']} [{f['security']}] (in {f['file']})")
        
    print(f"\nTotal Policies: {len(policies)}")
    for p in policies:
        print(f"  - [{p['table']}] \"{p['name']}\" (in {p['file']})")
        
    print(f"\nTotal Triggers: {len(triggers)}")
    for tr in triggers:
        print(f"  - {tr['name']} ON {tr['table']} ({tr['timing']} {tr['rest']}) (in {tr['file']})")

if __name__ == '__main__':
    audit_migrations()

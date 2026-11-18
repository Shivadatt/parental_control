import os
import glob
import re

def parse_all():
    migration_files = sorted(glob.glob('supabase/migrations/*.sql'))
    print(f"Loaded {len(migration_files)} migrations")
    
    # 1. Policies
    policies = []
    policy_pattern = re.compile(
        r'create\s+policy\s+([a-zA-Z0-9_"]+)\s+on\s+(?:public\.)?([a-zA-Z0-9_]+)\s+'
        r'(?:for\s+(all|select|insert|update|delete)\s+)?'
        r'(?:to\s+([a-zA-Z0-9_,\s]+?)\s+)?'
        r'(?:using\s*\((.*?)\)\s*)?'
        r'(?:with\s+check\s*\((.*?)\)\s*)?;',
        re.IGNORECASE | re.DOTALL
    )
    
    # Also drop policy
    drop_policies = []
    
    # Let's inspect each migration
    for mf in migration_files:
        fname = os.path.basename(mf)
        with open(mf, 'r', encoding='utf-8') as f:
            content = f.read()
            
        for m in policy_pattern.finditer(content):
            pname = m.group(1).replace('"', '')
            tbl = m.group(2)
            op = m.group(3) or 'all'
            roles = m.group(4) or 'public'
            using = m.group(5) or ''
            with_check = m.group(6) or ''
            policies.append({
                'file': fname,
                'table': tbl,
                'name': pname,
                'op': op.strip().lower(),
                'roles': roles.strip(),
                'using': ' '.join(using.split()),
                'with_check': ' '.join(with_check.split())
            })
            
        for m in re.finditer(r'drop\s+policy\s+(?:if\s+exists\s+)?([a-zA-Z0-9_"]+)\s+on\s+(?:public\.)?([a-zA-Z0-9_]+)', content, re.IGNORECASE):
            drop_policies.append({
                'file': fname,
                'name': m.group(1).replace('"', ''),
                'table': m.group(2)
            })

    print(f"\n--- Policies Found: {len(policies)} ---")
    for p in policies:
        print(f"Table: {p['table']}, Name: {p['name']}, Op: {p['op']}, Roles: {p['roles']}")
        if p['using']:
            print(f"   USING: {p['using']}")
        if p['with_check']:
            print(f"   WITH CHECK: {p['with_check']}")
            
    print(f"\n--- Dropped Policies: {len(drop_policies)} ---")
    for dp in drop_policies:
        print(f"File: {dp['file']}, Name: {dp['name']}, Table: {dp['table']}")

if __name__ == '__main__':
    parse_all()

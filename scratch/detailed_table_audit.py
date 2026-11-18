import os
import glob
import re

def detailed_table_audit():
    # Let's inspect each table created
    # 1. 20260101000000_core.sql
    with open('supabase/migrations/20260101000000_core.sql', 'r', encoding='utf-8') as f:
        core_sql = f.read()
    with open('supabase/migrations/20260101000500_child_contact_ids.sql', 'r', encoding='utf-8') as f:
        contact_sql = f.read()
        
    all_sql = core_sql + "\n" + contact_sql
    
    # Also read all migrations for ALTER TABLE
    alterations = {}
    for mf in sorted(glob.glob('supabase/migrations/*.sql')):
        with open(mf, 'r', encoding='utf-8') as f:
            c = f.read()
        for m in re.finditer(r'alter\s+table\s+(?:public\.)?([a-zA-Z0-9_]+)\s+([^;]+);', c, re.IGNORECASE):
            tbl = m.group(1).lower()
            if tbl not in alterations:
                alterations[tbl] = []
            alterations[tbl].append((os.path.basename(mf), ' '.join(m.group(2).split())))

    # Extract CREATE TABLE
    table_blocks = re.findall(r'create\s+table\s+(?:if\s+not\s+exists\s+)?(?:public\.)?([a-zA-Z0-9_]+)\s*\((.*?)\n\);', all_sql, re.DOTALL | re.IGNORECASE)
    
    print(f"Total tables detected: {len(table_blocks)}")
    
    for tbl, body in table_blocks:
        tbl = tbl.lower()
        print(f"\n=======================================================")
        print(f"TABLE: {tbl}")
        print(f"=======================================================")
        lines = [l.strip().rstrip(',') for l in body.strip().split('\n') if l.strip()]
        for l in lines:
            print(f"  {l}")
        if tbl in alterations:
            print(f"  --- Alterations ---")
            for f, a in alterations[tbl]:
                print(f"  [{f}] {a}")

if __name__ == '__main__':
    detailed_table_audit()

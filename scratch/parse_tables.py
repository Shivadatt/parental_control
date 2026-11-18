import os
import glob
import re

def parse_tables_detailed():
    migration_files = sorted(glob.glob('supabase/migrations/*.sql'))
    
    # We want to extract full table definitions from 20260101000000_core.sql and 20260101000500_child_contact_ids.sql
    # and all alter tables across all migrations.
    
    tables = {}
    
    for mf in migration_files:
        fname = os.path.basename(mf)
        with open(mf, 'r', encoding='utf-8') as f:
            content = f.read()
            
        # find create table
        for m in re.finditer(r'create\s+table\s+(?:if\s+not\s+exists\s+)?(?:public\.)?([a-zA-Z0-9_]+)\s*\((.*?)\n\);', content, re.IGNORECASE | re.DOTALL):
            tbl = m.group(1).lower()
            body = m.group(2)
            tables[tbl] = {
                'created_in': fname,
                'raw_body': body,
                'alterations': []
            }
            
    # Check alterations
    for mf in migration_files:
        fname = os.path.basename(mf)
        with open(mf, 'r', encoding='utf-8') as f:
            content = f.read()
        for m in re.finditer(r'alter\s+table\s+(?:public\.)?([a-zA-Z0-9_]+)\s+(.*?);', content, re.IGNORECASE | re.DOTALL):
            tbl = m.group(1).lower()
            stmt = ' '.join(m.group(2).split())
            if tbl in tables:
                tables[tbl]['alterations'].append((fname, stmt))
            else:
                print(f"Alter table on unknown table: {tbl} ({stmt}) in {fname}")

    print(f"Total tables: {len(tables)}")
    for t, data in sorted(tables.items()):
        print(f"\n================ TABLE: {t} (created in {data['created_in']}) ================")
        print("Raw definitions:")
        for line in data['raw_body'].strip().split('\n'):
            line = line.strip()
            if line:
                print(f"  {line}")
        if data['alterations']:
            print("Alterations:")
            for af, astmt in data['alterations']:
                print(f"  [{af}] {astmt}")

if __name__ == '__main__':
    parse_tables_detailed()

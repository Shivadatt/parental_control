import os
import glob
import re

def parse_indexes_publications():
    migration_files = sorted(glob.glob('supabase/migrations/*.sql'))
    indexes = []
    publications = []
    
    for mf in migration_files:
        fname = os.path.basename(mf)
        with open(mf, 'r', encoding='utf-8') as f:
            content = f.read()
            
        for m in re.finditer(r'create\s+(unique\s+)?index\s+(?:if\s+not\s+exists\s+)?([a-zA-Z0-9_]+)\s+on\s+(?:public\.)?([a-zA-Z0-9_]+)\s*(.*?);', content, re.IGNORECASE | re.DOTALL):
            is_uniq = bool(m.group(1))
            idx_name = m.group(2)
            tbl = m.group(3).lower()
            idx_def = ' '.join(m.group(4).split())
            indexes.append({
                'file': fname,
                'table': tbl,
                'name': idx_name,
                'unique': is_uniq,
                'def': idx_def
            })
            
        for m in re.finditer(r'alter\s+publication\s+([a-zA-Z0-9_]+)\s+(add\s+table\s+[^;]+);', content, re.IGNORECASE):
            pub_name = m.group(1)
            pub_action = ' '.join(m.group(2).split())
            publications.append({
                'file': fname,
                'publication': pub_name,
                'action': pub_action
            })

    print(f"Total Indexes: {len(indexes)}")
    for idx in indexes:
        uniq_str = "UNIQUE " if idx['unique'] else ""
        print(f"[{idx['file']}] {idx['table']}: {uniq_str}INDEX {idx['name']} {idx['def']}")
        
    print(f"\nPublications:")
    for p in publications:
        print(f"[{p['file']}] {p['publication']} -> {p['action']}")

if __name__ == '__main__':
    parse_indexes_publications()

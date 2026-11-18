import os
import glob

def audit_edge_functions():
    ef_dirs = sorted([d for d in glob.glob('supabase/functions/*') if os.path.isdir(d) and not os.path.basename(d).startswith('.')])
    print(f"Found {len(ef_dirs)} Edge Function directories:")
    for d in ef_dirs:
        print(f"  - {os.path.basename(d)}")
        
    shared_files = glob.glob('supabase/functions/_shared/*')
    print(f"\n_shared files ({len(shared_files)}):")
    for sf in shared_files:
        print(f"  - {os.path.basename(sf)}")
        
    for d in ef_dirs:
        dirname = os.path.basename(d)
        if dirname == '_shared':
            continue
        print(f"\n================ EDGE FUNCTION: {dirname} ================")
        files = glob.glob(f"{d}/**/*", recursive=True)
        for f in files:
            if os.path.isfile(f):
                rel = os.path.relpath(f, d)
                size = os.path.getsize(f)
                print(f"  File: {rel} ({size} bytes)")
                
        # Read index.ts
        index_path = os.path.join(d, 'index.ts')
        if os.path.exists(index_path):
            with open(index_path, 'r', encoding='utf-8') as f:
                content = f.read()
            lines = content.split('\n')
            imports = [l for l in lines if l.startswith('import ')]
            print("  Imports:")
            for imp in imports:
                print(f"    {imp}")
                
            # Check actions/routes/handlers
            actions = []
            for l in lines:
                if 'action' in l.lower() or 'case ' in l or 'switch' in l or 'router' in l or 'req.method' in l or 'url.pathname' in l:
                    actions.append(l.strip())
            if actions:
                print("  Routing / Action hints:")
                for a in actions[:25]:
                    print(f"    {a}")

if __name__ == '__main__':
    audit_edge_functions()

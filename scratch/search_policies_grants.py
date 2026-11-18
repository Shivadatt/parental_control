import os
import glob
import re

def search_text():
    migration_files = sorted(glob.glob('supabase/migrations/*.sql'))
    for mf in migration_files:
        with open(mf, 'r', encoding='utf-8') as f:
            lines = f.readlines()
        for idx, line in enumerate(lines):
            if any(k in line.lower() for k in ['policy', 'realtime', 'publication', 'grant ', 'revoke ']):
                if not line.strip().startswith('--'):
                    print(f"{os.path.basename(mf)}:{idx+1}: {line.strip()}")

if __name__ == '__main__':
    search_text()

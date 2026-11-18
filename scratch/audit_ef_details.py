import os
import glob
import re

def audit_all_ef_details():
    ef_dirs = sorted([d for d in glob.glob('supabase/functions/*') if os.path.isdir(d) and not os.path.basename(d).startswith('.') and os.path.basename(d) != '_shared'])
    
    for d in ef_dirs:
        dirname = os.path.basename(d)
        print(f"\n==========================================")
        print(f"EDGE FUNCTION: {dirname}")
        print(f"==========================================")
        
        # Read all ts files in the directory
        ts_files = glob.glob(f"{d}/*.ts")
        for ts_path in ts_files:
            fname = os.path.basename(ts_path)
            if 'test' in fname:
                continue
            with open(ts_path, 'r', encoding='utf-8') as f:
                content = f.read()
                
            cases = re.findall(r'case\s+["\']([a-zA-Z0-9_]+)["\']\s*:', content)
            if cases:
                print(f"[{fname}] Action cases found: {cases}")
                
            # If no cases, check if action == "something"
            direct_actions = re.findall(r'action\s*===?\s*["\']([a-zA-Z0-9_]+)["\']', content)
            if direct_actions:
                print(f"[{fname}] Direct action checks found: {direct_actions}")
                
            # Auth checks
            auths = []
            if 'requireUser' in content:
                auths.append('requireUser (JWT User)')
            if 'requireDevice' in content:
                auths.append('requireDevice (Device ID + Secret)')
            if 'constantTimeSecretEqual' in content or 'CRON_SECRET' in content:
                auths.append('CRON_SECRET / Service Secret')
            print(f"[{fname}] Auth: {', '.join(auths) if auths else 'Custom/None'}")

if __name__ == '__main__':
    audit_all_ef_details()

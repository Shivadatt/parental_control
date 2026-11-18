import os
import glob
import re

for fp in sorted(glob.glob('lib/data/services/*.dart')):
    with open(fp, 'r', encoding='utf-8') as f:
        c = f.read()
    tables = re.findall(r"\.from\(['\"](\w+)['\"]\)", c)
    rpcs = re.findall(r"\.rpc\(['\"](\w+)['\"]\)", c)
    efs = re.findall(r"['\"](account|auth-bootstrap|cron|device-command|device-policy|device-register|device-telemetry|family-admin|pairing|remote-session)['\"]", c)
    print(f"{os.path.basename(fp)}:")
    print(f"  Tables: {set(tables)}")
    print(f"  RPCs: {set(rpcs)}")
    print(f"  EFs: {set(efs)}")

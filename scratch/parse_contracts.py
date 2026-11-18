import os
import glob
import re

def parse_contracts():
    with open('lib/data/repositories/repository_contracts.dart', 'r', encoding='utf-8') as f:
        content = f.read()
        
    abstract_classes = re.findall(r'abstract\s+class\s+([a-zA-Z0-9_]+)\s*\{(.*?)\n\}', content, re.DOTALL)
    print(f"Found {len(abstract_classes)} abstract classes in repository_contracts.dart:")
    for cname, cbody in abstract_classes:
        print(f"\n--- {cname} ---")
        methods = re.findall(r'^\s*([A-Za-z0-9_<>?]+)\s+([A-Za-z0-9_]+)\s*\((.*?)\);', cbody, re.MULTILINE)
        for ret, mname, params in methods:
            print(f"  {mname}({params.strip()}) -> {ret}")

if __name__ == '__main__':
    parse_contracts()

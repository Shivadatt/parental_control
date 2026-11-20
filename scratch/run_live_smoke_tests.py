import urllib.request
import urllib.error
import json
import ssl

endpoint = "https://hhqgreaoqulmfwfwarhc.supabase.co/functions/v1/account"
ctx = ssl.create_default_context()

print("================ LIVE ENDPOINT SMOKE TESTS ================")
print(f"Target: {endpoint}\n")

# Test 1: OPTIONS / CORS
print("--- TEST 1: OPTIONS / CORS Preflight ---")
try:
    req = urllib.request.Request(endpoint, method="OPTIONS")
    req.add_header("Origin", "http://localhost:3000")
    req.add_header("Access-Control-Request-Method", "POST")
    with urllib.request.urlopen(req, context=ctx) as resp:
        print(f"Status: {resp.status} {resp.reason}")
        for k, v in resp.headers.items():
            if "access-control" in k.lower():
                print(f"  {k}: {v}")
        body = resp.read().decode('utf-8')
        print(f"Body: {body[:200]}")
except urllib.error.HTTPError as e:
    print(f"Status: {e.code} {e.reason}")
    print(f"Body: {e.read().decode('utf-8')[:200]}")
except Exception as e:
    print(f"Error: {e}")

# Test 2: Missing Authorization
print("\n--- TEST 2: Missing Authorization Header ---")
try:
    req = urllib.request.Request(endpoint, method="POST", data=b'{"action":"export"}')
    req.add_header("Content-Type", "application/json")
    with urllib.request.urlopen(req, context=ctx) as resp:
        print(f"Status: {resp.status} {resp.reason}")
        print(f"Body: {resp.read().decode('utf-8')[:200]}")
except urllib.error.HTTPError as e:
    print(f"Status: {e.code} {e.reason}")
    print(f"Body: {e.read().decode('utf-8')[:200]}")
except Exception as e:
    print(f"Error: {e}")

# Test 3: Malformed Authorization
print("\n--- TEST 3: Malformed Authorization Token ---")
try:
    req = urllib.request.Request(endpoint, method="POST", data=b'{"action":"export"}')
    req.add_header("Content-Type", "application/json")
    req.add_header("Authorization", "Bearer invalid.jwt.token")
    with urllib.request.urlopen(req, context=ctx) as resp:
        print(f"Status: {resp.status} {resp.reason}")
        print(f"Body: {resp.read().decode('utf-8')[:200]}")
except urllib.error.HTTPError as e:
    print(f"Status: {e.code} {e.reason}")
    print(f"Body: {e.read().decode('utf-8')[:200]}")
except Exception as e:
    print(f"Error: {e}")

# Test 4: Invalid JSON Body
print("\n--- TEST 4: Invalid JSON Body ---")
try:
    req = urllib.request.Request(endpoint, method="POST", data=b'{"malformed_json:')
    req.add_header("Content-Type", "application/json")
    with urllib.request.urlopen(req, context=ctx) as resp:
        print(f"Status: {resp.status} {resp.reason}")
        print(f"Body: {resp.read().decode('utf-8')[:200]}")
except urllib.error.HTTPError as e:
    print(f"Status: {e.code} {e.reason}")
    print(f"Body: {e.read().decode('utf-8')[:200]}")
except Exception as e:
    print(f"Error: {e}")

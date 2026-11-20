import hashlib
import os

staging_dir = r"D:\parentcontrol_app\docs\testing\phase_3_4_3_browser_package\staging\account"

expected = {
    "index.ts": "31ed89d4b995dd1ca14869d73e022e94c159aea85be2e3ca0624df6058681723",
    "deletion.ts": "64e9beb74b44846c8a9bc3dca348eeac9816b58b24f1f98bc96d73ea563992b8",
    "retention.ts": "0338194cf22b9372d5e18ee55c607e9020c8d8f164f8b25cfeb57ea83433e8ed",
    "validation.ts": "5f5befcdb947fbe327c04c2f011ec65b58092bfe9e33c105393d72ad0fd4acde",
    "shared-audit.ts": "b770dba176fddb8b7edceaf4c805b74124c2c15c366e683d77b3451c1d25f8e0",
    "shared-envelope.ts": "f788b50341f78e22a00a74cd363e9a626779f26870ed2d96e4f165b046b5d4cd",
    "shared-cors.ts": "1fc7034e7c3646f18ab424c49a464f23c88fefe3bba5dd0ee0bac5c348266db9",
    "shared-auth.ts": "f709f3e16363fbcf47e49876502630e18b4fba425a00f9c9a4e727aa52c62ab5",
    "shared-validation.ts": "263fa94e92c8ebf4c60eaf45d00ef39045f7554b50f1080c267ff7e96b9e3ee3",
}

print(f"{'File':<22} | {'Bytes':<6} | {'Lines':<6} | {'SHA-256 Match'}")
print("-" * 55)

all_ok = True
for name, exp_hash in expected.items():
    path = os.path.join(staging_dir, name)
    if not os.path.exists(path):
        print(f"{name:<22} | MISSING")
        all_ok = False
        continue
    with open(path, "rb") as f:
        content = f.read()
    h = hashlib.sha256(content).hexdigest()
    lines = content.count(b"\n") + (1 if content and not content.endswith(b"\n") else 0)
    match = (h == exp_hash)
    if not match:
        all_ok = False
    print(f"{name:<22} | {len(content):<6} | {lines:<6} | {match} ({h[:8]}...)")

print("-" * 55)
print(f"All 9 files match expected baseline: {all_ok}")

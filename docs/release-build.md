# Release build: size composition, reduction options, signing

Date: 2026-10-27
Workspace: `D:\parentcontrol_app` (Flutter 3.44.6 via FVM, Android only)
Baseline artifact: `build/app/outputs/flutter-apk/app-release.apk`
Built with `flutter build apk --release --dart-define-from-file=.tools/live_config.env`.

**Status of this document.** §1 is a read-only measurement of the universal
release APK. The recommended option in §2 row 1 (`--split-per-abi`) has now been
**built and measured** on this workstation, and the arm64-v8a artefact was
installed and cold-launched on the RMX2161; the measured numbers are recorded in
§1.7 and §6 and in [verification-report.md](verification-report.md). Options
that were not built are still labelled as estimates.

## 1. Measured breakdown of the current 110 MB APK

### 1.1 Totals

| Metric | Value | How obtained |
|---|---|---|
| APK file size on disk | **110,247,706 bytes** (105.1 MiB) | `ls -l build/app/outputs/flutter-apk/app-release.apk` |
| Sum of entry sizes after decompression | 112,468,814 bytes | `unzip -l ... \| tail -1` |
| Sum of compressed entry sizes | 109,992,032 bytes | `python -c "import zipfile; ..."` over `infolist()` |
| Zip container overhead (padding, central directory) | 255,674 bytes | 110,247,706 − 109,992,032 |
| Entries | 350 | `unzip -l` |
| ABIs shipped | `arm64-v8a`, `armeabi-v7a`, `x86_64` | `aapt dump badging ... \| grep native-code` |
| minSdk / targetSdk | 24 / 36 | `aapt dump badging` |
| `extractNativeLibs` | `false` → **`.so` files are stored, not deflated** | `aapt dump xmltree ... AndroidManifest.xml` |
| Signature | `CN=Android Debug` (debug keystore), cert SHA-256 `1c9268d57ebe5f5e15eb3738eed96e57f776c298e9e44d75a51937cda70720a5` | `apksigner verify --print-certs` |
| SHA-256 of APK (measured build) | `95ae17161dc8dfba34c9c2027ed359587ebff5653228db56a056be1cb7a33bb1` | recorded in `docs/verification-report.md` |
| SHA-256 of APK (current rebuild) | `51ea1c4f40fcb4cc789a55e157b1adfac823c908b318185d266ad0cc3c88fc93`, 110,247,826 bytes | `sha256sum build/app/outputs/flutter-apk/app-release.apk` |

The §1 composition was measured on the 110,247,706-byte build. The current
rebuild is 110,247,826 bytes (120 bytes larger, 0.0001 %); the difference is
rebuild non-determinism (zip container/timestamp bytes) and does not change the
composition below.

### 1.2 Top-level groups

| Group | Uncompressed | Compressed (in APK) | Share of APK |
|---|---:|---:|---:|
| `lib/` (native, stored) | 106,914,316 | 106,914,316 | **97.20 %** |
| `classes.dex` | 3,771,884 | 1,596,409 | 1.45 % |
| `assets/` | 1,310,862 | 1,130,340 | 1.03 % |
| `resources.arsc` | 223,228 | 223,228 | 0.20 % |
| `res/` | 141,383 | 97,013 | 0.09 % |
| `META-INF/` | 33,615 | 12,652 | 0.01 % |
| `kotlin/` + `kotlin-tooling-metadata.json` | 54,022 | 12,632 | 0.01 % |
| `AndroidManifest.xml` | 16,516 | 3,829 | < 0.01 % |
| misc (`.properties`, `DebugProbesKt.bin`) | ~5,000 | ~2,700 | < 0.01 % |

### 1.3 `lib/` per ABI

| ABI | Bytes in APK | Share of `lib/` | Redundant for the RMX2161? |
|---|---:|---:|---|
| `x86_64` | 43,044,320 | 40.3 % | yes — emulator ABI only |
| `arm64-v8a` | 36,726,656 | 34.4 % | **no — this is the device ABI** |
| `armeabi-v7a` | 27,143,340 | 25.4 % | yes — 32-bit ARM fallback |
| total | 106,914,316 | 100 % | 70,187,660 bytes are not used by an arm64 phone |

### 1.4 `lib/` per library (summed over all three ABIs)

| Library | Bytes | Owner |
|---|---:|---|
| `libjingle_peerconnection_so.so` | 35,263,068 | `flutter_webrtc` — largest single component |
| `libflutter.so` | 32,895,124 | Flutter engine |
| `libapp.so` | 24,185,196 | Dart AOT snapshot of this app |
| `libbarhopper_v3.so` | 14,100,440 | bundled MLKit barcode (via `mobile_scanner`) |
| `libdartjni.so` | 329,792 | `jni` / `flutter_webrtc` dependency |
| `libimage_processing_util_jni.so` | 106,392 | MLKit |
| `libdatastore_shared_counter.so`, `libsurface_util_jni.so` | 34,304 | plugins |

Per ABI (arm64, the device-relevant one): `libjingle_peerconnection_so.so`
12,287,312 bytes (33.4 % of the arm64 payload alone), `libflutter.so`
11,581,856, `libapp.so` 7,734,160, `libbarhopper_v3.so` 4,946,720.

### 1.5 `assets/` (1.31 MB total, 1.13 MB compressed)

| Entry | Bytes |
|---|---:|
| `assets/mlkit_barcode_models/*.tflite` (3 files) | 880,888 |
| `assets/flutter_assets/packages/cupertino_icons/.../CupertinoIcons.ttf` | 257,628 |
| `assets/flutter_assets/NOTICES.Z` | 114,086 |
| `assets/flutter_assets/fonts/MaterialIcons-Regular.otf` | **17,644** |
| `assets/flutter_assets/shaders/*.frag` | 39,480 |
| manifests / `baseline.prof` | ~1,000 |

`MaterialIcons-Regular.otf` at 17.6 KB (a full font is ~1.6 MB) proves icon
tree-shaking is already active. There is no `assets/` directory in the repository
and `android/app/src/main/res` totals ~28 KB, so no first-party asset is large.
The APK contains no `kernel_blob.bin` (release uses `libapp.so`), so the 242 MB
debug APK is not a useful comparison.

### 1.6 Current shrink/obfuscation state (verified by inspection)

| Setting | State | Evidence |
|---|---|---|
| `isMinifyEnabled` (R8) | **off** | no `minifyEnabled`/`isMinifyEnabled` in `android/`; APK still contains `kotlin/*.kotlin_builtins`, `DebugProbesKt.bin`, `kotlin-tooling-metadata.json` (R8 strips these) |
| `isShrinkResources` | **off** | same; `res/` is untouched template resources |
| ProGuard/R8 rules | **no file** | no `proguard-rules.pro` in `android/app/` |
| Icon tree-shaking | **on** (default) | 17.6 KB MaterialIcons font |
| Dart obfuscation | **off** | no `--obfuscate` in the recorded build command; no `build/symbols/` |
| ABI splits | **off by default** | the default `app-release.apk` carries three ABIs; a `--split-per-abi` build was produced and measured separately (§1.7) |
| Signing | debug keystore | `android/app/build.gradle.kts:29-33` |

### 1.7 Measured split-per-ABI artefacts (built 2026-10-27)

```bash
flutter build apk --release --split-per-abi \
  --dart-define-from-file=.tools/live_config.env
```

| Artefact | Bytes | SHA-256 | vs universal 110,247,826 |
|---|---:|---|---:|
| `app-arm64-v8a-release.apk` | 39,910,018 | `ec15b5e23252196d72c8b400df6f02d7077299d83e8902cf1e74c0fcf04d634e` | −70,337,808 (−63.8 %) |
| `app-armeabi-v7a-release.apk` | 30,340,342 | `34b9aa04d89276068b7eab5488008f742b124a899d7cf55c8a8a8749e381ca66` | −79,907,484 (−72.5 %) |
| `app-x86_64-release.apk` | 46,250,618 | `80164c708014cbddd96e6b05e6db6c0ccdf4577da769697e5ecbe79f9a0031da` | −63,997,208 (−58.0 %) |

The arm64-v8a artefact is the one for the RMX2161. It was installed with
`adb install -r` → `Success`, cold-launched, and rendered the role-selection
screen with the hosted configuration; PID alive and no `FATAL`/`AndroidRuntime`/
`E/flutter` in logcat (screenshot `.tools/evidence/device-release-arm64-launch.png`).
The measured sizes closely match the §2 row 1 estimates (−70.4 MB predicted for
arm64 → −70.3 MB measured). Signing is unchanged (still the debug keystore), so
this is packaging-only, as expected.

## 2. Options, ranked by impact and risk

Expected values are arithmetic on §1.3 (`abi lib bytes + 3,077,716 bytes of
non-`lib` payload`), so they assume the non-native part is unchanged.

| # | Option | Expected artefact | Change vs 110.2 MB | UI / function change | Risk | Verification needed |
|---|---|---|---|---|---|---|
| 1 | `--split-per-abi` | arm64 ≈ **39.8 MB**, armv7 ≈ 30.2 MB, x86_64 ≈ 46.1 MB | −70.4 MB for the device APK (−64 %) | none | **lowest** — packaging only, same code and signing | install + full checklist (§5) |
| 2 | `--target-platform android-arm64` | single APK ≈ 39.8 MB | −70.4 MB | none | lowest — one ABI, one file, simplest for the RMX2161 | same as #1 |
| 3 | `flutter build appbundle` (Play) | `.aab` contains all ABIs; Play delivers an ABI split ≈ the arm64 figure | store download ≈ 40 MB | none | low — delivery model change only | upload to internal test track; install from Play; §5 |
| 4 | `mobile_scanner` unbundled MLKit (`dev.steenbakker.mobile_scanner.useUnbundled=true`) | arm64 −5.8 MB (barhopper 4.95 + 0.88 models), armv7 −4.1 MB, x86_64 −6.8 MB | −5.8 MB on arm64 | **behavioural**: model downloaded on first scan via Google Play Services; fails on devices without Play Services; first scan needs network | medium | QR pairing scan on a real phone, offline/first-use case, BUG-010 flow |
| 5 | R8 `isMinifyEnabled` + `isShrinkResources` (+ `proguard-rules.pro`) | dex 1.60 MB → estimated 0.7–1.0 MB; plus ~65 KB Kotlin metadata and a few KB of `res`/`arsc` | **≈ 1 MB** (−1 %) | none intended, but reflection/consumer-rule failures are possible (MLKit, CameraX, `androidx.security`) | **high effort/low yield** | full checklist + QR scan + secure storage + guardian; keep a mapping file |
| 6 | `--obfuscate --split-debug-info=<dir>` | a few percent of `libapp.so` (not quantified here) | small (order 0.2–0.5 MB) | none at runtime; stack traces become unreadable | medium — symbolication | archive the mapping; force a test exception and run `flutter symbolize` |
| 7 | Remove unused deps/assets | `cupertino_icons` ≈ 116 KB compressed (unused in `lib/`); `flutter_secure_storage` is declared but not referenced in Dart (only dex) | < 0.2 MB | none intended | low-medium — pubspec/Gradle edits | `flutter pub get`, analyzer, tests, full checklist |
| 8 | `--tree-shake-icons` | already active (default) | 0 | none | n/a | none |

Notes that constrain the choices:

- **No option above changes UI or behaviour except #4** (unbundled MLKit changes
  first-scan behaviour and Play Services dependence). #6 changes only crash
  readability; #5 and #7 are meant to be behaviour-neutral but carry build-level
  risk.
- **Compression is not available for `.so` files**: `extractNativeLibs=false`
  stores them uncompressed by design (faster install, required for
  `android:extractNativeLibs="false"` + page alignment). `lib/` compressed size
  equals its uncompressed size. Re-enabling extraction would not shrink the APK.
- **The dominant cost is duplication, not code**: 70.2 MB of the 106.9 MB of
  native payload is for ABIs the test phone does not use. Fixing that is a build
  flag, not a code change.
- **`flutter_webrtc` (35.3 MB across ABIs) cannot be shrunk** without dropping a
  shipped feature (remote assistance + the camera/microphone self-test). Its
  native binary is the same for every ABI variant choice.
- **R8 is the wrong first lever**: even perfect dex shrinking removes ~1 % of
  110 MB while adding reflection risk to MLKit/CameraX/SecureStore. Do it only
  after the ABI work, and measure it separately.
- Signing must be fixed regardless of size: the current artefact is debug-signed
  and cannot be published (§4).
- **Row 1 is implemented and verified** (§1.7): `--split-per-abi` produced a
  39.9 MB arm64 APK (−63.8 %) that installed and cold-launched on the RMX2161.
  This is the recommended safe reduction — packaging only, no code, UI or
  functional change. Rows 4–7 remain unbuilt and are still estimates.

## 3. Exact commands

`.tools/live_config.env` already exists with `SUPABASE_URL` and `SUPABASE_ANON_KEY`
(key names only; values are not reproduced here). It is gitignored. All commands
run from `D:\parentcontrol_app`. Use either the FVM wrapper or the pinned binary
that produced the recorded builds:

```bash
# FVM wrapper
fvm flutter <args>

# Pinned binary used for the recorded builds
"C:\Users\ASUS\fvm\versions\3.44.6\bin\flutter.bat" <args>
```

### 3.1 Baseline (already measured, rebuild only if needed)

```bash
fvm flutter build apk --release --dart-define-from-file=.tools/live_config.env
# -> build/app/outputs/flutter-apk/app-release.apk
```

### 3.2 Per-ABI split (recommended, smallest change)

```bash
fvm flutter build apk --release --split-per-abi \
  --dart-define-from-file=.tools/live_config.env
# -> build/app/outputs/flutter-apk/app-armeabi-v7a-release.apk
# -> build/app/outputs/flutter-apk/app-arm64-v8a-release.apk   <- RMX2161
# -> build/app/outputs/flutter-apk/app-x86_64-release.apk
```

Clean up stale artifacts first if the output directory already holds a
`app-release.apk` from an earlier variant, so a mixed set is never measured.

### 3.3 Single ABI for the test device (one file, no split naming)

```bash
fvm flutter build apk --release --target-platform android-arm64 \
  --dart-define-from-file=.tools/live_config.env
# -> build/app/outputs/flutter-apk/app-release.apk (~39.8 MB expected)
```

### 3.4 Play bundle

```bash
fvm flutter build appbundle --release \
  --dart-define-from-file=.tools/live_config.env
# -> build/app/outputs/bundle/release/app-release.aab
```

### 3.5 Split + obfuscation (only if symbolication is set up)

```bash
fvm flutter build apk --release --split-per-abi \
  --obfuscate --split-debug-info=build/symbols/v1.0.0 \
  --dart-define-from-file=.tools/live_config.env
```

`build/symbols/` is inside the build tree and `.gitignore` already excludes
`app.*.map.json` / `app.*.symbols`; archive the directory outside the repo per
release (it is required to read any future crash). Symbolicate with:

```bash
fvm flutter symbolize -i <stack.txt> -d build/symbols/v1.0.0
```

### 3.6 Do not combine

- `--split-per-abi` and `--target-platform` in the same invocation (the split
  already determines the ABI set).
- Changing ABI options in the *same* output directory without clearing previous
  APKs, otherwise SHA-256 bookkeeping mixes variants.

## 4. Release signing procedure

Current state — `android/app/build.gradle.kts`:

```kotlin
buildTypes {
    release {
        // TODO: Add your own signing config for the release build.   <- line 30
        // Signing with the debug keys for now, so `flutter run --release` works.
        signingConfig = signingConfigs.getByName("debug")               // line 32
    }
}
```

`apksigner` confirms the APK is signed by `CN=Android Debug`. That key is shared
by every debug build on this machine; it must never reach a store, and switching
to a real key changes the app signature, so the phone must **uninstall** the
debug-signed build before installing a release-signed one.

### 4.1 Create the upload keystore outside the repository

```bash
mkdir -p "$HOME/.android-keys"
keytool -genkeypair -v \
  -keystore "$HOME/.android-keys/parentcontrol-upload.jks" \
  -alias upload -keyalg RSA -keysize 4096 -validity 10000 \
  -dname "CN=Parent Control, OU=Mobile, O=Parent Control, L=Seoul, C=KR"
```

- Path must stay outside `D:\parentcontrol_app` (the command above resolves to
  `C:\Users\ASUS\.android-keys\...`).
- `keytool` prompts for the store/key password; do not pass it on the command
  line (shell history / process list).
- Back up the `.jks` and both passwords in a password manager. Losing the upload
  key means a new upload key must be registered (Play App Signing) or the app
  cannot be updated under the same listing.

### 4.2 `key.properties` (gitignored)

Create `android/key.properties`. `.gitignore` already contains `key.properties`,
`*.jks`, `*.keystore`, so the file must never be force-added:

```properties
storePassword=<store password>
keyPassword=<key password>
keyAlias=upload
storeFile=C:/Users/ASUS/.android-keys/parentcontrol-upload.jks
```

Use forward slashes in `storeFile`; a Windows path with backslashes is read as
escapes by the `Properties` loader.

### 4.3 Wire `signingConfigs.release` (owner of `android/app/build.gradle.kts`)

```kotlin
import java.util.Properties
import java.io.FileInputStream

val keystoreProperties = Properties().apply {
    val f = rootProject.file("key.properties")
    if (f.exists()) FileInputStream(f).use { load(it) }
}

android {
    signingConfigs {
        create("release") {
            if (keystoreProperties.isNotEmpty()) {
                keyAlias = keystoreProperties["keyAlias"] as String
                keyPassword = keystoreProperties["keyPassword"] as String
                storeFile = file(keystoreProperties["storeFile"] as String)
                storePassword = keystoreProperties["storePassword"] as String
            }
        }
    }
    buildTypes {
        release {
            signingConfig = signingConfigs.getByName("release")
        }
    }
}
```

Replace the TODO block at lines 29–33; do not leave `debug` as a fallback for a
shipped artefact. Fail the build when `key.properties` is missing rather than
silently debug-signing (the condition above keeps `flutter run --release` usable
for developers; a release job should assert the signing certificate instead).

- Never commit the keystore, `key.properties`, or a password into Gradle files,
  CI YAML, docs or issue trackers.
- Verify before distribution:
  `"$LOCALAPPDATA/Android/Sdk/build-tools/36.0.0/apksigner.bat" verify --print-certs <apk>`
  must show the upload certificate, not `CN=Android Debug`.
- Prefer Play App Signing: the upload key only authorizes uploads; Google holds
  the app-signing key and can reset a lost upload key.

## 5. Regression checklist after each variant

Run on the RMX2161 (`5HXWRGQ4IFU8WS4T`, Android 12) for every APK variant, and
on an emulator only if an x86_64 artefact is kept.

| # | Check | Pass criterion |
|---|---|---|
| 1 | Install | `adb install -r <apk>` → `Success`; after any signing change use `adb uninstall com.parentcontrol.parent_control` first (signature mismatch fails the update) |
| 2 | Launch | cold start; `MainActivity` resumed; PID alive; no `FATAL`, `AndroidRuntime` or `E/flutter` in `adb logcat` |
| 3 | Sign-in | parent and child QA accounts sign in against the hosted project; role bootstrap reaches the correct shell |
| 4 | Camera self-test | Settings → Camera and microphone test: `Main camera live`, `Video frames 1280×720 received`, switch to front, mute, stop — this also proves `libjingle_peerconnection_so.so` and `getUserMedia` load |
| 5 | WebRTC native load | no `Failed to load native library` / `UnsatisfiedLinkError` in logcat; a remote-assistance session request reaches ICE with `ice_servers` (STUN-only is expected, TURN is not configured) |
| 6 | Secure storage | device credential survives app restart (EncryptedSharedPreferences via `SecureStore.kt`); sign-out keeps the local identity secret; no `GeneralSecurityException` in logcat |
| 7 | Guardian service | Background protection reaches `Running` with the foreground notification; heartbeat advances server `last_seen`; policy ack works; Usage Access still reported as denied on this phone (expected) |
| 8 | QR pairing | child generates code, parent scans it (`mobile_scanner` path) — mandatory for the unbundled-MLKit variant, recommended for R8 |
| 9 | Symbolication (obfuscated builds only) | trigger a known exception, capture the stack, `flutter symbolize` resolves app frames |
| 10 | Size/hash | record bytes + SHA-256 (§6) and confirm the installed APK is the measured file (`adb shell pm path`, then compare the pulled hash if in doubt) |

Keep the previous APK on the phone or in `.tools/` until the variant passes all
rows; an ABI split removes fallback ABIs, so a wrong ABI choice shows up as
`INSTALL_FAILED_NO_MATCHING_ABIS` only at install time.

## 6. Measurement protocol (for the main agent to fill in)

Record, per variant: on-disk bytes, SHA-256, entry totals, per-ABI `lib` bytes,
signing certificate, and install result. Read-only commands:

```bash
cd /d/parentcontrol_app
for f in build/app/outputs/flutter-apk/app*-release.apk; do
  echo "== $f"
  stat -c '%n %s bytes' "$f"
  sha256sum "$f"
  unzip -l "$f" | tail -1
  unzip -l "$f" | awk '/lib\/.*\.so$/ {split($4,a,"/"); s[a[2]]+=$1} END {for (k in s) printf "  %s %d\n", k, s[k]}'
  "$LOCALAPPDATA/Android/Sdk/build-tools/36.0.0/aapt.exe" dump badging "$f" | grep native-code
done
```

Expected result table (fill the **Measured** columns; do not infer them from the
estimates):

| Variant | Command | Expected bytes (est.) | Measured bytes | SHA-256 | Signing cert | Install |
|---|---|---:|---:|---|---|---|
| baseline universal | `build apk --release` | 110,247,706 | 110,247,826 (current rebuild) | `51ea1c4f…fc93` | Android Debug | PASS (recorded) |
| split arm64 | `--split-per-abi` | ≈ 39,804,372 | **39,910,018** | `ec15b5e2…634e` | Android Debug | **PASS** (installed + cold-launched) |
| split armv7 | `--split-per-abi` | ≈ 30,221,056 | **30,340,342** | `34b9aa04…ca66` | Android Debug | not installed (no 32-bit device) |
| split x86_64 | `--split-per-abi` | ≈ 46,122,036 | **46,250,618** | `80164c70…31da` | Android Debug | not installed (no x86_64 device) |
| single arm64 | `--target-platform android-arm64` | ≈ 39,804,372 | TBD | TBD | TBD | TBD |
| appbundle | `build appbundle --release` | not estimated | TBD | TBD | TBD | via Play track |
| split arm64 + obfuscate | `--split-per-abi --obfuscate` | ≤ 39.8 MB | TBD | TBD | TBD | TBD |
| split arm64 + R8 | Gradle flags §2 row 5 | ≈ 38.8–39.1 MB | TBD | TBD | TBD | TBD |

Record the mapping directory and build date next to each obfuscated row; a hash
without its symbol archive cannot be debugged later.

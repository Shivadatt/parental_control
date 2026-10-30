# Android delivery hygiene — Phase 1 notes

## What changed

- `android/app/build.gradle.kts`: loads `android/key.properties` (`storeFile`,
  `storePassword`, `keyAlias`, `keyPassword`) at configuration time. When all four are present a
  `release` signing config is created and used by the `release` build type; otherwise the release
  type keeps `signingConfigs.getByName("debug")` and Gradle prints
  `WARNING: release build signed with DEBUG key - not shippable. ...` during configuration.
  `flutter run --release` therefore still works without a keystore.
- `android/key.properties.example` (new): template only, fake values. Relative `storeFile` paths are
  resolved against `android/app/`.
- `android/app/src/main/res/xml/network_security_config.xml` (new): single `base-config`
  `cleartextTrafficPermitted="false"`; no domain exceptions, no pinning (TODO in the file).
- `AndroidManifest.xml`: `<application android:networkSecurityConfig="@xml/network_security_config">`.
- `MainActivity.kt`: validates the exported auth-callback intent. Only
  `ACTION_VIEW` + scheme `parentcontrol` + host `auth-callback` + non-empty `code` (query) or
  `access_token` (query or fragment) is forwarded to Flutter/Supabase. A cold start from any other
  `parentcontrol://` link has its data/action cleared before `super.onCreate`, so the app opens
  normally; while running (singleTop) unknown links are ignored in `onNewIntent` (super not called).
  The activity stays exported and no component was added.
- `.gitignore`: no edit needed. Root `.gitignore` already has `key.properties`, `*.jks`,
  `*.keystore`; `android/.gitignore` repeats them.

## Verified

- `grep "http://"` over `lib/` and Kotlin sources: no hits. The only `http://` strings under
  `android/` are XML namespace URIs, so disabling cleartext breaks no current host.
- Source manifests: no `android:debuggable`, no `android:usesCleartextTraffic`, `allowBackup="false"`
  retained. No permissions added.
- Merged debug manifest (from the build) carries `networkSecurityConfig` and `allowBackup="false"`;
  `debuggable="true"` is injected by the debug build type only.

## Validation

- `./.fvm/flutter_sdk/bin/flutter build apk --debug` → `√ Built build\app\outputs\flutter-apk\app-debug.apk`.
  First attempt failed on a script-compilation error (`java.util` shadowed by the Gradle `java`
  extension accessor); fixed with imports and rebuilt successfully.
- `./android/gradlew help` → warning text above printed (fallback path).
- No Kotlin unit test added: the validator relies on `android.net.Intent`/`Uri` and Robolectric is
  not a dependency (no new deps allowed). Build is the only compile check.
- Not tested on a device: valid callback still opens the verify screen; malformed `parentcontrol://`
  link opens the app. Error-shaped callbacks (`?error=...`) are intentionally ignored, so the user
  must use "Refresh verification".

## Follow-up

- Certificate pinning: no stable pins available; add `<pin-set>` with backup pin when pins exist.
- Before shipping: create `android/key.properties` + a real keystore, then verify
  `apksigner verify --print-certs` on the release APK (not done here).
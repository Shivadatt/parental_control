# 10 — Automated Verification

These checks were run after the fresh build and do not replace the manual results.

| Check | Command | Result |
|---|---|---|
| Dart/Flutter analysis | `.fvm/flutter_sdk/bin/flutter analyze` | **No issues found** (91.2 s) |
| Flutter unit/widget tests | `.fvm/flutter_sdk/bin/flutter test` | **493 passed, 0 failed** (31 s) |
| Deno Edge tests | `deno test --allow-read supabase/functions/` | **209 passed, 0 failed** (6 s) |
| Kotlin app unit tests | `./gradlew :app:testDebugUnitTest` | **BUILD SUCCESSFUL**; 57 tests, 0 failures, 0 errors, 0 skipped |
| Aggregate Gradle task | `./gradlew testDebugUnitTest` | Fails while configuring `flutter_secure_storage` because plugin and build roots differ (environment/plugin-path issue) |
| SQL regression chain | Not run | Requires disposable PostgreSQL/DB execution outside this phase's authorization |

Logs:

- `test_results/flutter_analyze.log`
- `test_results/flutter_test.log`
- `test_results/deno_edge_tests.log`
- `test_results/kotlin_app_tests.log` (success)
- `test_results/kotlin_tests.log` (aggregate failure)

## Interpretation

The automated suites are green, including 493 Flutter tests and 209 Edge tests.
They do not cover the live credential/heartbeat path that failed in manual testing.
The Kotlin app tests pass; only the multi-project aggregate task fails during
plugin configuration, before application tests execute.

No source code was modified to make any check pass.

# 09 — Fix Verification & Regression Test Plan

**Document ID:** HAVEN-REM-009  
**Phase:** Phase 1 — Remediation Planning (Strictly Planning-Only)  
**Date:** 2026-11-23  
**Status:** DRAFT FOR OWNER REVIEW & APPROVAL  
**Workspace:** `D:\parentcontrol_app`  
**Git Baseline HEAD:** `5ffc5c170add4bfafd236beb633f00b6fe86243b`  

---

## 1. Overview & Verification Philosophy

To ensure that each defect is definitively resolved without introducing collateral regressions, this verification plan establishes a multi-tiered test strategy spanning unit, widget, database, native, and controlled device testing.

Every test plan adheres to the **Absolute Safety & Credential Protection Rules**:
- **Zero Live Session Invalidation**: Automated tests must use mock sessions or isolated test accounts; never touch live QA tokens.
- **Zero Real Credential Exposure**: Never log or assert against real passwords or API secrets.
- **Hermetic Isolation**: Backend and database tests run in disposable test containers or mock environments.

---

## 2. Test Matrix by Defect

| Defect ID | Title | Test Level | Test Suite / Target Path | Primary Verification Assertion |
|---|---|---|---|---|
| **HAVEN-QA-001** | Role Selection Button Truncation | Widget Test | `test/features/role_selection/role_selection_page_test.dart` | Label "Create account" is 100% visible with zero text clipping at 360dp width. |
| **HAVEN-QA-002** | Password Security (`SEC-001`) | Widget Test | `test/core/widgets/app_text_field_security_test.dart` | `enableSuggestions == false`, `autocorrect == false`, `Semantics.isPassword == true`. |
| **HAVEN-QA-003** | Device Re-credentialing (`DEF-601`) | Deno + SQL | `supabase/functions/device-register/recredential_test.ts`, `supabase/tests/46_recredentialing.sql` | Atomic secret rotation replaces `secret_hash`, preserves UUID, permits subsequent heartbeat. |
| **HAVEN-QA-004** | Notification Permission Detection (`DEF-604`) | Native JUnit | `android/app/src/test/kotlin/.../NativePermissionsTest.kt` | Returns `false` when notification toggle is disabled on Android 12 (`API 31`). |
| **HAVEN-QA-005** | Revoked Devices Filter (`DEF-602`) | Unit Test | `test/data/repositories/supabase_device_repository_test.dart` | `fetchDevices()` excludes `status == 'revoked'` rows by default. |
| **HAVEN-QA-006** | Policy Version Consistency (`DEF-603`) | Unit Test | `test/features/devices/device_presentation_test.dart` | `policySummary()` projects identical descriptive string across Dashboard and Devices tabs. |

---

## 3. Detailed Test Specifications

---

### 3.1 HAVEN-QA-001: Role Selection Button Layout Test

#### Target Test File: `test/features/role_selection/role_selection_page_test.dart`
```dart
testWidgets('RoleSelectionPage: action buttons render complete labels without clipping on 360dp display', (tester) async {
  // Set screen dimensions to match 1080x2400 @ 480dpi (360x800 dp)
  tester.view.physicalSize = const Size(1080, 2400);
  tester.view.devicePixelRatio = 3.0;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);

  await tester.pumpWidget(
    const MaterialApp(
      home: RoleSelectionPage(),
    ),
  );
  await tester.pumpAndSettle();

  // Find all "Create account" button texts
  final createAccountButtons = find.text('Create account');
  expect(createAccountButtons, findsNWidgets(2)); // Parent card & Child card

  // Verify RenderParagraph does not truncate
  for (final element in createAccountButtons.evaluate()) {
    final renderParagraph = element.renderObject as RenderParagraph;
    expect(renderParagraph.didExceedMaxLines, isFalse);
  }
});
```

---

### 3.2 HAVEN-QA-002: Password Security (`SEC-001`) Test

#### Target Test File: `test/core/widgets/app_text_field_security_test.dart`
```dart
testWidgets('AppTextField: enforces secure text input hardening flags when obscureText is true', (tester) async {
  final controller = TextEditingController();
  await tester.pumpWidget(
    MaterialApp(
      home: Scaffold(
        body: AppTextField(
          controller: controller,
          label: 'Password',
          obscureText: true,
        ),
      ),
    ),
  );

  final editableFinder = find.byType(EditableText);
  final editableWidget = tester.widget<EditableText>(editableFinder);

  // Security Hardening Invariants:
  expect(editableWidget.obscureText, isTrue);
  expect(editableWidget.enableSuggestions, isFalse, reason: 'SEC-001: suggestions must be disabled');
  expect(editableWidget.autocorrect, isFalse, reason: 'SEC-001: autocorrect must be disabled');

  // Accessibility Semantics Invariant:
  final semantics = tester.getSemantics(find.byType(AppTextField));
  expect(semantics.isPassword, isTrue, reason: 'SEC-001: accessibility node must declare isPassword');
});
```

---

### 3.3 HAVEN-QA-004: Android Notification Detection Native Test

#### Target Test File: `android/app/src/test/kotlin/com/parentcontrol/parent_control/NativePermissionsTest.kt`
```kotlin
@RunWith(RobolectricTestRunner::class)
@Config(sdk = [Build.VERSION_CODES.S]) // Android 12 (API 31)
class NativePermissionsTest {

    @Test
    fun `hasNotifications returns false on Android 12 when notifications are disabled in system`() {
        val context = ApplicationProvider.getApplicationContext<Context>()
        val shadowNotificationManager = Shadows.shadowOf(
            context.getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
        )
        shadowNotificationManager.setNotificationsEnabled(false)

        val result = NativePermissions.hasNotifications(context)
        assertFalse("Notification permission must report false when disabled in settings", result)
    }

    @Test
    fun `hasNotifications returns true on Android 12 when notifications are enabled in system`() {
        val context = ApplicationProvider.getApplicationContext<Context>()
        val shadowNotificationManager = Shadows.shadowOf(
            context.getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
        )
        shadowNotificationManager.setNotificationsEnabled(true)

        val result = NativePermissions.hasNotifications(context)
        assertTrue("Notification permission must report true when enabled in settings", result)
    }
}
```

---

### 3.4 HAVEN-QA-005: Device Repository Query Filter Test

#### Target Test File: `test/data/repositories/supabase_device_repository_test.dart`
```dart
test('fetchDevices excludes revoked devices by default', () async {
  final mockClient = MockSupabaseClient();
  // Setup mock data with 1 active device and 1 revoked device
  final mockRows = [
    {'id': 'd1', 'family_id': 'f1', 'status': 'active', 'display_name': 'Child Phone'},
  ];
  when(mockClient.from('devices').select(any).eq('family_id', 'f1').neq('status', 'revoked'))
      .thenAnswer((_) => FakePostgrestFilterBuilder(mockRows));

  final repo = SupabaseDeviceRepository(supabase: mockClient, edgeApi: mockEdgeApi);
  final devices = await repo.fetchDevices('f1');

  expect(devices.length, equals(1));
  expect(devices.first.status, equals('active'));
});
```

---

### 3.5 HAVEN-QA-006: Policy Version Consistency Test

#### Target Test File: `test/features/devices/device_presentation_test.dart`
```dart
group('policySummary presentation harmonization', () {
  test('displays pending sync transition when desired version exceeds applied version', () {
    final status = resolvePolicyStatus(
      appliedVersion: 2,
      desiredPolicy: const DevicePolicy(id: 'p1', deviceId: 'd1', version: 4, status: PolicyEnforcementStatus.active),
    );

    expect(status.isPendingSync, isTrue);
    expect(status.label, contains('Policy v2 · Updating to v4...'));
    expect(status.versionText, equals('v2 → v4'));
  });

  test('displays unified enforced string when applied equals desired version', () {
    final status = resolvePolicyStatus(
      appliedVersion: 4,
      desiredPolicy: const DevicePolicy(id: 'p1', deviceId: 'd1', version: 4, status: PolicyEnforcementStatus.active),
    );

    expect(status.isPendingSync, isFalse);
    expect(status.label, equals('Policy v4 · Active'));
  });
});
```

---

### 3.6 HAVEN-QA-003: Device Re-credentialing Database & Protocol Suite

#### Target Test File: `supabase/tests/46_recredentialing.sql`
```sql
-- Test 46: Device Re-credentialing Protocol Verification
do $$
declare
  v_family1 uuid := tests.get('family1')::uuid;
  v_device1 uuid := 'd0000000-0000-4000-8000-000000000001';
  v_child1 uuid := '33333333-3333-4333-8333-333333333333';
  v_parent1 uuid := '11111111-1111-4111-8111-111111111111';
  v_challenge_token text := 'test_token_123456';
  v_token_hash text := encode(digest(v_challenge_token, 'sha256'), 'hex');
  v_new_secret_hash text := repeat('a', 64);
  v_result jsonb;
begin
  -- 1. Insert challenge
  insert into public.device_recovery_challenges (
    family_id, device_id, child_user_id, challenge_hash, created_by
  ) values (
    v_family1, v_device1, v_child1, v_token_hash, v_parent1
  );

  -- 2. Execute rotate_device_secret as child1
  v_result := public.rotate_device_secret(
    v_device1,
    v_challenge_token,
    'new_installation_uuid_123',
    v_new_secret_hash,
    v_child1
  );

  -- 3. Assertions
  perform tests.assert_true((v_result ->> 'ok')::boolean = true, 'Rotation succeeded');
  perform tests.assert_true(
    (select secret_hash from public.devices where id = v_device1) = v_new_secret_hash,
    'Device secret_hash was atomically updated'
  );
  perform tests.assert_true(
    (select consumed_at from public.device_recovery_challenges where device_id = v_device1) is not null,
    'Challenge was consumed'
  );
end;
$$;
```

---

## 4. Acceptance Criteria & Sign-Off Checklist

Before any defect is closed as fixed:
- [ ] Automated test suite passes with zero warnings or errors.
- [ ] No regression detected in adjacent screens or shared widgets.
- [ ] Static analysis passes (`flutter analyze` reports 0 issues).
- [ ] Existing Parent and Child QA sessions remain completely preserved.
- [ ] Owner signs off on verification results in the approval register.

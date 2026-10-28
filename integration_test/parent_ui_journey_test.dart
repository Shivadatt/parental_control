// Device journey test: parent-facing UI end to end on ONE physical Android
// phone, using only public widgets and visible text (no service calls, no
// repository shortcuts).
//
// WHAT IS AUTOMATED
//  1. Cold launch, normalisation of a pre-existing session (signs out), and a
//     deliberately invalid sign-in that must show "Could not sign in" without
//     entering a shell.
//  2. Parent sign-in, family creation when the account has none, and detection
//     of an already-linked active device.
//  3. When no active device exists: child sign-in, link/consent, the permanent
//     Child ID shown on the child setup screen, the parent sending a pairing
//     request with that ID, child approval, child device registration, and
//     parent verification of the linked device in the list and detail screen.
//  4. Device detail, App restrictions, the honest Device Owner limitation
//     banners, a benign policy save (all app blocks cleared) asserted as
//     pending acknowledgement, and an optional revoke gated behind QA_REVOKE.
//
// KNOWLEDGE / DIRECTION DEVIATION (documented bug BUG-010)
//  The brief says "create a child pairing code through the UI" while signed in
//  as the parent. The app uses the permanent Child ID instead: the CHILD device
//  displays it (child_enrollment_page.dart) and the PARENT enters it
//  (pairing_redeem_page.dart). The old "Create linking code" control is gone.
//  This test follows the implemented direction and asserts the Child ID on the
//  child UI; there is no parent "create code" control to drive.
//
// PREREQUISITES (not automated: system UI / server data)
//  - QA_PARENT_* and QA_CHILD_* must be a matched pair: the child must either be
//    unlinked or belong to the parent's active family. A child in a different
//    family fails with an explicit message instead of silently destroying the
//    other family. If the child is linked to the same family but has no active
//    device (e.g. after a previous QA_REVOKE run), the test unlinks and
//    re-pairs through the UI.
//  - Grant CAMERA before running, otherwise the Android permission dialog sits
//    over the QR scanner on "Link a child":
//      adb shell pm grant com.parentcontrol.parent_control android.permission.CAMERA
//  - Both accounts must be email-verified with a server role, and the hosted
//    Edge Functions (pairing, device-register, family-admin) must be deployed.
//  - Device Owner enforcement is unavailable on the verification phone, so the
//    test asserts the honest "unsupported" copy, never "enforced".
//
// POSSIBLE MANUAL REMAINDER
//  - If a pending pairing request for the same family already exists, the test
//    approves it instead of creating a new code (documented fallback).
//  - Camera permission, account verification/roles and any server-side rate
//    limit are external prerequisites, not asserted as app behaviour.
//
// This test has NOT been run. Do not treat it as green until it is.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:parent_control/core/widgets/widgets.dart';
import 'package:parent_control/main.dart' as app;

const String _parentEmail = String.fromEnvironment('QA_PARENT_EMAIL');
const String _parentPassword = String.fromEnvironment('QA_PARENT_PASSWORD');
const String _childEmail = String.fromEnvironment('QA_CHILD_EMAIL');
const String _childPassword = String.fromEnvironment('QA_CHILD_PASSWORD');
const bool _revokeAtEnd = bool.fromEnvironment('QA_REVOKE');

// A value that satisfies local validation so the server answers, but is never
// a real credential. Used only for the negative sign-in assertion.
const String _invalidPassword = 'qa-invalid-password-2026';
const String _phoneName = 'QA parent journey phone';

Finder _button(String label) => find.byWidgetPredicate(
  (widget) => widget is AppButton && widget.label == label,
);

Finder _nav(String label) =>
    find.descendant(of: find.byType(NavigationBar), matching: find.text(label));

bool _onParentShell() => _nav('Devices').evaluate().isNotEmpty;
bool _onChildShell() => _nav('Rules').evaluate().isNotEmpty;
bool _onRoleSelection() =>
    find.text('How will you use Parent Control?').evaluate().isNotEmpty;

bool _appBarHas(String title) => find
    .descendant(of: find.byType(AppBar), matching: find.text(title))
    .evaluate()
    .isNotEmpty;

String _visibleTexts() {
  final buffer = StringBuffer();
  for (final element in find.byType(Text).evaluate()) {
    final data = (element.widget as Text).data;
    if (data == null) continue;
    final value = data.trim();
    if (value.isEmpty) continue;
    buffer.write(value);
    buffer.write(' | ');
  }
  final raw = buffer.toString();
  return raw.length <= 900 ? raw : '${raw.substring(0, 900)}…';
}

void _mark(String step) {
  // ignore: avoid_print
  print('VISIBLE $step: ${_visibleTexts()}');
}

Future<bool> _pumpUntil(
  WidgetTester tester,
  bool Function() condition, {
  Duration timeout = const Duration(seconds: 40),
}) async {
  final deadline = DateTime.now().add(timeout);
  while (DateTime.now().isBefore(deadline)) {
    await tester.pump(const Duration(milliseconds: 250));
    if (condition()) return true;
  }
  return condition();
}

Finder? _scrollable() {
  final lists = find.byType(ListView);
  if (lists.evaluate().isNotEmpty) return lists.first;
  final singles = find.byType(SingleChildScrollView);
  if (singles.evaluate().isNotEmpty) return singles.first;
  final scrollables = find.byType(Scrollable);
  if (scrollables.evaluate().isNotEmpty) return scrollables.first;
  return null;
}

/// Scrolls the visible page until [target] is built and inside the safe area
/// (above the bottom navigation bar, below the app bar).
Future<bool> _reveal(
  WidgetTester tester,
  Finder target, {
  int attempts = 30,
}) async {
  for (var attempt = 0; attempt < attempts; attempt++) {
    if (target.evaluate().isNotEmpty) {
      final rect = tester.getRect(target.first);
      if (rect.top >= 72 && rect.bottom <= 660) return true;
      final scrollable = _scrollable();
      if (scrollable == null) return false;
      final delta = rect.top < 72 ? 320.0 : -320.0;
      await tester.drag(scrollable, Offset(0, delta));
    } else {
      final scrollable = _scrollable();
      if (scrollable == null) return false;
      await tester.drag(scrollable, const Offset(0, -380));
    }
    await tester.pump(const Duration(milliseconds: 300));
  }
  if (target.evaluate().isEmpty) return false;
  final rect = tester.getRect(target.first);
  return rect.top >= 0 && rect.bottom <= 720;
}

Future<void> _dismissOverlays(WidgetTester tester) async {
  FocusManager.instance.primaryFocus?.unfocus();
  for (var attempt = 0; attempt < 3; attempt++) {
    final dismiss = find.text('Dismiss');
    if (dismiss.evaluate().isEmpty) break;
    await tester.tap(dismiss.first, warnIfMissed: false);
    await tester.pump(const Duration(milliseconds: 350));
  }
  await tester.pump(const Duration(milliseconds: 150));
}

Future<void> _tap(
  WidgetTester tester,
  Finder target, {
  required String what,
}) async {
  await _dismissOverlays(tester);
  final visible = await _reveal(tester, target);
  expect(
    visible,
    isTrue,
    reason: 'Could not bring "$what" on screen. Visible: ${_visibleTexts()}',
  );
  expect(
    target,
    findsWidgets,
    reason: 'Widget "$what" is missing. Visible: ${_visibleTexts()}',
  );
  await tester.tap(target.first);
  await tester.pump(const Duration(milliseconds: 450));
}

Future<void> _openTab(WidgetTester tester, String label) async {
  final tab = _nav(label);
  expect(
    tab,
    findsOneWidget,
    reason: 'Navigation tab "$label" is missing. Visible: ${_visibleTexts()}',
  );
  await tester.tap(tab);
  await tester.pump(const Duration(milliseconds: 500));
}

Future<void> _confirmDialog(
  WidgetTester tester,
  String title,
  String confirmLabel,
) async {
  final dialog = find.byType(AlertDialog);
  final appeared = await _pumpUntil(
    tester,
    () => dialog.evaluate().isNotEmpty,
    timeout: const Duration(seconds: 15),
  );
  expect(
    appeared,
    isTrue,
    reason: 'Dialog "$title" did not appear. Visible: ${_visibleTexts()}',
  );
  final confirm = find.descendant(
    of: dialog,
    matching: find.widgetWithText(FilledButton, confirmLabel),
  );
  expect(
    confirm,
    findsOneWidget,
    reason:
        'Dialog "$title" has no "$confirmLabel" confirmation. Visible: ${_visibleTexts()}',
  );
  await tester.tap(confirm);
  await tester.pump(const Duration(milliseconds: 600));
}

String _appBarTitle(WidgetTester tester) {
  final bars = find.byType(AppBar);
  if (bars.evaluate().isEmpty) return '';
  final texts = find.descendant(of: bars.first, matching: find.byType(Text));
  for (final element in texts.evaluate()) {
    final data = (element.widget as Text).data?.trim() ?? '';
    if (data.isNotEmpty) return data;
  }
  return '';
}

Future<void> _openSignIn(WidgetTester tester, String roleTitle) async {
  final card = find
      .ancestor(of: find.text(roleTitle), matching: find.byType(SectionCard))
      .first;
  final signIn = find.descendant(of: card, matching: _button('Sign in'));
  await _tap(tester, signIn, what: '$roleTitle > Sign in');
  final opened = await _pumpUntil(
    tester,
    () => find.text('Welcome back').evaluate().isNotEmpty,
    timeout: const Duration(seconds: 20),
  );
  expect(
    opened,
    isTrue,
    reason:
        'The login page did not open for $roleTitle. Visible: ${_visibleTexts()}',
  );
}

Future<void> _submitLogin(
  WidgetTester tester,
  String email,
  String password,
) async {
  final fields = find.byType(TextField);
  expect(
    fields,
    findsNWidgets(2),
    reason:
        'The login form does not have exactly two fields. Visible: ${_visibleTexts()}',
  );
  await _dismissOverlays(tester);
  await tester.enterText(fields.at(0), email);
  await tester.enterText(fields.at(1), password);
  await tester.pump(const Duration(milliseconds: 250));
  await _dismissOverlays(tester);
  await _tap(tester, _button('Sign in'), what: 'Sign in submit');
}

Future<void> _signOutParent(
  WidgetTester tester, {
  required String phase,
}) async {
  await _openTab(tester, 'Settings');
  await _tap(tester, _button('Sign out'), what: '$phase: parent Sign out');
  await _confirmDialog(tester, 'Sign out?', 'Sign out');
  final done = await _pumpUntil(
    tester,
    _onRoleSelection,
    timeout: const Duration(seconds: 60),
  );
  expect(
    done,
    isTrue,
    reason:
        '$phase: parent sign-out did not reach role selection. Visible: ${_visibleTexts()}',
  );
}

Future<void> _signOutChild(WidgetTester tester, {required String phase}) async {
  await _openTab(tester, 'Settings');
  await _pumpUntil(
    tester,
    () => _appBarHas('This phone settings'),
    timeout: const Duration(seconds: 20),
  );
  await _tap(tester, _button('Sign out'), what: '$phase: child Sign out');
  await _confirmDialog(tester, 'Sign out?', 'Sign out');
  final done = await _pumpUntil(
    tester,
    _onRoleSelection,
    timeout: const Duration(seconds: 60),
  );
  expect(
    done,
    isTrue,
    reason:
        '$phase: child sign-out did not reach role selection. Visible: ${_visibleTexts()}',
  );
}

Future<void> _createFamily(WidgetTester tester, {required String phase}) async {
  final onForm = await _pumpUntil(
    tester,
    () => find.text('Create your family').evaluate().isNotEmpty,
    timeout: const Duration(seconds: 30),
  );
  expect(
    onForm,
    isTrue,
    reason:
        '$phase: family setup page did not open. Visible: ${_visibleTexts()}',
  );
  final fields = find.byType(TextField);
  expect(
    fields,
    findsOneWidget,
    reason:
        '$phase: family name field is not unique. Visible: ${_visibleTexts()}',
  );
  final suffix = DateTime.now().millisecondsSinceEpoch % 100000;
  await tester.enterText(fields.first, 'QA household $suffix');
  await tester.pump(const Duration(milliseconds: 250));
  await _tap(tester, _button('Create family'), what: '$phase: Create family');
  final arrived = await _pumpUntil(
    tester,
    _onParentShell,
    timeout: const Duration(seconds: 90),
  );
  expect(
    arrived,
    isTrue,
    reason:
        '$phase: family creation did not reach the parent shell. Visible: ${_visibleTexts()}',
  );
}

Future<void> _waitDashboard(
  WidgetTester tester, {
  required String phase,
}) async {
  bool loaded() =>
      find.text('Quick links').evaluate().isNotEmpty ||
      find.text('No child linked yet').evaluate().isNotEmpty ||
      find.text('No family set up yet').evaluate().isNotEmpty ||
      find.text('Open device').evaluate().isNotEmpty ||
      find.textContaining('Could not refresh').evaluate().isNotEmpty;
  var ready = await _pumpUntil(
    tester,
    loaded,
    timeout: const Duration(seconds: 60),
  );
  expect(
    ready,
    isTrue,
    reason: '$phase: the dashboard did not load. Visible: ${_visibleTexts()}',
  );
  if (find.text('No family set up yet').evaluate().isNotEmpty) {
    await _tap(
      tester,
      find.widgetWithText(FilledButton, 'Set up family'),
      what: '$phase: Set up family',
    );
    await _createFamily(tester, phase: '$phase family setup');
    ready = await _pumpUntil(
      tester,
      loaded,
      timeout: const Duration(seconds: 60),
    );
    expect(
      ready,
      isTrue,
      reason:
          '$phase: the dashboard did not load after family setup. Visible: ${_visibleTexts()}',
    );
  }
}

Future<void> _waitForParentShell(
  WidgetTester tester, {
  required String phase,
}) async {
  final arrived = await _pumpUntil(
    tester,
    () =>
        _onParentShell() ||
        find.text('Create your family').evaluate().isNotEmpty ||
        find.text('Verify email').evaluate().isNotEmpty,
    timeout: const Duration(seconds: 90),
  );
  expect(
    arrived,
    isTrue,
    reason:
        '$phase: parent sign-in produced no destination. Visible: ${_visibleTexts()}',
  );
  if (find.text('Create your family').evaluate().isNotEmpty) {
    await _createFamily(tester, phase: phase);
  }
  expect(
    _onParentShell(),
    isTrue,
    reason: '$phase: expected the parent shell. Visible: ${_visibleTexts()}',
  );
  await _waitDashboard(tester, phase: phase);
}

Future<void> _signInParent(WidgetTester tester, {required String phase}) async {
  await _openSignIn(tester, 'Parent Mode');
  await _submitLogin(tester, _parentEmail, _parentPassword);
  await _waitForParentShell(tester, phase: phase);
}

Future<String> _readFamilyName(
  WidgetTester tester, {
  required String phase,
}) async {
  var name = '';
  final ok = await _pumpUntil(tester, () {
    final title = _appBarTitle(tester);
    if (title.isNotEmpty && title != 'No family yet') {
      name = title;
      return true;
    }
    return false;
  }, timeout: const Duration(seconds: 30));
  expect(
    ok,
    isTrue,
    reason:
        '$phase: could not read the active family name. Visible: ${_visibleTexts()}',
  );
  return name;
}

Finder? _activeDeviceOpener() {
  for (final label in ['Online', 'Offline', 'Pending enrollment']) {
    final status = find.text(label);
    final count = status.evaluate().length;
    for (var i = 0; i < count; i++) {
      final card = find
          .ancestor(of: status.at(i), matching: find.byType(SectionCard))
          .first;
      final open = find.descendant(
        of: card,
        matching: find.text('Open device'),
      );
      if (open.evaluate().isNotEmpty) return open.first;
    }
  }
  return null;
}

Future<Finder?> _refreshAndFindActiveDevice(WidgetTester tester) async {
  await _openTab(tester, 'Devices');
  await _pumpUntil(
    tester,
    () =>
        _appBarHas('Devices') &&
        find.text('Loading devices…').evaluate().isEmpty,
    timeout: const Duration(seconds: 30),
  );
  final refresh = find.byTooltip('Refresh devices');
  if (refresh.evaluate().isNotEmpty) {
    await tester.tap(refresh);
    await tester.pump(const Duration(seconds: 1));
    await _pumpUntil(
      tester,
      () => find.text('Loading devices…').evaluate().isEmpty,
      timeout: const Duration(seconds: 30),
    );
  }
  for (var i = 0; i < 12; i++) {
    final opener = _activeDeviceOpener();
    if (opener != null) return opener;
    final scrollable = _scrollable();
    if (scrollable == null) return null;
    await tester.drag(scrollable, const Offset(0, -400));
    await tester.pump(const Duration(milliseconds: 350));
  }
  return _activeDeviceOpener();
}

Future<void> _signInChild(WidgetTester tester, {required String phase}) async {
  await _openSignIn(tester, 'Child Mode');
  await _submitLogin(tester, _childEmail, _childPassword);
  final arrived = await _pumpUntil(
    tester,
    () =>
        _onChildShell() || find.text('Could not sign in').evaluate().isNotEmpty,
    timeout: const Duration(seconds: 90),
  );
  expect(
    arrived,
    isTrue,
    reason:
        '$phase: child sign-in produced no destination. Visible: ${_visibleTexts()}',
  );
  expect(
    _onChildShell(),
    isTrue,
    reason: '$phase: child sign-in failed. Visible: ${_visibleTexts()}',
  );
  await _pumpUntil(
    tester,
    () => find.text('Checking this phone…').evaluate().isEmpty,
    timeout: const Duration(seconds: 60),
  );
}

bool _childLinkedToFamily(WidgetTester tester, String familyName) {
  final belongs = find.textContaining('Your account belongs to ');
  if (belongs.evaluate().isNotEmpty) {
    final data = (tester.widget<Text>(belongs.first)).data ?? '';
    return data.trim().startsWith('Your account belongs to $familyName,');
  }
  final title = _appBarTitle(tester);
  return title.trim().toLowerCase() == familyName.trim().toLowerCase();
}

String _childFamilyDescription(WidgetTester tester) {
  final belongs = find.textContaining('Your account belongs to ');
  if (belongs.evaluate().isNotEmpty) {
    return (tester.widget<Text>(belongs.first)).data ?? 'unknown family';
  }
  final title = _appBarTitle(tester);
  return title.isEmpty ? 'unknown family' : title;
}

Future<void> _ensureChildUnlinked(
  WidgetTester tester,
  String familyName,
) async {
  final loaded = await _pumpUntil(
    tester,
    () =>
        find.text('Set up linking').evaluate().isNotEmpty ||
        find.text('Finish phone setup').evaluate().isNotEmpty ||
        _appBarTitle(tester) == familyName,
    timeout: const Duration(seconds: 60),
  );
  expect(
    loaded,
    isTrue,
    reason: 'Child home did not load. Visible: ${_visibleTexts()}',
  );

  final finish = find.text('Finish phone setup');
  final setup = find.text('Set up linking');
  final linked =
      finish.evaluate().isNotEmpty ||
      (setup.evaluate().isEmpty && _appBarTitle(tester) != 'My phone');
  if (!linked) {
    _mark('CHILD UNLINKED');
    return;
  }

  expect(
    _childLinkedToFamily(tester, familyName),
    isTrue,
    reason:
        'The QA child belongs to another family: ${_childFamilyDescription(tester)}. '
        'The parent family is "$familyName". Use a matched QA pair or unlink the '
        'child manually; this test will not destroy a different family.',
  );

  await _openTab(tester, 'Settings');
  await _tap(
    tester,
    _button('Unlink this phone from the family'),
    what: 'child Unlink',
  );
  await _confirmDialog(tester, 'Unlink this phone?', 'Unlink');
  final unlinked = await _pumpUntil(
    tester,
    () =>
        find.textContaining('no longer linked').evaluate().isNotEmpty ||
        _button('Unlink this phone from the family').evaluate().isEmpty,
    timeout: const Duration(seconds: 60),
  );
  expect(
    unlinked,
    isTrue,
    reason: 'The child unlink did not complete. Visible: ${_visibleTexts()}',
  );
  await _openTab(tester, 'Home');
  final home = await _pumpUntil(
    tester,
    () => find.text('Set up linking').evaluate().isNotEmpty,
    timeout: const Duration(seconds: 30),
  );
  expect(
    home,
    isTrue,
    reason:
        'Child home still shows a linked family. Visible: ${_visibleTexts()}',
  );
  _mark('CHILD UNLINKED');
}

Future<void> _openChildSetup(WidgetTester tester) async {
  Finder? target;
  for (final label in ['Set up linking', 'Finish phone setup']) {
    final candidate = _button(label);
    if (candidate.evaluate().isNotEmpty) {
      target = candidate;
      break;
    }
  }
  expect(
    target,
    isNotNull,
    reason: 'Child home has no setup action. Visible: ${_visibleTexts()}',
  );
  await _tap(tester, target!, what: 'child setup');
  final opened = await _pumpUntil(
    tester,
    () =>
        find.text('Link to your family').evaluate().isNotEmpty ||
        find.text('Register this phone').evaluate().isNotEmpty ||
        find.text('This phone is set up').evaluate().isNotEmpty,
    timeout: const Duration(seconds: 60),
  );
  expect(
    opened,
    isTrue,
    reason: 'Child enrollment page did not open. Visible: ${_visibleTexts()}',
  );
}

Finder? _approveForFamily(String familyName) {
  final labels = find.text(familyName);
  final count = labels.evaluate().length;
  for (var i = 0; i < count; i++) {
    final card = find
        .ancestor(of: labels.at(i), matching: find.byType(SectionCard))
        .first;
    final approve = find.descendant(of: card, matching: _button('Approve'));
    if (approve.evaluate().isNotEmpty) return approve.first;
  }
  final all = _button('Approve');
  if (all.evaluate().length == 1) return all.first;
  return null;
}

final RegExp _childIdPattern =
    RegExp(r'^PC-?[23456789ABCDEFGHJKMNPQRSTVWXYZ]{8}$');

Future<String?> _waitForChildId(WidgetTester tester) async {
  String? childId;
  final ok = await _pumpUntil(tester, () {
    for (final element in find.byType(SelectableText).evaluate()) {
      final data = (element.widget as SelectableText).data?.trim() ?? '';
      if (_childIdPattern.hasMatch(data)) {
        childId = data;
        return true;
      }
    }
    return false;
  }, timeout: const Duration(seconds: 45));
  return ok ? childId : null;
}

Future<void> _registerChildDevice(WidgetTester tester) async {
  final deviceStep = await _pumpUntil(
    tester,
    () => find.text('Register this phone').evaluate().isNotEmpty,
    timeout: const Duration(seconds: 60),
  );
  expect(
    deviceStep,
    isTrue,
    reason:
        'Child device registration step did not appear. Visible: ${_visibleTexts()}',
  );
  final fields = find.byType(TextField);
  expect(
    fields,
    findsWidgets,
    reason: 'The phone name field is missing. Visible: ${_visibleTexts()}',
  );
  await tester.enterText(fields.first, _phoneName);
  await tester.pump(const Duration(milliseconds: 250));
  final register = _button('Register this phone');
  await _reveal(tester, register);
  expect(
    tester.widget<AppButton>(register.first).onPressed,
    isNotNull,
    reason: 'The register button is disabled. Visible: ${_visibleTexts()}',
  );
  await tester.tap(register.first);
  final done = await _pumpUntil(
    tester,
    () =>
        find.text('This phone is set up').evaluate().isNotEmpty ||
        find.text('Action failed').evaluate().isNotEmpty,
    timeout: const Duration(seconds: 90),
  );
  _mark('CHILD REGISTER RESULT');
  expect(
    done,
    isTrue,
    reason: 'Registration produced no result. Visible: ${_visibleTexts()}',
  );
  expect(
    find.text('This phone is set up').evaluate().isNotEmpty,
    isTrue,
    reason: 'Device registration failed: ${_visibleTexts()}',
  );
}

Future<void> _openMyPhone(WidgetTester tester) async {
  await _tap(tester, _button('Open My phone'), what: 'Open My phone');
  final shell = await _pumpUntil(
    tester,
    _onChildShell,
    timeout: const Duration(seconds: 30),
  );
  expect(
    shell,
    isTrue,
    reason:
        'Open My phone did not reach the child shell. Visible: ${_visibleTexts()}',
  );
  await _pumpUntil(
    tester,
    () => find.text('Checking this phone…').evaluate().isEmpty,
    timeout: const Duration(seconds: 60),
  );
}

Future<void> _returnToChildShell(WidgetTester tester) async {
  final backButton = find.byType(BackButton);
  if (backButton.evaluate().isNotEmpty) {
    await tester.tap(backButton.first);
  } else {
    await _tap(tester, _button('Back'), what: 'enrollment Back');
  }
  final shell = await _pumpUntil(
    tester,
    _onChildShell,
    timeout: const Duration(seconds: 30),
  );
  expect(
    shell,
    isTrue,
    reason:
        'Could not return to the child shell from enrollment. Visible: ${_visibleTexts()}',
  );
}

Future<void> _returnToParentShell(WidgetTester tester) async {
  for (var attempt = 0; attempt < 4 && !_onParentShell(); attempt++) {
    final backButton = find.byType(BackButton);
    expect(
      backButton,
      findsWidgets,
      reason:
          'No back button while leaving the redeem flow. Visible: ${_visibleTexts()}',
    );
    await tester.tap(backButton.first);
    await tester.pump(const Duration(milliseconds: 700));
  }
  final shell = await _pumpUntil(
    tester,
    _onParentShell,
    timeout: const Duration(seconds: 30),
  );
  expect(
    shell,
    isTrue,
    reason:
        'Could not return to the parent shell from redeeming. Visible: ${_visibleTexts()}',
  );
}

/// Reads the child's permanent Child ID, or approves an already pending request
/// for [familyName]. Returns the Child ID when it was read from the child UI,
/// or null when an existing request was approved and the device registered
/// immediately.
Future<String?> _createCodeOrApproveExisting(
  WidgetTester tester,
  String familyName,
) async {
  if (find.text('Register this phone').evaluate().isNotEmpty) {
    _mark('CHILD DEVICE STEP');
    await _registerChildDevice(tester);
    return null;
  }

  final pendingTitle = find.text('Waiting for your approval');
  if (pendingTitle.evaluate().isNotEmpty) {
    await _reveal(tester, pendingTitle, attempts: 12);
  }
  final existing = _approveForFamily(familyName);
  if (existing != null) {
    _mark('CHILD PENDING REQUEST');
    await _tap(tester, existing, what: 'Approve existing pending request');
    await _confirmDialog(tester, 'Join', 'Approve');
    final deviceStep = await _pumpUntil(
      tester,
      () => find.text('Register this phone').evaluate().isNotEmpty,
      timeout: const Duration(seconds: 60),
    );
    expect(
      deviceStep,
      isTrue,
      reason:
          'Approving the pending request did not reach registration. Visible: ${_visibleTexts()}',
    );
    await _registerChildDevice(tester);
    return null;
  }

  // The Child ID is assigned by the server and shown automatically; there is
  // no "create" button any more.
  final childIdCard = find.text('Your Child ID');
  final cardVisible = await _pumpUntil(
    tester,
    () => childIdCard.evaluate().isNotEmpty,
    timeout: const Duration(seconds: 45),
  );
  expect(
    cardVisible,
    isTrue,
    reason:
        'The child setup screen has no "Your Child ID" card. Visible: ${_visibleTexts()}',
  );
  if (childIdCard.evaluate().isNotEmpty) {
    await _reveal(tester, childIdCard, attempts: 12);
  }
  final childId = await _waitForChildId(tester);
  expect(
    childId,
    isNotNull,
    reason:
        'The child UI did not show a permanent Child ID. Visible: ${_visibleTexts()}',
  );
  expect(
    find.text('Create linking code'),
    findsNothing,
    reason:
        'The old "Create linking code" control must be gone. Visible: ${_visibleTexts()}',
  );
  _mark('CHILD ID');
  // The Child ID is an identifier, not a secret, but keep most of it out of
  // CI logs anyway.
  // ignore: avoid_print
  print(
    'CHILD ID VISIBLE: ${childId!.substring(0, 3)}****** '
    '(permanent identifier; remainder withheld)',
  );
  return childId;
}

Future<void> _openRedeem(WidgetTester tester) async {
  await _openTab(tester, 'Dashboard');
  await _waitDashboard(tester, phase: 'redeem');
  final quick = find.text('Pair a device');
  if (quick.evaluate().isNotEmpty) {
    await _tap(tester, quick, what: 'Pair a device quick link');
  } else {
    final emptyAction = find.widgetWithText(
      FilledButton,
      'Open family & pairing',
    );
    if (emptyAction.evaluate().isNotEmpty) {
      await _tap(tester, emptyAction, what: 'Open family & pairing');
    } else {
      await _tap(tester, find.text('Family'), what: 'Family quick link');
    }
    final familyPage = await _pumpUntil(
      tester,
      () => find.text('Family actions').evaluate().isNotEmpty,
      timeout: const Duration(seconds: 40),
    );
    expect(
      familyPage,
      isTrue,
      reason: 'Family page did not open. Visible: ${_visibleTexts()}',
    );
    await _tap(tester, _button('Link a child'), what: 'Link a child');
  }
  final redeem = await _pumpUntil(
    tester,
    () =>
        find.text('Or enter the Child ID or linking code').evaluate().isNotEmpty &&
        find.text('Child ID or linking code').evaluate().isNotEmpty,
    timeout: const Duration(seconds: 40),
  );
  expect(
    redeem,
    isTrue,
    reason: 'The parent redeem page did not open. Visible: ${_visibleTexts()}',
  );
}

bool _redeemErrorVisible() {
  const titles = [
    'Child ID or code not recognised',
    'Linking code expired',
    'Too many attempts',
    'Child already linked',
    'Pairing is not configured',
    'Connection problem',
    'Check the Child ID or code',
    'Pairing request failed',
  ];
  return titles.any((title) => find.text(title).evaluate().isNotEmpty);
}

Future<void> _sendPairingRequest(WidgetTester tester, String childId) async {
  final fields = find.byType(TextField);
  expect(
    fields,
    findsOneWidget,
    reason:
        'The Child ID or linking code field is not unique. Visible: ${_visibleTexts()}',
  );
  await tester.enterText(fields.first, childId);
  await tester.pump(const Duration(milliseconds: 250));
  final send = _button('Send pairing request');
  await _reveal(tester, send, attempts: 24);
  await tester.tap(send.first);
  final done = await _pumpUntil(
    tester,
    () =>
        find.text('Waiting for child approval').evaluate().isNotEmpty ||
        _redeemErrorVisible(),
    timeout: const Duration(seconds: 90),
  );
  _mark('PAIRING REQUEST RESULT');
  expect(
    done,
    isTrue,
    reason:
        'Sending the pairing request produced no server result. Visible: ${_visibleTexts()}',
  );
  expect(
    find.text('Waiting for child approval').evaluate().isNotEmpty,
    isTrue,
    reason: 'The parent pairing request failed: ${_visibleTexts()}',
  );
}

Future<void> _approvePending(
  WidgetTester tester,
  String familyName, {
  required String phase,
}) async {
  final page = await _pumpUntil(
    tester,
    () =>
        find.text('Waiting for your approval').evaluate().isNotEmpty ||
        find.text('Register this phone').evaluate().isNotEmpty,
    timeout: const Duration(seconds: 60),
  );
  expect(
    page,
    isTrue,
    reason:
        '$phase: pending approval card did not appear. Visible: ${_visibleTexts()}',
  );
  if (find.text('Register this phone').evaluate().isNotEmpty) return;

  await _reveal(tester, find.text('Waiting for your approval'));
  final approve = _approveForFamily(familyName);
  expect(
    approve,
    isNotNull,
    reason:
        '$phase: no pending approval for "$familyName". Visible: ${_visibleTexts()}',
  );
  await _tap(tester, approve!, what: '$phase: Approve');
  await _confirmDialog(tester, 'Join', 'Approve');
  final deviceStep = await _pumpUntil(
    tester,
    () => find.text('Register this phone').evaluate().isNotEmpty,
    timeout: const Duration(seconds: 60),
  );
  expect(
    deviceStep,
    isTrue,
    reason:
        '$phase: approval did not reach registration. Visible: ${_visibleTexts()}',
  );
}

Future<void> _runChildLinkingFlow(
  WidgetTester tester,
  String familyName,
) async {
  expect(
    _childEmail,
    isNotEmpty,
    reason: 'QA_CHILD_EMAIL is required when no active device exists',
  );
  expect(
    _childPassword,
    isNotEmpty,
    reason: 'QA_CHILD_PASSWORD is required when no active device exists',
  );

  await _signOutParent(tester, phase: 'pre-link');

  await _signInChild(tester, phase: 'child preparation');
  await _ensureChildUnlinked(tester, familyName);
  await _openChildSetup(tester);
  final childId = await _createCodeOrApproveExisting(tester, familyName);

  if (childId != null) {
    await _returnToChildShell(tester);
    await _signOutChild(tester, phase: 'after reading the Child ID');

    await _signInParent(tester, phase: 'parent pairing request');
    await _openRedeem(tester);
    await _sendPairingRequest(tester, childId);
    await _returnToParentShell(tester);
    await _signOutParent(tester, phase: 'after the pairing request');

    await _signInChild(tester, phase: 'child approval');
    await _openChildSetup(tester);
    await _approvePending(tester, familyName, phase: 'child approval');
    await _registerChildDevice(tester);
  }

  await _openMyPhone(tester);
  await _signOutChild(tester, phase: 'after registration');

  await _signInParent(tester, phase: 'parent verification');
}

Future<void> _runParentDeviceChecks(
  WidgetTester tester,
  Finder opener,
  String familyName,
) async {
  _mark('DEVICES LINKED');
  await _tap(tester, opener, what: 'Open device');

  final detail = await _pumpUntil(
    tester,
    () => find.text('Device identity').evaluate().isNotEmpty,
    timeout: const Duration(seconds: 60),
  );
  _mark('DEVICE DETAIL');
  expect(
    detail,
    isTrue,
    reason: 'Device detail did not load. Visible: ${_visibleTexts()}',
  );
  expect(
    find.text('Policy').evaluate().isNotEmpty,
    isTrue,
    reason: 'The device detail has no Policy card. Visible: ${_visibleTexts()}',
  );

  final detailLimitation = find.text('App suspension is not supported here');
  if (detailLimitation.evaluate().isNotEmpty) {
    final visible = await _reveal(tester, detailLimitation, attempts: 16);
    expect(visible, isTrue);
    expect(
      find
          .textContaining('not a fully managed Device Owner device')
          .evaluate()
          .isNotEmpty,
      isTrue,
      reason:
          'The Device Owner limitation text is missing on device detail. '
          'Visible: ${_visibleTexts()}',
    );
  } else {
    // ignore: avoid_print
    print(
      'NOTE: device detail did not show the suspension limitation; the '
      'device reports Device Owner enforcement.',
    );
  }

  await _tap(tester, find.text('App restrictions'), what: 'App restrictions');
  final restrictions = await _pumpUntil(
    tester,
    () => _appBarHas('App restrictions'),
    timeout: const Duration(seconds: 30),
  );
  _mark('APP RESTRICTIONS');
  expect(
    restrictions,
    isTrue,
    reason:
        'The App restrictions screen did not open. Visible: ${_visibleTexts()}',
  );

  final limitation = find.text('App suspension unsupported on this device');
  await _pumpUntil(
    tester,
    () => find.textContaining('Loading app restrictions').evaluate().isEmpty,
    timeout: const Duration(seconds: 60),
  );
  final limitationVisible = await _reveal(tester, limitation, attempts: 24);
  expect(
    limitationVisible,
    isTrue,
    reason:
        'The restrictions screen must state the Device Owner limitation. '
        'Visible: ${_visibleTexts()}',
  );
  expect(
    find
        .textContaining(
          'only allows setPackagesSuspended when Parent Control is the Device Owner',
        )
        .evaluate()
        .isNotEmpty,
    isTrue,
    reason:
        'The setPackagesSuspended/Device Owner explanation is missing. '
        'Visible: ${_visibleTexts()}',
  );

  final flagBanner = find.text('A database flag does not block an app');
  expect(
    await _reveal(tester, flagBanner, attempts: 20),
    isTrue,
    reason:
        'The "database flag does not block" banner is missing. '
        'Visible: ${_visibleTexts()}',
  );
  expect(
    find
        .textContaining('Saving only stores the policy and queues a command')
        .evaluate()
        .isNotEmpty,
    isTrue,
  );

  expect(
    await _reveal(tester, find.text('Policy state'), attempts: 20),
    isTrue,
    reason: 'The Policy state card is missing. Visible: ${_visibleTexts()}',
  );

  // Clear the block-all mode and every blocked app so the saved policy is
  // benign. This is UI-only; no repository or server shortcut is used.
  final blockAllTitle = find.text('Block every app except the allowed list');
  expect(
    await _reveal(tester, blockAllTitle, attempts: 24),
    isTrue,
    reason: 'The block-all control did not render. Visible: ${_visibleTexts()}',
  );
  final blockAllTile = find.widgetWithText(
    SwitchListTile,
    'Block every app except the allowed list',
  );
  expect(blockAllTile, findsOneWidget);
  if (tester.widget<SwitchListTile>(blockAllTile.first).value) {
    await tester.tap(blockAllTile.first);
    await tester.pump(const Duration(milliseconds: 400));
  }
  expect(
    tester.widget<SwitchListTile>(blockAllTile.first).value,
    isFalse,
    reason:
        'Could not turn off "block all except allowed". Visible: ${_visibleTexts()}',
  );

  var removed = 0;
  for (var i = 0; i < 40; i++) {
    final remove = find.byTooltip('Remove from blocked apps');
    if (remove.evaluate().isEmpty) {
      final found = await _reveal(tester, remove, attempts: 8);
      if (!found) break;
    }
    await tester.tap(remove.first);
    removed += 1;
    await tester.pump(const Duration(milliseconds: 350));
  }
  // ignore: avoid_print
  print(
    'BENIGN POLICY: removed $removed blocked app selection(s) through the UI',
  );

  final save = _button('Save restrictions');
  expect(
    await _reveal(tester, save, attempts: 40),
    isTrue,
    reason:
        'The Save restrictions button did not render. Visible: ${_visibleTexts()}',
  );
  final saveReady = await _pumpUntil(tester, () {
    final current = _button('Save restrictions');
    return current.evaluate().isNotEmpty &&
        tester.widget<AppButton>(current.first).onPressed != null;
  }, timeout: const Duration(seconds: 30));
  expect(
    saveReady,
    isTrue,
    reason:
        'Save restrictions stayed disabled (policy not loaded or device '
        'revoked). Visible: ${_visibleTexts()}',
  );
  await tester.tap(_button('Save restrictions').first);

  final saveFinished = await _pumpUntil(tester, () {
    final current = _button('Save restrictions');
    return current.evaluate().isNotEmpty &&
        !tester.widget<AppButton>(current.first).isLoading;
  }, timeout: const Duration(seconds: 90));
  expect(
    saveFinished,
    isTrue,
    reason:
        'The Save restrictions button never stopped loading. '
        'Visible: ${_visibleTexts()}',
  );

  // The policy card sits above the form. Drag the page back to the top; the
  // reveal helper only scrolls forward, so it cannot find an earlier card.
  final page = _scrollable();
  if (page != null) {
    for (var i = 0; i < 10; i++) {
      await tester.drag(page, const Offset(0, 600));
      await tester.pump(const Duration(milliseconds: 250));
    }
  }
  await _reveal(tester, find.text('Policy state'), attempts: 20);
  final saveResult = await _pumpUntil(
    tester,
    () =>
        find
            .textContaining('Pending device acknowledgement')
            .evaluate()
            .isNotEmpty ||
        find
            .textContaining('Unsupported on this device')
            .evaluate()
            .isNotEmpty ||
        find.textContaining('Enforcement failed').evaluate().isNotEmpty ||
        find.textContaining('Could not save the policy').evaluate().isNotEmpty,
    timeout: const Duration(seconds: 30),
  );
  _mark('POLICY SAVE RESULT');
  expect(
    saveResult,
    isTrue,
    reason:
        'The policy save produced no visible state. Visible: ${_visibleTexts()}',
  );
  expect(
    find.textContaining('Could not save the policy').evaluate().isEmpty,
    isTrue,
    reason: 'The policy save failed: ${_visibleTexts()}',
  );
  expect(
    find.textContaining('Pending device acknowledgement').evaluate().isNotEmpty,
    isTrue,
    reason:
        'The saved policy must be shown as pending acknowledgement, not '
        'enforced. Visible: ${_visibleTexts()}',
  );
  expect(
    find.textContaining('enforced on the device').evaluate().isEmpty,
    isTrue,
    reason:
        'The app claimed immediate enforcement. Visible: ${_visibleTexts()}',
  );

  if (!_revokeAtEnd) {
    // ignore: avoid_print
    print(
      'REVOKE SKIPPED: pass --dart-define=QA_REVOKE=true to revoke through the UI.',
    );
    return;
  }

  final backButton = find.byType(BackButton);
  expect(backButton, findsWidgets, reason: 'No back button on restrictions.');
  await tester.tap(backButton.first);
  // Returning restores the detail page's old scroll offset (the test had
  // scrolled down to the App restrictions entry), so bring the identity card
  // back into view instead of assuming it is at the top.
  final detailPage = _scrollable();
  if (detailPage != null) {
    for (var i = 0; i < 10; i++) {
      await tester.drag(detailPage, const Offset(0, 600));
      await tester.pump(const Duration(milliseconds: 200));
    }
  }
  final backOnDetail = await _pumpUntil(
    tester,
    () => find.text('Device identity').evaluate().isNotEmpty,
    timeout: const Duration(seconds: 20),
  );
  expect(
    backOnDetail,
    isTrue,
    reason: 'Could not return to device detail. Visible: ${_visibleTexts()}',
  );

  final revoke = _button('Revoke device');
  expect(
    await _reveal(tester, revoke, attempts: 40),
    isTrue,
    reason:
        'The Revoke device button did not render. Visible: ${_visibleTexts()}',
  );
  expect(
    tester.widget<AppButton>(revoke.first).onPressed,
    isNotNull,
    reason: 'Revoke device is disabled. Visible: ${_visibleTexts()}',
  );
  await tester.tap(revoke.first);
  await _confirmDialog(tester, 'Revoke this device?', 'Revoke device');

  final backOnDevices = await _pumpUntil(
    tester,
    () => _appBarHas('Devices'),
    timeout: const Duration(seconds: 90),
  );
  expect(
    backOnDevices,
    isTrue,
    reason:
        'Revoking did not return to the device list. Visible: ${_visibleTexts()}',
  );
  await tester.pump(const Duration(seconds: 1));
  final refresh = find.byTooltip('Refresh devices');
  if (refresh.evaluate().isNotEmpty) {
    await tester.tap(refresh);
    await tester.pump(const Duration(seconds: 1));
    await _pumpUntil(
      tester,
      () => find.text('Loading devices…').evaluate().isEmpty,
      timeout: const Duration(seconds: 30),
    );
  }
  final revoked = find.text('Revoked');
  final revokedVisible = await _reveal(tester, revoked, attempts: 30);
  _mark('DEVICE REVOKED');
  expect(
    revokedVisible,
    isTrue,
    reason:
        'The revoked state is not visible in the parent device list. Visible: ${_visibleTexts()}',
  );
}

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets(
    'parent UI journey: sign-in, family, pairing consent, restrictions, policy',
    (tester) async {
      expect(
        _parentEmail,
        isNotEmpty,
        reason: 'QA_PARENT_EMAIL must be provided with --dart-define',
      );
      expect(
        _parentPassword,
        isNotEmpty,
        reason: 'QA_PARENT_PASSWORD must be provided with --dart-define',
      );

      // 1. Cold launch and normalisation of any pre-existing session.
      app.main();
      final ready = await _pumpUntil(
        tester,
        () =>
            _onRoleSelection() ||
            _onParentShell() ||
            _onChildShell() ||
            find.text('Create your family').evaluate().isNotEmpty ||
            find.text('Verify email').evaluate().isNotEmpty ||
            find
                .textContaining('Provide the publishable configuration')
                .evaluate()
                .isNotEmpty,
        timeout: const Duration(seconds: 120),
      );
      _mark('START');
      expect(
        ready,
        isTrue,
        reason:
            'The app did not leave the splash screen. Visible: ${_visibleTexts()}',
      );
      if (find
          .textContaining('Provide the publishable configuration')
          .evaluate()
          .isNotEmpty) {
        fail(
          'The configuration page is showing. Pass SUPABASE_URL and '
          'SUPABASE_ANON_KEY with --dart-define.',
        );
      }
      if (_onParentShell()) {
        await _signOutParent(tester, phase: 'startup');
      } else if (_onChildShell()) {
        await _signOutChild(tester, phase: 'startup');
      } else if (find.text('Create your family').evaluate().isNotEmpty) {
        await _createFamily(tester, phase: 'startup');
        await _signOutParent(tester, phase: 'startup');
      } else if (find.text('Verify email').evaluate().isNotEmpty) {
        fail(
          'The signed-in QA parent has an unverified email; verify it first.',
        );
      }
      expect(
        _onRoleSelection(),
        isTrue,
        reason: 'Could not reach role selection. Visible: ${_visibleTexts()}',
      );

      // 2. Invalid sign-in: an error is shown and no shell is entered.
      await _openSignIn(tester, 'Parent Mode');
      await _submitLogin(tester, _parentEmail, _invalidPassword);
      final rejected = await _pumpUntil(
        tester,
        () => find.text('Could not sign in').evaluate().isNotEmpty,
        timeout: const Duration(seconds: 60),
      );
      _mark('INVALID SIGN IN');
      expect(
        rejected,
        isTrue,
        reason:
            'Invalid credentials showed no error. Visible: ${_visibleTexts()}',
      );
      expect(
        find.text('Welcome back').evaluate().isNotEmpty,
        isTrue,
        reason:
            'Invalid credentials left the login page. Visible: ${_visibleTexts()}',
      );
      expect(
        _onParentShell() || _onChildShell(),
        isFalse,
        reason: 'Invalid credentials entered an authenticated shell.',
      );

      // 3. Parent sign-in and family.
      await _submitLogin(tester, _parentEmail, _parentPassword);
      await _waitForParentShell(tester, phase: 'parent sign-in 1');
      final familyName = await _readFamilyName(
        tester,
        phase: 'parent sign-in 1',
      );
      _mark('PARENT FAMILY');
      // ignore: avoid_print
      print('PARENT FAMILY NAME: $familyName');

      // 4. Pairing only when the parent has no active device. Revoked devices
      // stay in the list, so "Open device" alone is not enough.
      final existingOpener = await _refreshAndFindActiveDevice(tester);
      _mark('DEVICES BEFORE LINK');
      if (existingOpener != null) {
        // ignore: avoid_print
        print('LINK SKIPPED: the parent already has an active device.');
        await _runParentDeviceChecks(tester, existingOpener, familyName);
      } else {
        await _runChildLinkingFlow(tester, familyName);
        final linkedOpener = await _refreshAndFindActiveDevice(tester);
        expect(
          linkedOpener,
          isNotNull,
          reason:
              'The parent device list has no active device after linking. '
              'Visible: ${_visibleTexts()}',
        );
        await _runParentDeviceChecks(tester, linkedOpener!, familyName);
      }
    },
    timeout: const Timeout(Duration(minutes: 30)),
  );
}

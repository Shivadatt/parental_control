// Device smoke test: a linked child signs in and reaches phone enrollment.
// Credentials come from --dart-define and are never stored in this file.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:parent_control/core/widgets/app_button.dart';
import 'package:parent_control/main.dart' as app;

const _email = String.fromEnvironment('QA_CHILD_EMAIL');
const _password = String.fromEnvironment('QA_CHILD_PASSWORD');

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
  return false;
}

Future<bool> _scrollTo(WidgetTester tester, Finder target) async {
  for (var attempt = 0; attempt < 12; attempt++) {
    if (target.evaluate().isNotEmpty) return true;
    final lists = find.byType(ListView);
    if (lists.evaluate().isEmpty) return false;
    await tester.drag(lists.first, const Offset(0, -420));
    await tester.pump(const Duration(milliseconds: 350));
  }
  return target.evaluate().isNotEmpty;
}

String _visibleTexts() => find
    .byType(Text)
    .evaluate()
    .map((element) => (element.widget as Text).data ?? '')
    .where((value) => value.trim().isNotEmpty)
    .join(' | ');

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('linked child signs in and reaches phone enrollment', (tester) async {
    expect(_email, isNotEmpty, reason: 'QA_CHILD_EMAIL must be provided');
    expect(_password, isNotEmpty, reason: 'QA_CHILD_PASSWORD must be provided');

    app.main();
    final ready = await _pumpUntil(
      tester,
      () =>
          find.text('Child Mode').evaluate().isNotEmpty ||
          find.text('This phone').evaluate().isNotEmpty,
    );
    expect(ready, isTrue, reason: 'app did not become ready');
    // ignore: avoid_print
    print('VISIBLE START: ${_visibleTexts()}');

    if (find.text('Child Mode').evaluate().isNotEmpty) {
      await tester.tap(find.text('Sign in').last);
      await tester.pumpAndSettle(const Duration(milliseconds: 500));

      final fields = find.byType(TextField);
      expect(fields, findsNWidgets(2));
      await tester.enterText(fields.at(0), _email);
      await tester.enterText(fields.at(1), _password);
      await tester.pump();

      final submit = find.byWidgetPredicate(
        (widget) => widget is AppButton && widget.label == 'Sign in',
      );
      expect(submit, findsOneWidget);
      await tester.tap(submit);
      final reached = await _pumpUntil(
        tester,
        () =>
            find.textContaining('Set up this phone').evaluate().isNotEmpty ||
            find.textContaining('Register this phone').evaluate().isNotEmpty ||
            find.textContaining('Link to your family').evaluate().isNotEmpty ||
            find.textContaining('Family linked').evaluate().isNotEmpty ||
            find.textContaining('Finish phone setup').evaluate().isNotEmpty ||
            find.textContaining('Background protection').evaluate().isNotEmpty ||
            find.textContaining('Device setup').evaluate().isNotEmpty ||
            find.textContaining('Waiting for your approval').evaluate().isNotEmpty ||
            find.textContaining('Could not sign in').evaluate().isNotEmpty,
      );
      // ignore: avoid_print
      print('VISIBLE AFTER SUBMIT: ${_visibleTexts()}');
      expect(reached, isTrue, reason: 'child enrollment screen was not reached');
      expect(find.textContaining('Could not sign in').evaluate().isEmpty, isTrue,
          reason: 'server rejected the child sign-in');
    }

    final finish = find.text('Finish phone setup');
    if (finish.evaluate().isNotEmpty) {
      await tester.ensureVisible(finish);
      await tester.tap(finish);

      final enrollment = await _pumpUntil(
        tester,
        () => find.text('Register this phone').evaluate().isNotEmpty,
      );
      // ignore: avoid_print
      print('VISIBLE ENROLLMENT: ${_visibleTexts()}');
      expect(enrollment, isTrue, reason: 'enrollment page did not open');

      final nameFields = find.byType(TextField);
      expect(nameFields, findsWidgets);
      await tester.enterText(nameFields.first, 'QA Phone B');
      await tester.pump();

      final register = find.byWidgetPredicate(
        (widget) => widget is AppButton && widget.label == 'Register this phone',
      );
      expect(register, findsOneWidget);
      await tester.ensureVisible(register);
      await tester.tap(register);

      final registered = await _pumpUntil(
        tester,
        () =>
            find.text('This phone is set up').evaluate().isNotEmpty ||
            find.textContaining('Action failed').evaluate().isNotEmpty,
        timeout: const Duration(seconds: 60),
      );
      // ignore: avoid_print
      print('VISIBLE REGISTER: ${_visibleTexts()}');
      expect(registered, isTrue, reason: 'registration produced no result');
      expect(find.text('This phone is set up').evaluate().isNotEmpty, isTrue,
          reason: 'device registration failed: ${_visibleTexts()}');

      final openPhone = find.byWidgetPredicate(
        (widget) => widget is AppButton && widget.label == 'Open My phone',
      );
      expect(openPhone, findsOneWidget);
      await tester.ensureVisible(openPhone);
      await tester.tap(openPhone);

      // The dialog is dismissed and the shell replaces the enrollment route;
      // wait for that transition before looking for the shell's list.
      final opened = await _pumpUntil(
        tester,
        () =>
            find.text('Rules').evaluate().isNotEmpty ||
            find.text('Requests').evaluate().isNotEmpty,
      );
      // ignore: avoid_print
      print('VISIBLE OPEN PHONE: ${_visibleTexts()}');
      expect(opened, isTrue, reason: 'Open My phone did not open the shell');
    }

    // The shell fetches membership, device and policy before it builds the
    // phone content; scrolling during that state finds no list.
    final loaded = await _pumpUntil(
      tester,
      () => find.text('Checking this phone…').evaluate().isEmpty,
      timeout: const Duration(seconds: 60),
    );
    // ignore: avoid_print
    print('VISIBLE PHONE LOADED: ${_visibleTexts()}');
    expect(loaded, isTrue, reason: 'phone shell stayed on its loading state');

    final myPhone = await _scrollTo(
      tester,
      find.text('Background protection'),
    );
    expect(myPhone, isTrue, reason: 'My phone did not open');

    final retry = find.byWidgetPredicate(
      (widget) =>
          widget is AppButton && widget.label == 'Retry background protection',
    );
    final retryVisible = await _scrollTo(tester, retry);
    expect(retryVisible, isTrue);
    await tester.ensureVisible(retry);
    await tester.tap(retry);

    final started = await _pumpUntil(
      tester,
      () =>
          find.text('Running').evaluate().isNotEmpty ||
          find.textContaining('Action failed').evaluate().isNotEmpty,
      timeout: const Duration(seconds: 60),
    );
    // ignore: avoid_print
    print('VISIBLE GUARDIAN: ${_visibleTexts()}');
    expect(started, isTrue, reason: 'guardian start produced no result');
    expect(
      find.text('Running').evaluate().isNotEmpty,
      isTrue,
      reason: 'guardian service did not start: ${_visibleTexts()}',
    );

    // Give the foreground service time to poll once while the app stays alive.
    await tester.pump(const Duration(seconds: 1));
    await Future<void>.delayed(const Duration(seconds: 35));
    await tester.pump(const Duration(seconds: 1));
    // ignore: avoid_print
    print('VISIBLE GUARDIAN AFTER POLL: ${_visibleTexts()}');
  });
}

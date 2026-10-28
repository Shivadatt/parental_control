// Device test: the child's visible camera/microphone self-test opens both
// devices, switches camera, mutes the microphone, and stops every track.
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
  Duration timeout = const Duration(seconds: 60),
}) async {
  final deadline = DateTime.now().add(timeout);
  while (DateTime.now().isBefore(deadline)) {
    await tester.pump(const Duration(milliseconds: 250));
    if (condition()) return true;
  }
  return false;
}

Future<bool> _scrollTo(WidgetTester tester, Finder target) async {
  for (var attempt = 0; attempt < 16; attempt++) {
    if (target.evaluate().isNotEmpty) return true;
    final lists = find.byType(ListView);
    if (lists.evaluate().isEmpty) return false;
    await tester.drag(lists.first, const Offset(0, -380));
    await tester.pump(const Duration(milliseconds: 350));
  }
  return target.evaluate().isNotEmpty;
}

/// Drags the owning scroll view until [target] is fully above the bottom
/// navigation bar, without flinging past it.
Future<bool> _ensureTappable(WidgetTester tester, Finder target) async {
  for (var attempt = 0; attempt < 18; attempt++) {
    if (target.evaluate().isNotEmpty) {
      final rect = tester.getRect(target);
      if (rect.top >= 0 && rect.bottom <= 720) return true;
      final scrollables =
          find.ancestor(of: target, matching: find.byType(Scrollable));
      if (scrollables.evaluate().isEmpty) return false;
      final delta = rect.top > 520 ? -120.0 : 120.0;
      await tester.timedDrag(
        scrollables.first,
        Offset(0, delta),
        const Duration(milliseconds: 350),
      );
      await tester.pump(const Duration(milliseconds: 350));
      continue;
    }
    final lists = find.byType(ListView);
    if (lists.evaluate().isEmpty) return false;
    await tester.timedDrag(
      lists.first,
      const Offset(0, -150),
      const Duration(milliseconds: 350),
    );
    await tester.pump(const Duration(milliseconds: 350));
  }
  return target.evaluate().isNotEmpty &&
      tester.getRect(target).bottom <= 720;
}

String _visibleTexts() => find
    .byType(Text)
    .evaluate()
    .map((element) => (element.widget as Text).data ?? '')
    .where((value) => value.trim().isNotEmpty)
    .join(' | ');

Finder _buttonFinder(String label) => find.byWidgetPredicate(
      (widget) => widget is AppButton && widget.label == label,
    );

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('child camera and microphone self-test opens and stops media',
      (tester) async {
    expect(_email, isNotEmpty, reason: 'QA_CHILD_EMAIL must be provided');
    expect(_password, isNotEmpty, reason: 'QA_CHILD_PASSWORD must be provided');

    app.main();
    final ready = await _pumpUntil(
      tester,
      () =>
          find.text('Child Mode').evaluate().isNotEmpty ||
          find.text('Settings').evaluate().isNotEmpty ||
          find.text('This phone').evaluate().isNotEmpty,
    );
    expect(ready, isTrue, reason: 'app did not become ready');

    if (find.text('Child Mode').evaluate().isNotEmpty) {
      await tester.tap(find.text('Sign in').last);
      await tester.pumpAndSettle(const Duration(milliseconds: 500));
      final fields = find.byType(TextField);
      expect(fields, findsNWidgets(2));
      await tester.enterText(fields.at(0), _email);
      await tester.enterText(fields.at(1), _password);
      await tester.pump();
      final submit = _buttonFinder('Sign in');
      expect(submit, findsOneWidget);
      await tester.tap(submit);
    }

    final signedIn = await _pumpUntil(
      tester,
      () =>
          find.text('Settings').evaluate().isNotEmpty ||
          find.textContaining('Could not sign in').evaluate().isNotEmpty,
    );
    // ignore: avoid_print
    print('VISIBLE AFTER SIGN IN: ${_visibleTexts()}');
    expect(signedIn, isTrue, reason: 'child shell was not reached');
    expect(
      find.textContaining('Could not sign in').evaluate().isEmpty,
      isTrue,
      reason: 'server rejected the child sign-in',
    );

    final settingsTab = find.descendant(
      of: find.byType(NavigationBar),
      matching: find.text('Settings'),
    );
    expect(settingsTab, findsOneWidget);
    await tester.tap(settingsTab);
    await tester.pump(const Duration(milliseconds: 500));

    final settingsReady = await _pumpUntil(
      tester,
      () => find.text('This phone settings').evaluate().isNotEmpty,
    );
    // ignore: avoid_print
    print('VISIBLE SETTINGS: ${_visibleTexts()}');
    expect(settingsReady, isTrue, reason: 'settings tab did not open');

    final testTitle = find.text('Camera and microphone test');
    final foundTest = await _scrollTo(tester, testTitle);
    expect(foundTest, isTrue, reason: 'media test card was not found');
    final startTest = _buttonFinder('Test camera and microphone');
    expect(
      await _ensureTappable(tester, startTest),
      isTrue,
      reason: 'the media test action did not become reachable',
    );
    await tester.tap(startTest);

    final live = await _pumpUntil(
      tester,
      () =>
          find.textContaining('camera live').evaluate().isNotEmpty ||
          find.text('Test failed').evaluate().isNotEmpty,
      timeout: const Duration(seconds: 45),
    );
    // ignore: avoid_print
    print('VISIBLE MEDIA TEST: ${_visibleTexts()}');
    expect(live, isTrue, reason: 'camera preview did not report live');
    expect(
      find.text('Test failed').evaluate().isEmpty,
      isTrue,
      reason: 'media test reported a failure: ${_visibleTexts()}',
    );
    expect(
      find.text('Main camera live').evaluate().isNotEmpty,
      isTrue,
      reason: 'the main camera did not open',
    );
    expect(
      find.text('Not available in this app').evaluate().isNotEmpty,
      isTrue,
      reason: 'the recording row must state plainly that this app cannot '
          'record, rather than showing an off/on state that reads like a '
          'control (BUG-030)',
    );

    // A live track is not proof of a picture: wait for the renderer to report
    // real decoded frames before treating the camera as working.
    final frames = await _pumpUntil(
      tester,
      () => find.textContaining('received').evaluate().isNotEmpty,
      timeout: const Duration(seconds: 30),
    );
    // ignore: avoid_print
    print('VISIBLE FRAMES: ${_visibleTexts()}');
    expect(frames, isTrue, reason: 'no video frames reached the preview');
    expect(
      find.text('Waiting for the first frame…').evaluate().isEmpty,
      isTrue,
      reason: 'the preview never received a picture',
    );

    // Leave the preview on screen long enough for an external screenshot.
    await tester.pump(const Duration(seconds: 2));
    await Future<void>.delayed(const Duration(seconds: 10));
    await tester.pump(const Duration(milliseconds: 500));

    final switchCamera = _buttonFinder('Switch camera');
    expect(switchCamera, findsOneWidget);
    expect(await _ensureTappable(tester, switchCamera), isTrue);
    await tester.tap(switchCamera);
    final switched = await _pumpUntil(
      tester,
      () => find.text('Front camera live').evaluate().isNotEmpty,
      timeout: const Duration(seconds: 20),
    );
    // ignore: avoid_print
    print('VISIBLE AFTER SWITCH: ${_visibleTexts()}');
    expect(switched, isTrue, reason: 'camera switch did not report the front camera');
    expect(
      find.textContaining('received').evaluate().isNotEmpty,
      isTrue,
      reason: 'the front camera preview lost its video frames',
    );

    // Leave the front-camera preview on screen long enough for a screenshot.
    await tester.pump(const Duration(seconds: 2));
    await Future<void>.delayed(const Duration(seconds: 8));
    await tester.pump(const Duration(milliseconds: 500));

    final mute = _buttonFinder('Mute microphone');
    expect(mute, findsOneWidget);
    expect(await _ensureTappable(tester, mute), isTrue);
    await tester.tap(mute);
    await tester.pump(const Duration(milliseconds: 500));
    expect(
      find.text('Opened, muted for this test').evaluate().isNotEmpty,
      isTrue,
      reason: 'microphone mute state was not shown',
    );

    final stop = _buttonFinder('Stop test');
    expect(stop, findsOneWidget);
    expect(await _ensureTappable(tester, stop), isTrue);
    await tester.tap(stop);
    final stopped = await _pumpUntil(
      tester,
      () => find.text('Stop test').evaluate().isEmpty,
      timeout: const Duration(seconds: 20),
    );
    // ignore: avoid_print
    print('VISIBLE AFTER STOP: ${_visibleTexts()}');
    expect(stopped, isTrue, reason: 'the self-test did not close');
    expect(
      find.text('Camera and microphone test').evaluate().isNotEmpty,
      isTrue,
      reason: 'the settings action is not available after the test',
    );
  });
}

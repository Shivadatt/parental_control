import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';
import 'package:parent_control/features/child/widgets/media_self_test_sheet.dart';

class _FakeTrack extends Fake implements MediaStreamTrack {
  bool stopped = false;

  @override
  bool enabled = true;

  @override
  Future<void> stop() async {
    stopped = true;
  }
}

class _FakeStream extends Fake implements MediaStream {
  _FakeStream({this.audio = const []});

  final List<MediaStreamTrack> audio;
  final List<MediaStreamTrack> video = const [];
  bool disposed = false;

  @override
  List<MediaStreamTrack> getAudioTracks() => audio;

  @override
  List<MediaStreamTrack> getVideoTracks() => video;

  @override
  List<MediaStreamTrack> getTracks() => [...audio, ...video];

  @override
  Future<void> dispose() async {
    disposed = true;
  }
}

Widget _host(Widget child) => MaterialApp(home: Scaffold(body: child));

void _useTallSurface(WidgetTester tester) {
  tester.view.physicalSize = const Size(900, 1800);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);
}

Future<void> _pumpUntil(WidgetTester tester, Finder finder) async {
  for (var i = 0; i < 200 && finder.evaluate().isEmpty; i++) {
    await tester.pump(const Duration(milliseconds: 50));
  }
}

void main() {
  testWidgets('sheet opens without requesting permission or capturing media',
      (tester) async {
    _useTallSurface(tester);
    var permissionCalls = 0;
    var mediaCalls = 0;

    await tester.pumpWidget(_host(MediaSelfTestSheet(
      captureAllowed: () => true,
      permissionRequest: ({
        required bool camera,
        required bool microphone,
      }) async {
        permissionCalls++;
        return {'camera': true, 'microphone': true};
      },
      openMedia: (_) async {
        mediaCalls++;
        return _FakeStream();
      },
    )));
    await tester.pump();

    expect(permissionCalls, 0);
    expect(mediaCalls, 0);
    expect(find.text('Start test'), findsOneWidget);
    expect(
      find.textContaining('Nothing is recorded, saved, or sent'),
      findsOneWidget,
    );
    expect(find.text('Track running, not sent anywhere'), findsNothing);
    expect(find.text('Microphone'), findsNothing);
  });

  testWidgets('tapping Start test opens media, then a failed preview releases it',
      (tester) async {
    _useTallSurface(tester);
    final track = _FakeTrack();
    final stream = _FakeStream(audio: [track]);
    var mediaCalls = 0;
    Map<String, dynamic>? constraints;

    await tester.pumpWidget(_host(MediaSelfTestSheet(
      captureAllowed: () => true,
      permissionRequest: ({
        required bool camera,
        required bool microphone,
      }) async =>
          {'camera': true, 'microphone': true},
      openMedia: (requested) async {
        mediaCalls++;
        constraints = requested;
        return stream;
      },
    )));
    await tester.pump();
    expect(mediaCalls, 0);

    await tester.tap(find.text('Start test'));
    await tester.pump();

    await _pumpUntil(tester, find.text('Test failed'));
    await tester.pump();

    expect(mediaCalls, 1);
    expect(constraints, isNotNull);
    expect(constraints!.containsKey('audio'), isTrue);
    expect(constraints!.containsKey('video'), isTrue);
    // The preview renderer is unavailable on the test host, so the sheet must
    // report the failure instead of claiming live audio. Every track that was
    // opened is stopped so nothing keeps capturing behind the error.
    expect(track.stopped, isTrue);
    expect(stream.disposed, isTrue);
    expect(find.text('Test failed'), findsOneWidget);
    expect(find.text('Track running, not sent anywhere'), findsNothing);
    expect(find.text('Try again'), findsOneWidget);
  });

  testWidgets('permission denial is reported without opening media',
      (tester) async {
    _useTallSurface(tester);
    var mediaCalls = 0;

    await tester.pumpWidget(_host(MediaSelfTestSheet(
      captureAllowed: () => true,
      permissionRequest: ({
        required bool camera,
        required bool microphone,
      }) async =>
          {'camera': true, 'microphone': false},
      openMedia: (_) async {
        mediaCalls++;
        return _FakeStream();
      },
    )));
    await tester.pump();

    await tester.tap(find.text('Start test'));
    await tester.pump();
    await _pumpUntil(tester, find.textContaining('Android denied'));

    expect(mediaCalls, 0);
    expect(find.textContaining('Android denied'), findsOneWidget);
    expect(find.text('Try again'), findsOneWidget);
    expect(find.text('Stop test'), findsNothing);
  });

  testWidgets('a non-child role cannot start the test', (tester) async {
    _useTallSurface(tester);
    var permissionCalls = 0;
    var mediaCalls = 0;

    await tester.pumpWidget(_host(MediaSelfTestSheet(
      captureAllowed: () => false,
      permissionRequest: ({
        required bool camera,
        required bool microphone,
      }) async {
        permissionCalls++;
        return {'camera': true, 'microphone': true};
      },
      openMedia: (_) async {
        mediaCalls++;
        return _FakeStream();
      },
    )));
    await tester.pump();

    expect(find.text('Start test'), findsNothing);
    expect(find.text('Try again'), findsNothing);
    expect(find.textContaining('only runs on the child account'), findsOneWidget);
    expect(permissionCalls, 0);
    expect(mediaCalls, 0);
  });

  testWidgets('default policy keeps capture closed without a child session',
      (tester) async {
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: Builder(
          builder: (context) => TextButton(
            onPressed: () => MediaSelfTestSheet.show(context),
            child: const Text('open'),
          ),
        ),
      ),
    ));

    // The default capture policy resolves against SessionService; without a
    // registered child session it must stay closed rather than guess.
    await tester.tap(find.text('open'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));

    expect(find.text('Test not available'), findsOneWidget);
    expect(find.text('Start test'), findsNothing);
  });
}

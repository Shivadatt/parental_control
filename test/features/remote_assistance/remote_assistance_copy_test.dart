import 'package:flutter_test/flutter_test.dart';
import 'package:parent_control/data/models/remote_session.dart';
import 'package:parent_control/features/remote_assistance/remote_assistance_page.dart';

void main() {
  group('pre-request dialog copy', () {
    test('says the child must accept and then join', () {
      for (final kind in SessionKind.values) {
        final message = requestDialogMessage(kind);
        expect(message, contains('The child must accept it'));
        expect(message, contains('tap Join on their own phone'));
      }
    });

    test('never claims the parent alone opens the child microphone', () {
      for (final kind in SessionKind.values) {
        final message = requestDialogMessage(kind);
        expect(
          message,
          isNot(contains('unless the child accepts and you tap Join')),
        );
        // The old copy implied that the parent tapping Join opens media.
        expect(message, isNot(contains('and you tap Join')));
        expect(message, contains('never opened'));
      }
    });

    test('states that the child microphone opens only after accept and join',
        () {
      expect(
        requestDialogMessage(SessionKind.audio),
        contains(
          "the child's microphone opens only after the child accepts and joins",
        ),
      );
      expect(
        requestDialogMessage(SessionKind.video),
        contains(
          "the child's camera and microphone open only after the child accepts "
          'and joins',
        ),
      );
    });

    test('keeps the expiry promise', () {
      expect(
        requestDialogMessage(SessionKind.audio),
        contains('expires in 10 minutes'),
      );
    });

    test('titles name the requested media', () {
      expect(requestDialogTitle(SessionKind.audio), contains('audio'));
      expect(requestDialogTitle(SessionKind.video), contains('video'));
    });
  });
}

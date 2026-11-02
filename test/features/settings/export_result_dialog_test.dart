import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:parent_control/features/settings/account_privacy_repository.dart';
import 'package:parent_control/features/settings/export_result_dialog.dart';

AccountDataExport _export({required String role}) {
  return AccountDataExport(
    payload: {
      'profile': {'role': role, 'display_name': 'Alex'},
      'tables': {
        'location_events': {
          'row_count': 12,
          'truncated': false,
        },
      },
    },
    fileName: 'parent-control-export-2026-11-02.json',
    byteCount: 4096,
    savedPath: null,
  );
}

Future<void> _open(WidgetTester tester, AccountDataExport export) async {
  await tester.pumpWidget(
    MaterialApp(
      home: Builder(
        builder: (context) => TextButton(
          onPressed: () => showExportResultDialog(context, export),
          child: const Text('open export'),
        ),
      ),
    ),
  );
  await tester.tap(find.text('open export'));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('a parent export is described as family-scoped', (tester) async {
    await _open(tester, _export(role: 'parent'));

    expect(
      find.textContaining('family-scoped, not personal-only'),
      findsOneWidget,
    );
    expect(
      find.textContaining('including rows recorded about other members'),
      findsOneWidget,
    );
    expect(
      find.textContaining('other members’ private data are never included'),
      findsNothing,
    );
  });

  testWidgets('a child export is limited to their own devices, including '
      'parent actions on them', (tester) async {
    await _open(tester, _export(role: 'child'));

    expect(find.textContaining('limited to this account'), findsOneWidget);
    expect(
      find.textContaining('actions a parent took on them'),
      findsOneWidget,
    );
    expect(
      find.textContaining('family-scoped, not personal-only'),
      findsNothing,
    );
  });

  testWidgets('the export names the identifiers it does include',
      (tester) async {
    await _open(tester, _export(role: 'parent'));

    expect(
      find.textContaining('each device row does carry its installation id'),
      findsOneWidget,
    );
    expect(
      find.textContaining('is never selected — no secret hash'),
      findsOneWidget,
    );
    // The old absolute claim: the export does select installation_id.
    expect(
      find.textContaining(
        'are never selected by the export, whatever the role',
      ),
      findsNothing,
    );
  });

  testWidgets('the real server row count is shown', (tester) async {
    await _open(tester, _export(role: 'parent'));

    expect(find.text('location_events: 12 rows'), findsOneWidget);
    expect(find.textContaining('4096 bytes'), findsOneWidget);
  });
}

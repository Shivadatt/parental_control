import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/theme/app_theme.dart';
import 'account_privacy_repository.dart';

/// Shows the real export result: row counts from the server, the written file
/// path (when the platform allowed it) and a clipboard copy of the JSON.
Future<void> showExportResultDialog(
  BuildContext context,
  AccountDataExport export,
) {
  return showDialog<void>(
    context: context,
    builder: (_) => _ExportResultDialog(export: export),
  );
}

class _ExportResultDialog extends StatefulWidget {
  const _ExportResultDialog({required this.export});

  final AccountDataExport export;

  @override
  State<_ExportResultDialog> createState() => _ExportResultDialogState();
}

class _ExportResultDialogState extends State<_ExportResultDialog> {
  bool _copied = false;

  Future<void> _copy() async {
    await Clipboard.setData(ClipboardData(text: widget.export.prettyJson));
    if (!mounted) return;
    setState(() => _copied = true);
  }

  @override
  Widget build(BuildContext context) {
    final export = widget.export;
    final counts = export.rowCounts;
    final truncated = export.truncatedTables;
    return AlertDialog(
      title: const Text('Your data export is ready'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Exported ${export.byteCount} bytes across ${counts.length} tables.',
            ),
            const SizedBox(height: 8),
            for (final entry in counts.entries)
              Text('${entry.key}: ${entry.value} rows'),
            if (truncated.isNotEmpty) ...[
              const SizedBox(height: 10),
              Text(
                'These tables hit the 20,000-row cap and are marked truncated: '
                '${truncated.join(', ')}.',
                style: const TextStyle(color: AppColors.warning, fontSize: 13),
              ),
            ],
            const SizedBox(height: 12),
            Text(
              export.savedPath == null
                  ? 'The file could not be saved on this device. Copy the JSON '
                      'below to keep it.'
                  : 'Saved to ${export.savedPath}',
              style: const TextStyle(color: AppColors.muted, fontSize: 12),
            ),
            const SizedBox(height: 8),
            const Text(
              'The document contains your profile, family membership, devices, '
              'location, usage, alerts and audit rows. Device secrets, tokens '
              'and other members’ private data are never included.',
              style: TextStyle(fontSize: 12, height: 1.4),
            ),
          ],
        ),
      ),
      actions: [
        TextButton.icon(
          onPressed: _copy,
          icon: Icon(_copied ? Icons.check : Icons.copy),
          label: Text(_copied ? 'Copied' : 'Copy JSON'),
        ),
        FilledButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Done'),
        ),
      ],
    );
  }
}
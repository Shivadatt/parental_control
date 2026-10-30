import 'package:flutter/material.dart';

import '../../core/theme/app_theme.dart';
import '../../core/widgets/app_text_field.dart';
import 'delete_confirmation.dart';

/// What the page submits after the second confirmation step.
class DeleteAccountRequest {
  const DeleteAccountRequest({required this.confirm, required this.email});

  final String confirm;
  final String email;
}

/// Second step of account deletion: the user must type `DELETE` *and* the
/// account email. Closing (Cancel or back) returns null; nothing is submitted.
Future<DeleteAccountRequest?> showDeleteAccountDialog(
  BuildContext context, {
  required String accountEmail,
}) {
  return showDialog<DeleteAccountRequest>(
    context: context,
    barrierDismissible: false,
    builder: (_) => DeleteAccountDialog(accountEmail: accountEmail),
  );
}

class DeleteAccountDialog extends StatefulWidget {
  const DeleteAccountDialog({super.key, required this.accountEmail});

  final String accountEmail;

  @override
  State<DeleteAccountDialog> createState() => _DeleteAccountDialogState();
}

class _DeleteAccountDialogState extends State<DeleteAccountDialog> {
  final _wordController = TextEditingController();
  final _emailController = TextEditingController();
  String? _error;

  @override
  void initState() {
    super.initState();
    _wordController.addListener(_onChanged);
    _emailController.addListener(_onChanged);
  }

  @override
  void dispose() {
    _wordController.dispose();
    _emailController.dispose();
    super.dispose();
  }

  void _onChanged() {
    setState(() {
      _error = null;
    }); // Refresh the enabled state of the destructive button.
  }

  bool get _canSubmit => canSubmitDeleteAccount(
        typedWord: _wordController.text,
        typedEmail: _emailController.text,
        accountEmail: widget.accountEmail,
      );

  void _submit() {
    final error = validateDeleteAccountInput(
      typedWord: _wordController.text,
      typedEmail: _emailController.text,
      accountEmail: widget.accountEmail,
    );
    if (error != null) {
      setState(() => _error = error);
      return;
    }
    Navigator.of(context).pop(
      DeleteAccountRequest(
        confirm: _wordController.text.trim(),
        email: _emailController.text.trim(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Delete account permanently?'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'This removes your profile, your family memberships, your device '
              'pairing and your own location, usage, alert and audit rows. '
              'Audit entries you caused are kept with the actor anonymised.',
              style: TextStyle(height: 1.4),
            ),
            const SizedBox(height: 10),
            const Text(
              'Other family members’ data is never deleted. If you own a family '
              'that still has active members or devices, deletion is refused '
              'until they are removed.',
              style: TextStyle(height: 1.4),
            ),
            const SizedBox(height: 16),
            Text(
              'Signed-in email: ${widget.accountEmail}',
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 12),
            AppTextField(
              controller: _wordController,
              label: 'Type DELETE',
              hint: deleteAccountConfirmationWord,
              textCapitalization: TextCapitalization.characters,
              autofillHints: const [],
            ),
            const SizedBox(height: 12),
            AppTextField(
              controller: _emailController,
              label: 'Account email',
              hint: widget.accountEmail,
              keyboardType: TextInputType.emailAddress,
              autofillHints: const [],
            ),
            if (_error != null) ...[
              const SizedBox(height: 10),
              Text(
                _error!,
                style: const TextStyle(color: AppColors.danger, fontSize: 13),
              ),
            ],
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: _canSubmit ? _submit : null,
          style: FilledButton.styleFrom(backgroundColor: AppColors.danger),
          child: const Text('Delete account'),
        ),
      ],
    );
  }
}
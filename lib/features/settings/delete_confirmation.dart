/// Pure confirmation rules for account deletion.
///
/// The UI gate and the controller gate share this function; the server repeats
/// the same checks in `supabase/functions/account/validation.ts`. Nothing here
/// touches Flutter or the network, so it is directly testable.
const String deleteAccountConfirmationWord = 'DELETE';

/// Returns a user-facing reason, or null when the input is acceptable.
String? validateDeleteAccountInput({
  required String typedWord,
  required String typedEmail,
  required String accountEmail,
}) {
  final account = accountEmail.trim().toLowerCase();
  if (account.isEmpty) {
    return 'The signed-in email is not available. Sign in again.';
  }
  if (typedWord.trim() != deleteAccountConfirmationWord) {
    return 'Type $deleteAccountConfirmationWord to confirm.';
  }
  final typed = typedEmail.trim().toLowerCase();
  if (typed.isEmpty) {
    return 'Type the account email to confirm.';
  }
  if (typed != account) {
    return 'The email does not match the signed-in account.';
  }
  return null;
}

bool canSubmitDeleteAccount({
  required String typedWord,
  required String typedEmail,
  required String accountEmail,
}) {
  return validateDeleteAccountInput(
        typedWord: typedWord,
        typedEmail: typedEmail,
        accountEmail: accountEmail,
      ) ==
      null;
}
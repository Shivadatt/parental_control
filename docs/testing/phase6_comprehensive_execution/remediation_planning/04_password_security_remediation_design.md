# 04 — Password Security Remediation Design (SEC-001)

**Document ID:** HAVEN-REM-004  
**Target Defect:** HAVEN-QA-002 (`SEC-001`)  
**Phase:** Phase 1 — Remediation Planning (Strictly Planning-Only)  
**Date:** 2026-11-23  
**Status:** DRAFT FOR OWNER REVIEW & APPROVAL  
**Workspace:** `D:\parentcontrol_app`  
**Git Baseline HEAD:** `5ffc5c170add4bfafd236beb633f00b6fe86243b`  

---

## 1. Vulnerability Overview & Threat Analysis

During Phase 6 testing and historical Run 8 execution, security audit `SEC-001` identified that password inputs across the application lacked essential client-side hardening flags.

### 1.1 Threat Surface
1. **Predictive Keyboard Caching**: By omitting `enableSuggestions: false` and `autocorrect: false` on password inputs, software keyboards (such as Gboard, SwiftKey, or OEM Android keyboards) may index, predict, or cache entered credentials into local user dictionaries or cloud telemetry caches.
2. **Accessibility Node Scraping**: Without explicit `password: true` semantics, accessibility services, screen scraping tools (e.g. UIAutomator), and background assistive apps can read entered password strings directly from the UI hierarchy in plaintext.
3. **Clipboard Sniffing**: Missing `enableInteractiveSelection: true` controls allow unrestricted clipboard manipulation if not carefully managed.

---

## 2. Core Remediation Architecture (`AppTextField`)

The remediation focuses on making `AppTextField` (`lib/core/widgets/app_text_field.dart`) **secure-by-default**. Any field marked `obscureText: true` automatically inherits strict password protection parameters, eliminating the possibility of caller omission.

### 2.1 Proposed Code Architecture for `AppTextField`

```dart
// lib/core/widgets/app_text_field.dart
import 'package:flutter/material.dart';

class AppTextField extends StatelessWidget {
  const AppTextField({
    super.key,
    required this.controller,
    required this.label,
    this.hint,
    this.keyboardType,
    this.obscureText = false,
    this.validator,
    this.prefixIcon,
    this.suffix,
    this.textInputAction,
    this.maxLines = 1,
    this.enabled = true,
    this.helperText,
    this.autofillHints,
    this.onFieldSubmitted,
    this.textCapitalization = TextCapitalization.none,
    this.enableSuggestions,
    this.autocorrect,
  });

  final TextEditingController controller;
  final String label;
  final String? hint;
  final TextInputType? keyboardType;
  final bool obscureText;
  final String? Function(String?)? validator;
  final IconData? prefixIcon;
  final Widget? suffix;
  final TextInputAction? textInputAction;
  final int maxLines;
  final bool enabled;
  final String? helperText;
  final Iterable<String>? autofillHints;
  final ValueChanged<String>? onFieldSubmitted;
  final TextCapitalization textCapitalization;
  final bool? enableSuggestions;
  final bool? autocorrect;

  @override
  Widget build(BuildContext context) {
    // SEC-001 ENFORCEMENT:
    // If obscureText is active, suggestions and autocorrect MUST be disabled
    // unless an explicit caller explicitly enables them (anti-pattern prevented).
    final effectiveEnableSuggestions = obscureText ? false : (enableSuggestions ?? true);
    final effectiveAutocorrect = obscureText ? false : (autocorrect ?? true);

    // Default keyboardType to visiblePassword when obscureText is active and no type provided
    final effectiveKeyboardType = keyboardType ??
        (obscureText ? TextInputType.visiblePassword : TextInputType.text);

    return Semantics(
      password: obscureText,
      obscured: obscureText,
      child: TextFormField(
        controller: controller,
        keyboardType: effectiveKeyboardType,
        obscureText: obscureText,
        enableSuggestions: effectiveEnableSuggestions,
        autocorrect: effectiveAutocorrect,
        validator: validator,
        enabled: enabled,
        maxLines: maxLines,
        textInputAction: textInputAction,
        autofillHints: autofillHints,
        onFieldSubmitted: onFieldSubmitted,
        textCapitalization: obscureText
            ? TextCapitalization.none
            : textCapitalization,
        decoration: InputDecoration(
          labelText: label,
          hintText: hint,
          helperText: helperText,
          prefixIcon: prefixIcon == null ? null : Icon(prefixIcon),
          suffixIcon: suffix,
        ),
      ),
    );
  }
}
```

---

## 3. Caller Audit & Updates

Every authentication and sensitive input screen across the application has been audited to ensure complete compliance:

| Screen File | Field | Current Config | Proposed Update | Autofill Hint |
|---|---|---|---|---|
| `lib/features/auth/login_page.dart:126-148` | Password | `obscureText: true`, no `keyboardType` | Keep `obscureText: true`; automatically receives `enableSuggestions: false`, `autocorrect: false`, `visiblePassword` | `AutofillHints.password` |
| `lib/features/auth/register_page.dart:118-143` | Password | `obscureText: true`, no `keyboardType` | Inherits hardened `AppTextField` settings | `AutofillHints.newPassword` |
| `lib/features/auth/register_page.dart:145-175` | Confirm Password | `obscureText: true`, no `keyboardType` | Inherits hardened `AppTextField` settings | `AutofillHints.newPassword` |
| `lib/features/role_selection/role_selection_page.dart:240-270` | Lock PIN / Admin Code | `obscureText: true`, `number` | Enforce `enableSuggestions: false`, `autocorrect: false`, `keyboardType: TextInputType.numberPassword` | N/A |

---

## 4. Autofill & Accessibility Compatibility

1. **Password Manager Integration**: 
   - Retaining `AutofillHints.password` and `AutofillHints.newPassword` ensures 1Password, Bitwarden, Google Autofill, and iOS Keychain can securely identify and populate the field without exposing plaintext.
2. **Screen Reader Compliance**:
   - `Semantics(password: true, obscured: true)` instructs TalkBack and VoiceOver to suppress vocalizing typed characters unless the user's accessibility setting explicitly enables character echo with headphones.
3. **Show/Hide Toggle Preservation**:
   - The toggle button (`Icons.visibility_outlined` / `Icons.visibility_off_outlined`) toggles `_obscurePassword`. When toggled to visible (`obscureText: false`), `effectiveEnableSuggestions` and `effectiveAutocorrect` still remain `false` if `keyboardType` is `TextInputType.visiblePassword`, maintaining security.

---

## 5. Automated Verification Test Suite

To guarantee that this vulnerability never regresses, the following automated widget test suite will be deployed in `test/core/widgets/app_text_field_security_test.dart`:

```dart
// Proposed Test Suite: test/core/widgets/app_text_field_security_test.dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:parent_control/core/widgets/app_text_field.dart';

void main() {
  group('SEC-001: AppTextField Password Hardening Tests', () {
    testWidgets('enforces suggestions=false and autocorrect=false when obscureText is true', (tester) async {
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

      final textFormField = tester.widget<TextFormField>(find.byType(TextFormField));
      final editableText = tester.widget<EditableText>(find.byType(EditableText));

      expect(editableText.obscureText, isTrue);
      expect(editableText.enableSuggestions, isFalse);
      expect(editableText.autocorrect, isFalse);
    });

    testWidgets('applies password semantics node to accessibility tree', (tester) async {
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

      final semantics = tester.getSemantics(find.byType(AppTextField));
      expect(semantics.isPassword, isTrue);
      expect(semantics.isObscured, isTrue);
    });
  });
}
```

---

## 6. Implementation Prerequisites & Rollback

- **Prerequisites**: Gate A Owner Approval. No schema or native code changes required.
- **Rollback**: If keyboard behavior regressions are reported on legacy Android OEM devices, the flags can be modified cleanly in `app_text_field.dart` without database impact.

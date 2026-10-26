import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:parent_control/app/routes/app_routes.dart';
import 'package:parent_control/core/theme/app_theme.dart';
import 'package:parent_control/core/utils/validators.dart';
import 'package:parent_control/core/widgets/widgets.dart';
import 'package:parent_control/data/models/account.dart';
import 'package:parent_control/features/auth/controllers/register_controller.dart';
import 'package:parent_control/features/auth/route_arguments.dart';
import 'package:parent_control/features/auth/widgets/offline_notice.dart';

class RegisterPage extends StatefulWidget {
  const RegisterPage({super.key});

  @override
  State<RegisterPage> createState() => _RegisterPageState();
}

class _RegisterPageState extends State<RegisterPage> {
  late final RegisterController _controller = Get.find<RegisterController>();
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  final TextEditingController _displayName = TextEditingController();
  final TextEditingController _email = TextEditingController();
  final TextEditingController _password = TextEditingController();
  final TextEditingController _confirmPassword = TextEditingController();
  bool _obscurePassword = true;
  bool _obscureConfirm = true;

  @override
  void initState() {
    super.initState();
    final roleValue = routeString('role');
    _controller.prepare(
      role: roleValue == null ? null : ProfileRole.fromWire(roleValue),
    );
  }

  @override
  void dispose() {
    _displayName.dispose();
    _email.dispose();
    _password.dispose();
    _confirmPassword.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    FocusScope.of(context).unfocus();
    await _controller.signUp(
      displayName: _displayName.text,
      email: _email.text,
      password: _password.text,
      confirmPassword: _confirmPassword.text,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Create account')),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 560),
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
              child: Obx(() {
                final error = _controller.error.value;
                final intendedRole = _controller.intendedRole.value;
                return Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      const OfflineNotice(),
                      Padding(
                        padding: const EdgeInsets.only(bottom: 16),
                        child: InfoBanner(
                          tone: BannerTone.info,
                          icon: Icons.mark_email_unread_outlined,
                          title: 'Email verification comes first',
                          message: intendedRole.isChosen
                              ? 'You picked ${_roleLabel(intendedRole)} '
                                  'earlier. That choice is only stored on this '
                                  'device. After verification the role-lock '
                                  'screen assigns the permanent server role once.'
                              : 'The permanent parent or child role is '
                                  'assigned only after the server confirms '
                                  'this email. Nothing is assigned at sign-up.',
                        ),
                      ),
                      if (error != null)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 16),
                          child: InfoBanner(
                            tone: BannerTone.danger,
                            title: 'Could not create the account',
                            message: error.message,
                            actionLabel: 'Dismiss',
                            onAction: _controller.clearError,
                          ),
                        ),
                      AppTextField(
                        controller: _displayName,
                        label: 'Display name',
                        textInputAction: TextInputAction.next,
                        autofillHints: const [AutofillHints.name],
                        validator: Validators.displayName,
                        prefixIcon: Icons.person_outline,
                      ),
                      const SizedBox(height: 14),
                      AppTextField(
                        controller: _email,
                        label: 'Email',
                        keyboardType: TextInputType.emailAddress,
                        textInputAction: TextInputAction.next,
                        autofillHints: const [AutofillHints.email],
                        validator: Validators.email,
                        prefixIcon: Icons.alternate_email,
                      ),
                      const SizedBox(height: 14),
                      AppTextField(
                        controller: _password,
                        label: 'Password',
                        obscureText: _obscurePassword,
                        textInputAction: TextInputAction.next,
                        autofillHints: const [AutofillHints.newPassword],
                        validator: Validators.password,
                        prefixIcon: Icons.lock_outline,
                        suffix: IconButton(
                          onPressed: () => setState(
                            () => _obscurePassword = !_obscurePassword,
                          ),
                          icon: Icon(
                            _obscurePassword
                                ? Icons.visibility_outlined
                                : Icons.visibility_off_outlined,
                          ),
                          tooltip: _obscurePassword
                              ? 'Show password'
                              : 'Hide password',
                        ),
                      ),
                      const SizedBox(height: 14),
                      AppTextField(
                        controller: _confirmPassword,
                        label: 'Confirm password',
                        obscureText: _obscureConfirm,
                        textInputAction: TextInputAction.done,
                        autofillHints: const [AutofillHints.newPassword],
                        validator: (value) {
                          if ((value ?? '').isEmpty) {
                            return 'Confirm the password';
                          }
                          if (value != _password.text) {
                            return 'The passwords do not match';
                          }
                          return null;
                        },
                        prefixIcon: Icons.lock_outline,
                        suffix: IconButton(
                          onPressed: () => setState(
                            () => _obscureConfirm = !_obscureConfirm,
                          ),
                          icon: Icon(
                            _obscureConfirm
                                ? Icons.visibility_outlined
                                : Icons.visibility_off_outlined,
                          ),
                          tooltip: _obscureConfirm
                              ? 'Show password'
                              : 'Hide password',
                        ),
                        onFieldSubmitted: (_) => _submit(),
                      ),
                      const SizedBox(height: 22),
                      AppButton(
                        label: 'Create account',
                        icon: Icons.person_add_alt,
                        isLoading: _controller.isSubmitting.value,
                        onPressed: _controller.isSubmitting.value
                            ? null
                            : _submit,
                      ),
                      const SizedBox(height: 8),
                      TextButton(
                        onPressed: _controller.isSubmitting.value
                            ? null
                            : () {
                                final role = _controller.intendedRole.value;
                                Get.offNamed(
                                  AppRoutes.login,
                                  arguments: role.isChosen
                                      ? {'role': role.wireName}
                                      : null,
                                );
                              },
                        child: const Text('Already have an account? Sign in'),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'No child data, family link or device permission is '
                        'created by signing up. Those require verification, '
                        'an explicit role and server-side consent.',
                        textAlign: TextAlign.center,
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              color: AppColors.muted,
                            ),
                      ),
                    ],
                  ),
                );
              }),
            ),
          ),
        ),
      ),
    );
  }

  String _roleLabel(ProfileRole role) =>
      role.isChild ? 'Child mode' : 'Parent mode';
}

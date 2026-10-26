import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:parent_control/app/routes/app_routes.dart';
import 'package:parent_control/core/theme/app_theme.dart';
import 'package:parent_control/core/utils/validators.dart';
import 'package:parent_control/core/widgets/widgets.dart';
import 'package:parent_control/data/models/account.dart';
import 'package:parent_control/features/auth/controllers/login_controller.dart';
import 'package:parent_control/features/auth/route_arguments.dart';
import 'package:parent_control/features/auth/widgets/offline_notice.dart';

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  late final LoginController _controller = Get.find<LoginController>();
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  final TextEditingController _email = TextEditingController();
  final TextEditingController _password = TextEditingController();
  bool _obscurePassword = true;

  @override
  void initState() {
    super.initState();
    final roleValue = routeString('role');
    _controller.prepare(
      email: routeString('email'),
      role: roleValue == null ? null : ProfileRole.fromWire(roleValue),
    );
    _email.text = _controller.initialEmail.value;
  }

  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    FocusScope.of(context).unfocus();
    await _controller.signIn(
      email: _email.text,
      password: _password.text,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Sign in')),
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
                      if (intendedRole.isChosen)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 16),
                          child: InfoBanner(
                            title: 'Continuing as ${_roleLabel(intendedRole)}',
                            message:
                                'This device remembers the flow you picked. '
                                'Your profile role and permissions are decided '
                                'by the server after sign-in.',
                          ),
                        ),
                      if (error != null)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 16),
                          child: InfoBanner(
                            tone: error.code == 'email_not_confirmed'
                                ? BannerTone.warning
                                : BannerTone.danger,
                            title: 'Could not sign in',
                            message: error.message,
                            actionLabel: 'Dismiss',
                            onAction: _controller.clearError,
                          ),
                        ),
                      Text(
                        'Welcome back',
                        style: Theme.of(context)
                            .textTheme
                            .headlineSmall
                            ?.copyWith(
                              fontWeight: FontWeight.w800,
                              color: const Color(0xFF172033),
                            ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        'Use the email and password for this account. '
                        'Unverified emails are sent to the verification step.',
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              color: AppColors.muted,
                              height: 1.45,
                            ),
                      ),
                      const SizedBox(height: 22),
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
                        textInputAction: TextInputAction.done,
                        autofillHints: const [AutofillHints.password],
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
                        onFieldSubmitted: (_) => _submit(),
                      ),
                      const SizedBox(height: 22),
                      AppButton(
                        label: 'Sign in',
                        icon: Icons.login,
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
                                final role = intendedRole;
                                Get.toNamed(
                                  AppRoutes.register,
                                  arguments: role.isChosen
                                      ? {'role': role.wireName}
                                      : null,
                                );
                              },
                        child: const Text('New here? Create an account'),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Nothing on this screen grants access. Email '
                        'verification, your server profile role and family '
                        'membership are checked on every request.',
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

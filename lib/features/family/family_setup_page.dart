import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:parent_control/core/theme/app_theme.dart';
import 'package:parent_control/core/utils/validators.dart';
import 'package:parent_control/core/widgets/widgets.dart';
import 'package:parent_control/features/auth/widgets/offline_notice.dart';
import 'package:parent_control/features/family/controllers/family_setup_controller.dart';

class FamilySetupPage extends StatefulWidget {
  const FamilySetupPage({super.key});

  @override
  State<FamilySetupPage> createState() => _FamilySetupPageState();
}

class _FamilySetupPageState extends State<FamilySetupPage> {
  late final FamilySetupController _controller =
      Get.find<FamilySetupController>();
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  final TextEditingController _name = TextEditingController();

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    FocusScope.of(context).unfocus();
    await _controller.create(_name.text);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Create your family')),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 560),
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
              child: Obx(() {
                final error = _controller.error.value;
                final family = _controller.createdFamily.value;
                return Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      const OfflineNotice(),
                      if (error != null)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 16),
                          child: InfoBanner(
                            tone: BannerTone.danger,
                            title: 'The family was not created',
                            message: error.message,
                            actionLabel: 'Dismiss',
                            onAction: _controller.clearError,
                          ),
                        ),
                      if (family != null)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 16),
                          child: InfoBanner(
                            tone: BannerTone.success,
                            title: 'Family confirmed',
                            message:
                                'The server returned “${family.name}”. Opening '
                                'the parent area now.',
                          ),
                        ),
                      const InfoBanner(
                        tone: BannerTone.info,
                        icon: Icons.family_restroom,
                        title: 'One real family, owned by you',
                        message:
                            'This creates a family on the server and adds your '
                            'verified parent account as its owner. It does not '
                            'create, discover or link any child account.',
                      ),
                      const SizedBox(height: 20),
                      AppTextField(
                        controller: _name,
                        label: 'Family name',
                        hint: 'For example: Our household',
                        textInputAction: TextInputAction.done,
                        validator: Validators.familyName,
                        prefixIcon: Icons.home_outlined,
                        onFieldSubmitted: (_) => _submit(),
                      ),
                      const SizedBox(height: 18),
                      AppButton(
                        label: 'Create family',
                        icon: Icons.add_home_work_outlined,
                        isLoading: _controller.isSubmitting.value,
                        onPressed: _controller.isSubmitting.value
                            ? null
                            : _submit,
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'After this step, open Link a child to redeem the '
                        '8-character code shown on the child device. The child '
                        'must approve the request on their own device.',
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              color: AppColors.muted,
                              height: 1.45,
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
}

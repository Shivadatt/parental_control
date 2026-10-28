import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:parent_control/core/theme/app_theme.dart';
import 'package:parent_control/core/utils/validators.dart';
import 'package:parent_control/core/widgets/widgets.dart';
import 'package:parent_control/data/models/account.dart';
import 'package:parent_control/features/auth/route_arguments.dart';
import 'package:parent_control/features/auth/widgets/offline_notice.dart';
import 'package:parent_control/features/role_selection/controllers/role_selection_controller.dart';

class RoleSelectionPage extends StatefulWidget {
  const RoleSelectionPage({super.key});

  @override
  State<RoleSelectionPage> createState() => _RoleSelectionPageState();
}

class _RoleSelectionPageState extends State<RoleSelectionPage> {
  late final RoleSelectionController _controller =
      Get.find<RoleSelectionController>();
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  final TextEditingController _displayName = TextEditingController();
  ProfileRole? _pendingRole;
  bool _opening = false;

  @override
  void initState() {
    super.initState();
    _controller.prepare(
      lockRequested: routeFlag('lock') || routeString('mode') == 'lock',
    );
    _displayName.text = _controller.displayNamePrefill.value;
  }

  @override
  void dispose() {
    _displayName.dispose();
    super.dispose();
  }

  Future<void> _submitLock(ProfileRole role) async {
    if (_pendingRole != null || _controller.isSubmitting.value) return;
    if (!(_formKey.currentState?.validate() ?? false)) return;
    setState(() => _pendingRole = role);
    await _controller.setInitialRole(
      role: role,
      displayName: _displayName.text,
    );
    if (mounted) setState(() => _pendingRole = null);
  }

  Future<void> _open(ProfileRole role, {required bool register}) async {
    if (_opening) return;
    setState(() => _opening = true);
    if (register) {
      await _controller.createAccount(role);
    } else {
      await _controller.continueToLogin(role);
    }
    if (mounted) setState(() => _opening = false);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Obx(
          () => Text(
            _controller.isLockMode.value ? 'Choose your role' : 'Get started',
          ),
        ),
      ),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 620),
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
              child: Obx(() {
                final error = _controller.error.value;
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const OfflineNotice(),
                    if (error != null)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 16),
                        child: InfoBanner(
                          tone: BannerTone.danger,
                          title: 'Could not continue',
                          message: error.message,
                          actionLabel: 'Dismiss',
                          onAction: _controller.clearError,
                        ),
                      ),
                    if (_controller.isLockMode.value)
                      _buildLockContent(context)
                    else if (_controller.isAuthenticated &&
                        _controller.hasServerRole)
                      _buildExistingRoleContent(context)
                    else
                      _buildPreLoginContent(context),
                  ],
                );
              }),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildPreLoginContent(BuildContext context) {
    final intendedRole = _controller.intendedRole;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          'How will you use Parent Control?',
          style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.w800,
                color: const Color(0xFF172033),
              ),
        ),
        const SizedBox(height: 8),
        Text(
          'This choice only opens the matching sign-in or sign-up flow and is '
          'stored on this device. It never grants parent or child permissions.',
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: AppColors.muted,
                height: 1.45,
              ),
        ),
        if (intendedRole.isChosen) ...[
          const SizedBox(height: 14),
          InfoBanner(
            tone: BannerTone.info,
            title: 'Last choice on this device',
            message:
                '${_roleTitle(intendedRole)}. Sign in or create an '
                'account; the server profile still decides access.',
          ),
        ],
        const SizedBox(height: 18),
        _RoleOptionCard(
          icon: Icons.family_restroom,
          title: 'Parent Mode',
          description:
              'Create a family, link a child device with a consent-based '
              'pairing request, and manage that family’s policies.',
          actions: Row(
            children: [
              Expanded(
                child: AppButton(
                  label: 'Sign in',
                  outlined: true,
                  onPressed: _opening
                      ? null
                      : () => _open(ProfileRole.parent, register: false),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: AppButton(
                  label: 'Create account',
                  onPressed: _opening
                      ? null
                      : () => _open(ProfileRole.parent, register: true),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 14),
        _RoleOptionCard(
          icon: Icons.phone_android,
          title: 'Child Mode',
          description:
              'Join a family with a linking code, review what is shared and '
              'approve pairing or assistance requests on the device.',
          actions: Row(
            children: [
              Expanded(
                child: AppButton(
                  label: 'Sign in',
                  outlined: true,
                  onPressed: _opening
                      ? null
                      : () => _open(ProfileRole.child, register: false),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: AppButton(
                  label: 'Create account',
                  onPressed: _opening
                      ? null
                      : () => _open(ProfileRole.child, register: true),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 18),
        Text(
          'A device role is a server-side decision. Local choices are never '
          'used to authorize device data or family access.',
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: AppColors.muted,
              ),
        ),
      ],
    );
  }

  Widget _buildLockContent(BuildContext context) {
    return Form(
      key: _formKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const InfoBanner(
            tone: BannerTone.warning,
            icon: Icons.lock_outline,
            title: 'Server role not set',
            message:
                'The server has no parent or child role for this verified '
                'account yet. Pick one carefully: it is assigned once and '
                'cannot be changed in the app afterwards.',
          ),
          const SizedBox(height: 18),
          AppTextField(
            controller: _displayName,
            label: 'Display name',
            helperText: 'Shown to family members. 1–60 characters.',
            textInputAction: TextInputAction.done,
            validator: Validators.displayName,
            prefixIcon: Icons.person_outline,
          ),
          const SizedBox(height: 16),
          _RoleOptionCard(
            icon: Icons.family_restroom,
            title: 'Set Parent account',
            description:
                'This account will manage a family. After the server confirms '
                'the role you create a family and can link a child.',
            actions: AppButton(
              label: 'Set parent role',
              icon: Icons.family_restroom,
              outlined: true,
              isLoading: _pendingRole == ProfileRole.parent,
              onPressed: _controller.isSubmitting.value
                  ? null
                  : () => _submitLock(ProfileRole.parent),
            ),
          ),
          const SizedBox(height: 14),
          _RoleOptionCard(
            icon: Icons.phone_android,
            title: 'Set Child account',
            description:
                'This account joins a family by linking code. After the server '
                'confirms the role you continue to child enrollment.',
            actions: AppButton(
              label: 'Set child role',
              icon: Icons.phone_android,
              outlined: true,
              isLoading: _pendingRole == ProfileRole.child,
              onPressed: _controller.isSubmitting.value
                  ? null
                  : () => _submitLock(ProfileRole.child),
            ),
          ),
          const SizedBox(height: 16),
          Text(
            'Only the server assigns this role, and only after email '
            'verification. Choosing a card here does not unlock any data by '
            'itself.',
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: AppColors.muted,
                ),
          ),
        ],
      ),
    );
  }

  Widget _buildExistingRoleContent(BuildContext context) {
    final role = _controller.serverRole;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const InfoBanner(
          tone: BannerTone.success,
          icon: Icons.verified_outlined,
          title: 'Role already assigned',
          message:
              'The server profile already has a permanent role. Continue to '
              'the matching part of the app; this screen cannot change it.',
        ),
        const SizedBox(height: 14),
        SectionCard(
          title: 'Your role',
          child: KeyValueRow(
            label: 'Account type',
            value: _roleTitle(role),
          ),
        ),
        const SizedBox(height: 16),
        AppButton(
          label: 'Continue',
          icon: Icons.arrow_forward,
          isLoading: _controller.isSubmitting.value,
          onPressed:
              _controller.isSubmitting.value ? null : _controller.resume,
        ),
      ],
    );
  }

  String _roleTitle(ProfileRole role) {
    if (role.isParent) return 'Parent Mode';
    if (role.isChild) return 'Child Mode';
    return 'Not assigned';
  }
}

class _RoleOptionCard extends StatelessWidget {
  const _RoleOptionCard({
    required this.icon,
    required this.title,
    required this.description,
    required this.actions,
  });

  final IconData icon;
  final String title;
  final String description;
  final Widget actions;

  @override
  Widget build(BuildContext context) {
    return SectionCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(icon, color: AppColors.primary),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  title,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            description,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: AppColors.muted,
                  height: 1.45,
                ),
          ),
          const SizedBox(height: 14),
          actions,
        ],
      ),
    );
  }
}

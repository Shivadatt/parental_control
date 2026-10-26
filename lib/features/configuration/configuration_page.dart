import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';

import '../../app/routes/app_routes.dart';
import '../../core/config/env.dart';
import '../../core/theme/app_theme.dart';
import '../../core/widgets/widgets.dart';
import '../../data/services/supabase_service.dart';

class ConfigurationPage extends StatefulWidget {
  const ConfigurationPage({super.key});

  @override
  State<ConfigurationPage> createState() => _ConfigurationPageState();
}

class _ConfigurationPageState extends State<ConfigurationPage> {
  static const String _runCommand =
      'fvm flutter run \\\n'
      '  --dart-define=SUPABASE_URL=https://YOUR_PROJECT.supabase.co \\\n'
      '  --dart-define=SUPABASE_ANON_KEY=YOUR_PUBLISHABLE_KEY';

  bool _checking = false;
  String? _checkMessage;

  Future<void> _checkAgain() async {
    setState(() {
      _checking = true;
      _checkMessage = null;
    });
    final service = Get.find<SupabaseService>();
    await service.init();
    if (!mounted) return;
    setState(() => _checking = false);
    if (service.isReady) {
      Get.offAllNamed(AppRoutes.splash);
      return;
    }
    setState(() {
      _checkMessage = service.initError?.message ??
          'Supabase is still not reachable with the supplied configuration.';
    });
  }

  Future<void> _copyCommand() async {
    await Clipboard.setData(const ClipboardData(text: _runCommand));
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Command copied without any secret values.')),
    );
  }

  @override
  Widget build(BuildContext context) {
    final service = Get.find<SupabaseService>();
    final url = Uri.tryParse(Env.supabaseUrl);
    final urlState = Env.supabaseUrl.isEmpty
        ? 'Not set'
        : (url != null && url.host.isNotEmpty)
            ? '${url.scheme}://${url.host}'
            : 'Invalid URL';
    final keyState = Env.supabaseAnonKey.isEmpty
        ? 'Not set'
        : 'Present (${Env.supabaseAnonKey.length} characters)';
    final configurationProblem = Env.configurationProblem;

    return Scaffold(
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 760),
            child: ListView(
              padding: const EdgeInsets.fromLTRB(20, 28, 20, 40),
              children: [
                Center(
                  child: Container(
                    width: 64,
                    height: 64,
                    decoration: BoxDecoration(
                      color: AppColors.primary.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: const Icon(
                      Icons.family_restroom,
                      color: AppColors.primary,
                      size: 34,
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  'Connect the backend',
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                        fontWeight: FontWeight.w800,
                        color: const Color(0xFF172033),
                      ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Parent Control needs a Supabase project for accounts, '
                  'pairing and device data. Nothing on this screen is simulated '
                  'and no feature is enabled until the connection succeeds.',
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: AppColors.muted,
                        height: 1.45,
                      ),
                ),
                const SizedBox(height: 24),
                SectionCard(
                  title: 'Current configuration',
                  subtitle: 'Values come from --dart-define at build time.',
                  child: Column(
                    children: [
                      _ConfigRow(
                        label: 'SUPABASE_URL',
                        value: urlState,
                        ok: Env.supabaseUrl.isNotEmpty &&
                            url != null &&
                            url.host.isNotEmpty,
                      ),
                      const Divider(height: 20),
                      _ConfigRow(
                        label: 'SUPABASE_ANON_KEY',
                        value: keyState,
                        ok: Env.supabaseAnonKey.isNotEmpty,
                      ),
                      const Divider(height: 20),
                      _ConfigRow(
                        label: 'STUN_URL',
                        value: Env.defaultStunUrl,
                        ok: true,
                      ),
                      const Divider(height: 20),
                      _ConfigRow(
                        label: 'Client status',
                        value: service.isReady ? 'Connected' : 'Not connected',
                        ok: service.isReady,
                      ),
                    ],
                  ),
                ),
                if (configurationProblem != null &&
                    (Env.supabaseUrl.isNotEmpty ||
                        Env.supabaseAnonKey.isNotEmpty)) ...[
                  const SizedBox(height: 16),
                  InfoBanner(
                    tone: BannerTone.warning,
                    title: 'Configuration rejected',
                    message: configurationProblem,
                  ),
                ],
                if (service.initError != null || _checkMessage != null) ...[
                  const SizedBox(height: 16),
                  InfoBanner(
                    tone: BannerTone.danger,
                    title: 'Connection error',
                    message: _checkMessage ?? service.initError!.message,
                  ),
                ],
                const SizedBox(height: 16),
                SectionCard(
                  title: '1. Provide the publishable configuration',
                  subtitle:
                      'Never put a service-role key, TURN secret or password in the app.',
                  trailing: IconButton(
                    onPressed: _copyCommand,
                    icon: const Icon(Icons.copy_all),
                    tooltip: 'Copy command',
                  ),
                  child: Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: const Color(0xFF0F172A),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const SelectableText(
                      _runCommand,
                      style: TextStyle(
                        color: Color(0xFFE2E8F0),
                        fontFamily: 'monospace',
                        fontSize: 12.5,
                        height: 1.5,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                SectionCard(
                  title: '2. Deploy the database and functions',
                  subtitle: 'The Supabase account owner performs these steps.',
                  child: Text(
                    'Apply the SQL migrations in supabase/migrations, then deploy '
                    'the Edge Functions and set the server-side secrets '
                    '(SUPABASE_SERVICE_ROLE_KEY, TURN_URL, TURN_SECRET, '
                    'TURN_TTL_SECONDS, CRON_SECRET). The exact commands and '
                    'dashboard steps are in docs/backend.md. This repository '
                    'never contains live secrets, and deployment is never '
                    'performed by the app.',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: AppColors.muted,
                          height: 1.5,
                        ),
                  ),
                ),
                const SizedBox(height: 16),
                SectionCard(
                  title: '3. Re-check the connection',
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Text(
                        'After supplying the configuration and restarting the '
                        'build, run the check below. If the values were changed '
                        'without rebuilding, the check cannot see them.',
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              color: AppColors.muted,
                              height: 1.5,
                            ),
                      ),
                      const SizedBox(height: 14),
                      AppButton(
                        label: 'Check configuration again',
                        icon: Icons.refresh,
                        isLoading: _checking,
                        onPressed: _checking ? null : _checkAgain,
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),
                Text(
                  '.env.example lists the placeholder names. Only the '
                  'publishable (anon) key belongs in the client; privileged '
                  'keys remain server-side.',
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: AppColors.muted,
                      ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _ConfigRow extends StatelessWidget {
  const _ConfigRow({
    required this.label,
    required this.value,
    required this.ok,
  });

  final String label;
  final String value;
  final bool ok;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(
          ok ? Icons.check_circle : Icons.radio_button_unchecked,
          size: 18,
          color: ok ? AppColors.success : AppColors.muted,
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            label,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
          ),
        ),
        const SizedBox(width: 12),
        Flexible(
          child: Text(
            value,
            textAlign: TextAlign.right,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: AppColors.muted,
                ),
          ),
        ),
      ],
    );
  }
}

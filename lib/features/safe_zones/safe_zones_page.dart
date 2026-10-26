import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../core/theme/app_theme.dart';
import '../../core/widgets/widgets.dart';
import '../../data/models/telemetry.dart';
import 'safe_zones_controller.dart';

class SafeZonesPage extends GetView<SafeZonesController> {
  const SafeZonesPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Safe zones'),
        actions: [
          Obx(
            () => IconButton(
              tooltip: 'Refresh',
              onPressed: controller.isRefreshing.value
                  ? null
                  : () => controller.load(refresh: true),
              icon: const Icon(Icons.refresh),
            ),
          ),
        ],
      ),
      body: Obx(() {
        if (controller.isLoading.value) {
          return const LoadingState(label: 'Loading safe zones…');
        }
        final fatalError = controller.error.value;
        if (fatalError != null) {
          return ErrorState(
            error: fatalError,
            onRetry: () => controller.load(refresh: true),
          );
        }
        return RefreshIndicator(
          onRefresh: () => controller.load(refresh: true),
          child: ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.only(top: 8, bottom: 32),
            children: [
              if (!controller.canManage)
                PageSection(
                  child: InfoBanner(
                    tone: controller.familyError.value == null
                        ? BannerTone.info
                        : BannerTone.warning,
                    title: controller.familyError.value == null
                        ? 'View only'
                        : 'Owner status unavailable',
                    message: controller.familyError.value == null
                        ? 'Only the family owner can create, edit, or delete '
                            'safe zones. The server enforces this.'
                        : 'The family could not be loaded, so owner controls '
                            'are hidden. ${controller.familyError.value!.message}',
                    actionLabel: controller.familyError.value == null
                        ? null
                        : 'Retry',
                    onAction: controller.familyError.value == null
                        ? null
                        : () => controller.load(refresh: true),
                  ),
                ),
              Obx(
                () => controller.actionError.value == null
                    ? const SizedBox.shrink()
                    : PageSection(
                        child: InfoBanner(
                          tone: BannerTone.danger,
                          title: 'Action failed',
                          message: controller.actionError.value!.message,
                        ),
                      ),
              ),
              if (controller.zones.isEmpty)
                PageSection(
                  child: SectionCard(
                    child: EmptyState(
                      icon: Icons.fence_outlined,
                      title: 'No safe zones yet',
                      message:
                          'Safe zones are optional circles used for enter/exit '
                          'alerts. Coordinates come from a location you enter, '
                          'never from a map or a guessed position.',
                      actionLabel:
                          controller.canManage ? 'Create a zone' : null,
                      onAction: controller.canManage
                          ? () => _openEditor(context)
                          : null,
                    ),
                  ),
                )
              else
                ...controller.zones.map(
                  (zone) => PageSection(
                    child: _ZoneCard(
                      zone: zone,
                      canManage: controller.canManage,
                      busy: controller.savingZoneId.value == zone.id,
                      onEdit: () => _openEditor(context, zone: zone),
                      onDelete: () => _confirmDelete(context, zone),
                      onToggle: (value) => controller.setActive(zone, value),
                    ),
                  ),
                ),
              if (controller.canManage)
                PageSection(
                  child: AppButton(
                    label: 'Create a safe zone',
                    icon: Icons.add_location_alt_outlined,
                    onPressed: () => _openEditor(context),
                  ),
                ),
            ],
          ),
        );
      }),
    );
  }

  Future<void> _openEditor(BuildContext context, {SafeZone? zone}) async {
    await showDialog<void>(
      context: context,
      builder: (dialogContext) => _SafeZoneEditor(
        controller: controller,
        zone: zone,
      ),
    );
  }

  Future<void> _confirmDelete(BuildContext context, SafeZone zone) async {
    final confirmed = await ConfirmDialog.show(
      context,
      title: 'Delete “${zone.name}”?',
      message:
          'This removes the zone for the whole family. Existing location '
          'history is not changed.',
      confirmLabel: 'Delete',
      destructive: true,
    );
    if (!confirmed) return;
    await controller.deleteZone(zone);
  }
}

class _ZoneCard extends StatelessWidget {
  const _ZoneCard({
    required this.zone,
    required this.canManage,
    required this.busy,
    required this.onEdit,
    required this.onDelete,
    required this.onToggle,
  });

  final SafeZone zone;
  final bool canManage;
  final bool busy;
  final VoidCallback onEdit;
  final VoidCallback onDelete;
  final ValueChanged<bool> onToggle;

  @override
  Widget build(BuildContext context) {
    return SectionCard(
      title: zone.name,
      trailing: StatusChip(
        label: zone.active ? 'Active' : 'Inactive',
        tone: zone.active ? StatusTone.success : StatusTone.neutral,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          KeyValueRow(
            label: 'Centre',
            value:
                '${zone.latitude.toStringAsFixed(5)}, ${zone.longitude.toStringAsFixed(5)}',
          ),
          KeyValueRow(
            label: 'Radius',
            value: '${zone.radiusM.round()} m',
          ),
          const SizedBox(height: 4),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('Active'),
            subtitle: const Text(
              'Inactive zones stay saved but are not evaluated by the device.',
            ),
            value: zone.active,
            onChanged: canManage && !busy ? onToggle : null,
          ),
          if (busy)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 6),
              child: LinearProgressIndicator(),
            ),
          if (canManage)
            Row(
              children: [
                Expanded(
                  child: AppButton(
                    label: 'Edit',
                    icon: Icons.edit_outlined,
                    outlined: true,
                    expanded: false,
                    onPressed: busy ? null : onEdit,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: AppButton(
                    label: 'Delete',
                    icon: Icons.delete_outline,
                    outlined: true,
                    destructive: true,
                    expanded: false,
                    onPressed: busy ? null : onDelete,
                  ),
                ),
              ],
            ),
          if (!canManage)
            const Text(
              'Only the family owner can change this zone.',
              style: TextStyle(color: AppColors.muted, fontSize: 12),
            ),
        ],
      ),
    );
  }
}

class _SafeZoneEditor extends StatefulWidget {
  const _SafeZoneEditor({required this.controller, this.zone});

  final SafeZonesController controller;
  final SafeZone? zone;

  @override
  State<_SafeZoneEditor> createState() => _SafeZoneEditorState();
}

class _SafeZoneEditorState extends State<_SafeZoneEditor> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _name;
  late final TextEditingController _latitude;
  late final TextEditingController _longitude;
  late final TextEditingController _radius;
  late bool _active;

  @override
  void initState() {
    super.initState();
    final zone = widget.zone;
    _name = TextEditingController(text: zone?.name ?? '');
    _latitude = TextEditingController(
      text: zone == null ? '' : zone.latitude.toString(),
    );
    _longitude = TextEditingController(
      text: zone == null ? '' : zone.longitude.toString(),
    );
    _radius = TextEditingController(
      text: zone == null ? '' : zone.radiusM.round().toString(),
    );
    _active = zone?.active ?? true;
  }

  @override
  void dispose() {
    _name.dispose();
    _latitude.dispose();
    _longitude.dispose();
    _radius.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    final saved = await widget.controller.saveZone(
      zoneId: widget.zone?.id,
      name: _name.text,
      latitude: double.parse(_latitude.text.trim()),
      longitude: double.parse(_longitude.text.trim()),
      radiusM: double.parse(_radius.text.trim()),
      active: _active,
    );
    if (!mounted) return;
    if (saved) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.zone == null ? 'Create safe zone' : 'Edit safe zone'),
      content: SingleChildScrollView(
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Obx(
                () => widget.controller.actionError.value == null
                    ? const SizedBox.shrink()
                    : Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: InfoBanner(
                          tone: BannerTone.danger,
                          message: widget.controller.actionError.value!.message,
                        ),
                      ),
              ),
              AppTextField(
                controller: _name,
                label: 'Zone name',
                validator: widget.controller.validateName,
                textCapitalization: TextCapitalization.words,
                textInputAction: TextInputAction.next,
              ),
              const SizedBox(height: 12),
              AppTextField(
                controller: _latitude,
                label: 'Latitude',
                hint: 'e.g. 37.42200 (decimal degrees)',
                keyboardType:
                    const TextInputType.numberWithOptions(decimal: true, signed: true),
                validator: widget.controller.validateLatitude,
                textInputAction: TextInputAction.next,
              ),
              const SizedBox(height: 12),
              AppTextField(
                controller: _longitude,
                label: 'Longitude',
                hint: 'e.g. -122.08400 (decimal degrees)',
                keyboardType:
                    const TextInputType.numberWithOptions(decimal: true, signed: true),
                validator: widget.controller.validateLongitude,
                textInputAction: TextInputAction.next,
              ),
              const SizedBox(height: 12),
              AppTextField(
                controller: _radius,
                label: 'Radius (metres)',
                hint: '50 to 5000',
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                validator: widget.controller.validateRadius,
                helperText: 'Server accepts 50–5000 m.',
              ),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('Active'),
                value: _active,
                onChanged: (value) => setState(() => _active = value),
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        Obx(
          () => FilledButton(
            onPressed: widget.controller.isSaving.value ? null : _save,
            child: widget.controller.isSaving.value
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : Text(widget.zone == null ? 'Create' : 'Save'),
          ),
        ),
      ],
    );
  }
}

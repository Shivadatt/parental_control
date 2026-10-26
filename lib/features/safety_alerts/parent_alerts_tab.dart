import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../core/widgets/widgets.dart';
import '../../data/repositories/repository_contracts.dart';
import '../../data/services/session_service.dart';
import 'alerts_body.dart';
import 'safety_alerts_controller.dart';

/// Shell tab used by Agent C's ParentShellPage.
class ParentAlertsTab extends StatelessWidget {
  const ParentAlertsTab({super.key});

  @override
  Widget build(BuildContext context) {
    final session = Get.find<SessionService>();
    final familyId = session.activeFamily.value?.id ?? '';
    if (familyId.isEmpty) {
      return const EmptyState(
        icon: Icons.family_restroom,
        title: 'No active family',
        message: 'Create or join a family to see safety alerts.',
      );
    }
    return GetX<SafetyAlertsController>(
      tag: 'parent-alerts-tab:$familyId',
      init: SafetyAlertsController(
        alertRepository: Get.find<AlertRepository>(),
        familyId: familyId,
      ),
      builder: (controller) => AlertsBody(controller: controller, compact: true),
    );
  }
}

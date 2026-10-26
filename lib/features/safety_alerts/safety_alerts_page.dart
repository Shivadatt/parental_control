import 'package:flutter/material.dart';
import 'package:get/get.dart';

import 'alerts_body.dart';
import 'safety_alerts_controller.dart';

class SafetyAlertsPage extends GetView<SafetyAlertsController> {
  const SafetyAlertsPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Safety alerts')),
      body: AlertsBody(controller: controller),
    );
  }
}

import 'package:flutter/material.dart';
import 'package:get/get.dart';

import 'parent_settings_controller.dart';
import 'settings_body.dart';

class ParentSettingsPage extends GetView<ParentSettingsController> {
  const ParentSettingsPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Settings'),
        actions: [
          IconButton(
            tooltip: 'Refresh',
            onPressed: () => controller.refresh(),
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      body: SettingsBody(controller: controller),
    );
  }
}

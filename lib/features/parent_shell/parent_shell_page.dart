import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:parent_control/features/dashboard/parent_dashboard_tab.dart';
import 'package:parent_control/features/devices/parent_devices_tab.dart';
import 'package:parent_control/features/parent_shell/parent_shell_controller.dart';
import 'package:parent_control/features/safety_alerts/parent_alerts_tab.dart';
import 'package:parent_control/features/settings/parent_settings_tab.dart';

class ParentShellPage extends GetView<ParentShellController> {
  const ParentShellPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Obx(
      () => Scaffold(
        body: IndexedStack(
          index: controller.tabIndex.value,
          children: const [
            ParentDashboardTab(),
            ParentDevicesTab(),
            ParentAlertsTab(),
            ParentSettingsTab(),
          ],
        ),
        bottomNavigationBar: NavigationBar(
          selectedIndex: controller.tabIndex.value,
          onDestinationSelected: controller.selectTab,
          destinations: const [
            NavigationDestination(
              icon: Icon(Icons.dashboard_outlined),
              selectedIcon: Icon(Icons.dashboard),
              label: 'Dashboard',
            ),
            NavigationDestination(
              icon: Icon(Icons.devices_other_outlined),
              selectedIcon: Icon(Icons.devices_other),
              label: 'Devices',
            ),
            NavigationDestination(
              icon: Icon(Icons.notifications_outlined),
              selectedIcon: Icon(Icons.notifications),
              label: 'Alerts',
            ),
            NavigationDestination(
              icon: Icon(Icons.settings_outlined),
              selectedIcon: Icon(Icons.settings),
              label: 'Settings',
            ),
          ],
        ),
      ),
    );
  }
}

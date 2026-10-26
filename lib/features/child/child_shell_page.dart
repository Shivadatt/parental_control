import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:parent_control/features/child/controllers/child_shell_controller.dart';
import 'package:parent_control/features/child/tabs/child_home_tab.dart';
import 'package:parent_control/features/child/tabs/child_requests_tab.dart';
import 'package:parent_control/features/child/tabs/child_rules_tab.dart';
import 'package:parent_control/features/child/tabs/child_settings_tab.dart';

class ChildShellPage extends GetView<ChildShellController> {
  const ChildShellPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Obx(
      () => Scaffold(
        body: IndexedStack(
          index: controller.tabIndex.value,
          children: const [
            ChildHomeTab(),
            ChildRulesTab(),
            ChildRequestsTab(),
            ChildSettingsTab(),
          ],
        ),
        bottomNavigationBar: NavigationBar(
          selectedIndex: controller.tabIndex.value,
          onDestinationSelected: controller.selectTab,
          destinations: [
            const NavigationDestination(
              icon: Icon(Icons.home_outlined),
              selectedIcon: Icon(Icons.home),
              label: 'Home',
            ),
            const NavigationDestination(
              icon: Icon(Icons.shield_outlined),
              selectedIcon: Icon(Icons.shield),
              label: 'Rules',
            ),
            NavigationDestination(
              icon: _requestIcon(
                controller.pendingCount,
                selected: false,
              ),
              selectedIcon: _requestIcon(
                controller.pendingCount,
                selected: true,
              ),
              label: 'Requests',
            ),
            const NavigationDestination(
              icon: Icon(Icons.tune_outlined),
              selectedIcon: Icon(Icons.tune),
              label: 'Settings',
            ),
          ],
        ),
      ),
    );
  }

  Widget _requestIcon(int count, {required bool selected}) {
    final icon = Icon(
      selected ? Icons.forum : Icons.forum_outlined,
    );
    if (count <= 0) return icon;
    return Badge.count(count: count, child: icon);
  }
}

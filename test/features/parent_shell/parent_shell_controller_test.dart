import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:parent_control/features/parent_shell/parent_shell_binding.dart';
import 'package:parent_control/features/parent_shell/parent_shell_controller.dart';

void main() {
  setUp(() {
    Get.testMode = true;
  });

  tearDown(() {
    Get.reset();
  });

  test('tab selection stays within the four shell tabs', () {
    final controller = ParentShellController();

    controller.selectTab(2);
    expect(controller.tabIndex.value, 2);

    controller.selectTab(4);
    expect(controller.tabIndex.value, 2);

    controller.selectTab(-1);
    expect(controller.tabIndex.value, 2);
  });

  test('binding registers the shell controller lazily', () {
    ParentShellBinding().dependencies();

    final controller = Get.find<ParentShellController>();
    expect(controller.tabIndex.value, 0);
  });
}

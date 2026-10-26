import 'package:get/get.dart';

class ParentShellController extends GetxController {
  static const tabCount = 4;

  final RxInt tabIndex = 0.obs;

  void selectTab(int index) {
    if (index < 0 || index >= tabCount) return;
    tabIndex.value = index;
  }
}

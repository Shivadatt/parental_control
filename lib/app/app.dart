import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../core/config/env.dart';
import '../core/theme/app_theme.dart';
import 'routes/app_pages.dart';
import 'routes/app_routes.dart';

class ParentControlApp extends StatelessWidget {
  const ParentControlApp({super.key});

  @override
  Widget build(BuildContext context) {
    return GetMaterialApp(
      title: Env.appName,
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light(),
      initialRoute: AppRoutes.splash,
      getPages: AppPages.routes,
      defaultTransition: Transition.cupertino,
      transitionDuration: const Duration(milliseconds: 240),
    );
  }
}

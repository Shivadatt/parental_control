import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:parent_control/core/theme/app_theme.dart';
import 'package:parent_control/data/services/supabase_service.dart';
import 'package:parent_control/features/configuration/configuration_page.dart';

void main() {
  setUp(() {
    Get.put<SupabaseService>(SupabaseService(), permanent: true);
  });

  tearDown(Get.reset);

  testWidgets('configuration screen never pretends a backend is connected',
      (tester) async {
    await tester.pumpWidget(
      GetMaterialApp(
        theme: AppTheme.light(),
        home: const ConfigurationPage(),
      ),
    );

    expect(find.text('Connect the backend'), findsOneWidget);
    expect(find.text('Not set'), findsWidgets);
    expect(find.text('Connected'), findsNothing);
    expect(
      find.textContaining('Nothing on this screen is simulated'),
      findsOneWidget,
    );
  });
}

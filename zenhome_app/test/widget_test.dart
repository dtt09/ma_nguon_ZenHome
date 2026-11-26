import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:zenhome_app/features/onboarding/ui/splash_screen.dart';
import 'package:zenhome_app/main.dart';
import 'package:zenhome_app/core/services/connectivity_service.dart';

class _OfflineConnectivity extends ConnectivityNotifier {
  @override
  Future<bool> checkConnectivity() async => false;
}


void main() {
  testWidgets('Shows the ZenHome splash screen on first launch', (tester) async {
    SharedPreferences.setMockInitialValues({});
    await tester.pumpWidget(ProviderScope(overrides: [connectivityProvider.overrideWith((ref) => _OfflineConnectivity())], child: const ZenHomeApp()));
    expect(find.byType(SplashScreen), findsOneWidget);
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(const Duration(seconds: 2));
  });
}

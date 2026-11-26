import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zenhome_app/core/theme/app_theme.dart';
import 'package:zenhome_app/features/onboarding/ui/onboarding_screen.dart';
import 'package:zenhome_app/features/setup/logic/wifi_setup_wizard_controller.dart';
import 'package:zenhome_app/features/setup/ui/wifi_setup_screen.dart';
import 'package:zenhome_app/l10n/app_localizations.dart';

void main() {
  for (final size in [const Size(320, 640), const Size(640, 320)]) {
    testWidgets('Giới thiệu và thiết lập Wi-Fi ở $size, cỡ chữ 200%', (
      tester,
    ) async {
      tester.view.devicePixelRatio = 1;
      tester.view.physicalSize = size;
      addTearDown(tester.view.reset);
      final container = ProviderContainer();
      addTearDown(container.dispose);
      Widget host(Widget screen) => UncontrolledProviderScope(
        container: container,
        child: MaterialApp(
          theme: AppTheme.lightTheme,
          supportedLocales: AppLocalizations.supportedLocales,
          locale: const Locale('vi'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(context).copyWith(
              textScaler: const TextScaler.linear(2),
              disableAnimations: true,
            ),
            child: child!,
          ),
          home: screen,
        ),
      );
      await tester.pumpWidget(host(const OnboardingScreen()));
      await tester.pumpAndSettle();
      for (var page = 1; page < 3; page++) {
        await tester.tap(find.text('Tiếp theo'));
        await tester.pumpAndSettle();
      }
      expect(find.text('Bắt Đầu'), findsOneWidget);
      expect(tester.takeException(), isNull, reason: 'Giới thiệu');

      await tester.pumpWidget(host(const WifiSetupScreen()));
      await tester.pump();
      expect(tester.takeException(), isNull, reason: 'Chuẩn bị');
      final controller = container.read(wifiSetupWizardProvider.notifier);
      for (var step = 1; step < 4; step++) {
        controller.setStep(step);
        await tester.pump();
        expect(tester.takeException(), isNull, reason: 'Bước ${step + 1}');
      }
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump(const Duration(seconds: 2));
    });
  }
}

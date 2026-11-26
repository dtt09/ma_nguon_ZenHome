import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pinput/pinput.dart';
import 'package:zenhome_app/core/theme/app_theme.dart';
import 'package:zenhome_app/features/auth/ui/otp_verification_screen.dart';
import 'package:zenhome_app/l10n/app_localizations.dart';

void main() {
  for (final language in ['vi', 'en']) {
    testWidgets('OTP fits a 320 dp phone at 200% text in $language', (
      tester,
    ) async {
      tester.view.devicePixelRatio = 1;
      tester.view.physicalSize = const Size(320, 640);
      addTearDown(tester.view.reset);
      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            locale: Locale(language),
            supportedLocales: AppLocalizations.supportedLocales,
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            theme: AppTheme.lightTheme,
            builder: (context, child) => MediaQuery(
              data: MediaQuery.of(context).copyWith(
                textScaler: const TextScaler.linear(2),
                disableAnimations: true,
              ),
              child: child!,
            ),
            home: const OtpVerificationScreen(
              verificationId: 'test',
              phoneNumber: '+84 900 000 000',
            ),
          ),
        ),
      );
      await tester.pump();
      final input = find.byType(Pinput);
      await tester.ensureVisible(input);
      final pin = tester.widget<Pinput>(input);
      expect(pin.length, 6);
      expect(pin.pinAnimationType, PinAnimationType.none);
      expect(pin.defaultPinTheme!.width, lessThan(46));
      await tester.enterText(find.byType(EditableText), '12345');
      tester.view.viewInsets = const FakeViewPadding(bottom: 240);
      await tester.pump();
      expect(pin.controller!.text, '12345');
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump(const Duration(seconds: 1));
    });
  }
}

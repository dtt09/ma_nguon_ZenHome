import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zenhome_app/core/providers/mqtt_provider.dart';
import 'package:zenhome_app/core/theme/app_theme.dart';
import 'package:zenhome_app/core/widgets/animations/telegram_theme_transition.dart';
import 'package:zenhome_app/features/home/ui/weather_card.dart';
import 'package:zenhome_app/l10n/app_localizations.dart';

class _HotRoom extends MqttIndoorTemp {
  @override
  String build() => '52.5';
}

void main() {
  for (final compact in [false, true]) {
    testWidgets('Weather readings reflow and settle (compact: $compact)', (
      tester,
    ) async {
      tester.view.devicePixelRatio = 1;
      tester.view.physicalSize = Size(compact ? 320 : 430, 840);
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.pumpWidget(
        ProviderScope(
          overrides: [mqttIndoorTempProvider.overrideWith(_HotRoom.new)],
          child: MaterialApp(
            theme: AppTheme.darkTheme,
            locale: const Locale('vi'),
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            builder: (context, child) => MediaQuery(
              data: MediaQuery.of(
                context,
              ).copyWith(textScaler: TextScaler.linear(compact ? 2 : 1)),
              child: child!,
            ),
            home: const Scaffold(
              body: SingleChildScrollView(child: WeatherCard()),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      final inside = tester.getTopLeft(find.byIcon(Icons.home_outlined));
      final outside = tester.getTopLeft(find.byIcon(Icons.cloud_outlined));
      expect(outside.dy, compact ? greaterThan(inside.dy) : equals(inside.dy));
      expect(find.text('52.5'), findsOneWidget);
      expect(find.byIcon(Icons.warning_amber_rounded), findsOneWidget);
      expect(tester.takeException(), isNull);
      expect(tester.binding.hasScheduledFrame, isFalse);
    });
  }

  testWidgets('Theme choices apply in order even after a failed change', (
    tester,
  ) async {
    final key = GlobalKey<TelegramThemeTransitionState>();
    await tester.pumpWidget(
      MaterialApp(
        home: MediaQuery(
          data: const MediaQueryData(disableAnimations: true),
          child: TelegramThemeTransition(
            key: key,
            child: const SizedBox.expand(),
          ),
        ),
      ),
    );
    final firstWrite = Completer<void>();
    final calls = <String>[];
    final first = key.currentState!.startThemeTransition(
      center: Offset.zero,
      performThemeChange: () async {
        calls.add('light');
        await firstWrite.future;
        throw StateError('fixture');
      },
    );
    final failed = expectLater(first, throwsStateError);
    final next = key.currentState!.startThemeTransition(
      center: Offset.zero,
      performThemeChange: () async {
        calls.add('dark');
      },
    );
    await tester.pump();
    expect(calls, ['light']);
    firstWrite.complete();
    await tester.pump();
    await failed;
    await next;
    expect(calls, ['light', 'dark']);
    expect(tester.takeException(), isNull);
  });
}

import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:zenhome_app/core/theme/app_theme.dart';
import 'package:zenhome_app/features/home/ui/device_card.dart';
import 'package:zenhome_app/features/home/ui/room_tab.dart';
import 'package:zenhome_app/features/home/ui/scene_section.dart';
import 'package:zenhome_app/l10n/app_localizations.dart';

Widget _homeContent(Widget child, double scale, {bool sliver = false}) => ProviderScope(
  child: MaterialApp(
    theme: AppTheme.lightTheme,
    locale: const Locale('vi'),
    supportedLocales: AppLocalizations.supportedLocales,
    localizationsDelegates: AppLocalizations.localizationsDelegates,
    builder: (context, child) => MediaQuery(
      data: MediaQuery.of(
        context,
      ).copyWith(textScaler: TextScaler.linear(scale), disableAnimations: true),
      child: child!,
    ),
    home: Scaffold(
      body: CustomScrollView(
        slivers: [SliverPadding(
          padding: const EdgeInsets.all(20),
          sliver: sliver ? child : SliverToBoxAdapter(child: child),
        )],
      ),
    ),
  ),
);

void main() {
  const deviceName = 'Đèn đọc sách bên cửa sổ trong phòng sinh hoạt chung';
  const roomName = 'Phòng sinh hoạt chung của gia đình';
  for (final layout in [(320.0, 2.0, 1), (390.0, 1.0, 2), (840.0, 1.0, 4)]) {
    testWidgets('Lưới thiết bị rộng ${layout.$1} ở cỡ chữ ${layout.$2}', (
      tester,
    ) async {
      tester.view.devicePixelRatio = 1;
      tester.view.physicalSize = Size(layout.$1, 900);
      addTearDown(tester.view.reset);
      int taps = 0;
      await tester.pumpWidget(
        _homeContent(
          SliverDeviceGrid(
            itemCount: 80,
            itemBuilder: (context, index) => DeviceCard(
                  key: ValueKey(index),
                  deviceName: '$deviceName $index',
                  roomName: roomName,
                  icon: Icons.lightbulb_rounded,
                  isOn: false,
                  isCooldown: index == 1,
                  onTap: () => taps++,
                ),
          ),
          layout.$2,
          sliver: true,
        ),
      );
      await tester.pump();
      expect(tester.takeException(), isNull);
      expect(find.byKey(const ValueKey(79), skipOffstage: false), findsNothing);
      final first = tester.getRect(find.byKey(const ValueKey(0)));
      expect(
        tester.getRect(find.byKey(ValueKey(layout.$3 - 1))).top,
        first.top,
      );
      expect(
        tester.getRect(find.byKey(ValueKey(layout.$3))).top,
        greaterThan(first.bottom),
      );
      await tester.tap(find.byKey(const ValueKey(0)));
      await tester.ensureVisible(find.byKey(const ValueKey(1)));
      await tester.tap(find.byKey(const ValueKey(1)));
      expect(taps, 1);
      if (layout.$3 == 4) {
        await tester.scrollUntilVisible(find.byKey(const ValueKey(79)), 500);
        expect(find.byKey(const ValueKey(79)), findsOneWidget);
      }
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('Phòng và ngữ cảnh tiếng Việt ở cỡ chữ 200%', (tester) async {
    const sceneName = 'Đọc sách cùng gia đình trước giờ đi ngủ';
    SharedPreferences.setMockInitialValues({
      'custom_scenes_data_guest': jsonEncode([
        {
          'id': 'night',
          'name': sceneName,
          'actions': {'light': 'on'},
        },
      ]),
    });
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(320, 640);
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      _homeContent(
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: RoomTabWidget(
                roomCode: roomName,
                isSelected: true,
                onTap: () {},
              ),
            ),
            const SceneSection(),
          ],
        ),
        2,
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text(sceneName), findsOneWidget);
    expect(tester.widget<Text>(find.text(sceneName)).maxLines, 2);
    expect(
      find.ancestor(of: find.text(sceneName), matching: find.byType(FittedBox)),
      findsNothing,
    );
    expect(tester.takeException(), isNull);
  });
}

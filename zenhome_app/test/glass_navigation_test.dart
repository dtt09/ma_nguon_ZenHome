import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:zenhome_app/core/theme/app_theme.dart';
import 'package:zenhome_app/features/auth/ui/login_screen.dart';
import 'package:zenhome_app/features/home/ui/home_navigation_dock.dart';
import 'package:zenhome_app/features/settings/ui/appearance_preferences.dart';
import 'package:zenhome_app/l10n/app_localizations.dart';

Widget _app(Widget child, {double inset = 0}) {
  return ProviderScope(
    child: MaterialApp(
      locale: const Locale('vi'),
      theme: AppTheme.getLightTheme(AppThemePreset.emeraldZen),
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      builder: (context, child) => MediaQuery(
        data: MediaQuery.of(context).copyWith(
          textScaler: const TextScaler.linear(2),
          disableAnimations: true,
          viewInsets: EdgeInsets.only(bottom: inset),
        ),
        child: child!,
      ),
      home: child,
    ),
  );
}

void main() {
  testWidgets(
    'Vietnamese dock selects by tap and drag at 320 dp with large type',
    (tester) async {
      tester.view.devicePixelRatio = 1;
      tester.view.physicalSize = const Size(320, 640);
      addTearDown(tester.view.reset);
      final pages = PageController();
      var selected = 0;
      await tester.pumpWidget(
        _app(
          StatefulBuilder(
            builder: (context, setState) => Scaffold(
              body: PageView(
                controller: pages,
                onPageChanged: (index) => setState(() => selected = index),
                children: const [Text('0'), Text('1'), Text('2')],
              ),
              bottomNavigationBar: HomeNavigationDock(
                controller: pages,
                currentIndex: selected,
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      for (final label in ['Trang chủ', 'Tiện ích', 'Cài đặt']) {
        expect(find.text(label).hitTestable(), findsOneWidget);
      }
      await tester.tap(find.text('Cài đặt'));
      await tester.pump();
      expect(pages.page, 2);
      final start = tester.getCenter(find.text('Cài đặt'));
      await tester.dragFrom(
        start,
        tester.getCenter(find.text('Trang chủ')) - start,
      );
      await tester.pumpAndSettle();
      expect(selected, 0);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
      pages.dispose();
    },
  );

  testWidgets('appearance choices wrap and retain callbacks at large scale', (
    tester,
  ) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(320, 640);
    addTearDown(tester.view.reset);
    ThemeMode? selectedMode;
    String? selectedLanguage;
    await tester.pumpWidget(
      _app(
        Scaffold(
          body: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: AppearancePreferences(
              mode: ThemeMode.light,
              language: 'vi',
              onThemeChanged: (value, _) => selectedMode = value,
              onLanguageChanged: (value) => selectedLanguage = value,
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Tối'));
    await tester.tap(find.text('English'));
    expect(selectedMode, ThemeMode.dark);
    expect(selectedLanguage, 'en');
    expect(tester.takeException(), isNull);
  });

  testWidgets('login can scroll to alternative actions above keyboard', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({});
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(320, 600);
    addTearDown(tester.view.reset);
    await tester.pumpWidget(_app(const LoginScreen(), inset: 240));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.byType(TextField).last);
    await tester.pumpAndSettle();
    await tester.tap(find.byType(TextField).last);
    await tester.enterText(find.byType(TextField).last, 'test');
    await tester.pump();
    expect(
      tester.widget<TextField>(find.byType(TextField).last).obscureText,
      isTrue,
    );
    final reveal = find.byIcon(Icons.visibility_off_outlined);
    await Scrollable.ensureVisible(tester.element(reveal), alignment: 0.5);
    await tester.pumpAndSettle();
    expect(reveal.hitTestable(), findsOneWidget);
    await tester.tap(reveal);
    await tester.pump();
    expect(
      tester.widget<TextField>(find.byType(TextField).last).obscureText,
      isFalse,
    );
    await tester.ensureVisible(find.text('Google'));
    await tester.pumpAndSettle();
    expect(find.text('Google').hitTestable(), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}

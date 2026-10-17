import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:zenhome_app/features/settings/data/settings_repository.dart';

part 'theme_provider.g.dart';

@riverpod
SettingsRepository settingsRepository(SettingsRepositoryRef ref) {
  return SettingsRepository();
}

@riverpod
class ThemeModeNotifier extends _$ThemeModeNotifier {
  @override
  ThemeMode build() {
    // FIX 3: Trì hoãn việc load state một nhịp để không chọc vào widget đang build
    Future.microtask(() => _loadTheme());
    return ThemeMode.system;
  }

  Future<void> _loadTheme() async {
    state = await ref.read(settingsRepositoryProvider).getThemeMode();
  }

  Future<void> setThemeMode(ThemeMode mode) async {
    await ref.read(settingsRepositoryProvider).setThemeMode(mode);
    state = mode;
  }
}

@riverpod
class LocaleNotifier extends _$LocaleNotifier {
  @override
  Locale build() {
    Future.microtask(() => _loadLocale());
    final deviceLang = PlatformDispatcher.instance.locale.languageCode;
    return Locale(deviceLang == 'vi' ? 'vi' : 'en');
  }

  Future<void> _loadLocale() async {
    final lang = await ref.read(settingsRepositoryProvider).getLanguage();
    state = Locale(lang);
  }

  Future<void> setLocale(String lang) async {
    await ref.read(settingsRepositoryProvider).setLanguage(lang);
    state = Locale(lang);
    try {
      final messaging = FirebaseMessaging.instance;
      await messaging.subscribeToTopic('all_users');
      if (lang == 'en') {
        await messaging.subscribeToTopic('all_users_en');
        await messaging.unsubscribeFromTopic('all_users_vi');
      } else {
        await messaging.subscribeToTopic('all_users_vi');
        await messaging.unsubscribeFromTopic('all_users_en');
      }
    } catch (_) {}
  }
}
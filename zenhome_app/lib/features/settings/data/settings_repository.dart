import 'dart:ui';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter/material.dart';

class SettingsRepository {
  static const String _themeKey = 'app_theme';
  static const String _langKey = 'app_lang';

  Future<ThemeMode> getThemeMode() async {
    final prefs = await SharedPreferences.getInstance();
    final savedTheme = prefs.getString(_themeKey);
    if (savedTheme == 'light') return ThemeMode.light;
    if (savedTheme == 'dark') return ThemeMode.dark;
    return ThemeMode.system;
  }

  Future<void> setThemeMode(ThemeMode mode) async {
    final prefs = await SharedPreferences.getInstance();
    if (mode == ThemeMode.light) await prefs.setString(_themeKey, 'light');
    else if (mode == ThemeMode.dark) await prefs.setString(_themeKey, 'dark');
    else await prefs.remove(_themeKey);
  }

  Future<String> getLanguage() async {
    final prefs = await SharedPreferences.getInstance();
    String? savedLang = prefs.getString(_langKey);
    if (savedLang != null) return savedLang;
    
    String deviceLang = PlatformDispatcher.instance.locale.languageCode;
    return deviceLang == 'vi' ? 'vi' : 'en';
  }

  Future<void> setLanguage(String langCode) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_langKey, langCode);
  }
}

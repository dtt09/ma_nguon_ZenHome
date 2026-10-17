import 'package:flutter/material.dart';

/// Bảng màu & Hệ thống thiết kế chuẩn Luxury / High-End Smart Home cho ZenHome
/// Phong cách: Xanh Zen & Ngọc Lục Bảo (Deep Emerald & Mint Glow)
class AppColors {
  // Brand & Accent Colors
  static const Color primary = Color(0xFF0F766E);          // Deep Emerald Teal
  static const Color primaryDark = Color(0xFF042F2E);      // Midnight Forest
  static const Color primaryLight = Color(0xFF14B8A6);     // Mint Emerald Glow
  static const Color primaryAccent = Color(0xFF2DD4BF);    // Cyber Mint Highlight

  // Functional Accents & Ambient Glows
  static const Color amberGlow = Color(0xFFF59E0B);        // Đèn ấm / Ánh sáng
  static const Color amberDeep = Color(0xFFD97706);
  static const Color cyanGlow = Color(0xFF06B6D4);         // Quạt / Làm mát
  static const Color cyanDeep = Color(0xFF0284C7);
  static const Color emeraldGlow = Color(0xFF10B981);      // Trực tuyến / An toàn
  static const Color roseGlow = Color(0xFFF43F5E);         // Cảnh báo / Ngắt kết nối
  static const Color purpleGlow = Color(0xFF8B5CF6);       // Ngữ cảnh thông minh

  // Light Mode Surfaces (Clean Mint Pearl)
  static const Color lightBg = Color(0xFFF5F9F8);
  static const Color lightCard = Color(0xFFFFFFFF);
  static const Color lightCardBorder = Color(0xFFE2EFEA);
  static const Color lightText = Color(0xFF0F172A);
  static const Color lightTextMuted = Color(0xFF64748B);

  // Dark Mode Surfaces (OLED True Obsidian with subtle emerald atmosphere)
  static const Color darkBg = Color(0xFF081210);
  static const Color darkCard = Color(0xFF0E1F1C);
  static const Color darkCardElevated = Color(0xFF142B27);
  static const Color darkCardBorder = Color(0x2634D399);   // Subtle Mint Glow border
  static const Color darkText = Color(0xFFF0FDF4);
  static const Color darkTextMuted = Color(0xFF94A3B8);

  // Luxury Ambient Gradients
  static const LinearGradient brandHero = LinearGradient(
    colors: [Color(0xFF0F766E), Color(0xFF14B8A6)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const LinearGradient mintHighlight = LinearGradient(
    colors: [Color(0xFF0D9488), Color(0xFF2DD4BF)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const LinearGradient weatherDay = LinearGradient(
    colors: [Color(0xFF0F766E), Color(0xFF14B8A6)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const LinearGradient weatherNight = LinearGradient(
    colors: [Color(0xFF042F2E), Color(0xFF0F172A)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const LinearGradient lightOn = LinearGradient(
    colors: [Color(0xFFF59E0B), Color(0xFFEA580C)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const LinearGradient fanOn = LinearGradient(
    colors: [Color(0xFF14B8A6), Color(0xFF06B6D4)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const LinearGradient deviceDefaultOn = LinearGradient(
    colors: [Color(0xFF0F766E), Color(0xFF10B981)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const LinearGradient navPillGradient = LinearGradient(
    colors: [Color(0xFF0D9488), Color(0xFF14B8A6)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );
}

class AppTheme {
  static ThemeData get lightTheme {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.light,
      scaffoldBackgroundColor: AppColors.lightBg,
      primaryColor: AppColors.primary,
      colorScheme: ColorScheme.fromSeed(
        seedColor: AppColors.primary,
        brightness: Brightness.light,
        primary: AppColors.primary,
        secondary: AppColors.primaryLight,
        surface: AppColors.lightCard,
      ),
      fontFamily: 'Roboto',
      appBarTheme: const AppBarTheme(
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: false,
        scrolledUnderElevation: 0,
        iconTheme: IconThemeData(color: AppColors.lightText),
        titleTextStyle: TextStyle(
          color: AppColors.lightText,
          fontSize: 20,
          fontWeight: FontWeight.bold,
        ),
      ),
      cardTheme: CardThemeData(
        color: AppColors.lightCard,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(24),
          side: const BorderSide(color: AppColors.lightCardBorder, width: 1.2),
        ),
      ),
      dividerTheme: const DividerThemeData(
        color: AppColors.lightCardBorder,
        thickness: 1,
      ),
    );
  }

  static ThemeData get darkTheme {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      scaffoldBackgroundColor: AppColors.darkBg,
      primaryColor: AppColors.primaryLight,
      colorScheme: ColorScheme.fromSeed(
        seedColor: AppColors.primaryLight,
        brightness: Brightness.dark,
        primary: AppColors.primaryLight,
        secondary: AppColors.primaryAccent,
        surface: AppColors.darkCard,
      ),
      fontFamily: 'Roboto',
      appBarTheme: const AppBarTheme(
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: false,
        scrolledUnderElevation: 0,
        iconTheme: IconThemeData(color: AppColors.darkText),
        titleTextStyle: TextStyle(
          color: AppColors.darkText,
          fontSize: 20,
          fontWeight: FontWeight.bold,
        ),
      ),
      cardTheme: CardThemeData(
        color: AppColors.darkCard,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(24),
          side: const BorderSide(color: AppColors.darkCardBorder, width: 1.2),
        ),
      ),
      dividerTheme: const DividerThemeData(
        color: Color(0x1AFFFFFF),
        thickness: 1,
      ),
    );
  }
}

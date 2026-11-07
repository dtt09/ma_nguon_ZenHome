import 'package:flutter/material.dart';

/// Danh sách 6 Chủ đề Đẳng cấp (Zen Luxury Color Presets)
enum AppThemePreset {
  emeraldZen,        // Ngọc Lục Bảo Hoàng Gia (Zen Teal - Mặc định)
  midnightSapphire,  // Lam Biển Sâu Sapphire
  amethystTwilight,  // Thạch Anh Tím Hoàng Hôn
  champagneGold,     // Hoàng Kim Hổ Phách Sang Trọng
  rubyCoral,         // Hồng Ngọc San Hô Tinh Tế
  obsidianCyber,     // Titanium Công Nghệ Tối Giản
}

/// Cấu hình chi tiết cho từng Theme Preset
class ThemePresetConfig {
  final AppThemePreset preset;
  final String key;
  final String titleVi;
  final String titleEn;
  final Color primary;
  final Color primaryDark;
  final Color primaryLight;
  final Color primaryAccent;
  final LinearGradient brandHero;
  final LinearGradient navPillGradient;
  final Color previewColor;
  final IconData icon;

  const ThemePresetConfig({
    required this.preset,
    required this.key,
    required this.titleVi,
    required this.titleEn,
    required this.primary,
    required this.primaryDark,
    required this.primaryLight,
    required this.primaryAccent,
    required this.brandHero,
    required this.navPillGradient,
    required this.previewColor,
    required this.icon,
  });

  static const List<ThemePresetConfig> presets = [
    ThemePresetConfig(
      preset: AppThemePreset.emeraldZen,
      key: 'theme_preset_emerald',
      titleVi: 'Ngọc Lục Bảo Zen',
      titleEn: 'Emerald Zen',
      primary: Color(0xFF0D9488),          // Royal Emerald Teal
      primaryDark: Color(0xFF042F2E),
      primaryLight: Color(0xFF14B8A6),
      primaryAccent: Color(0xFF2DD4BF),
      previewColor: Color(0xFF0D9488),
      icon: Icons.spa_rounded,
      brandHero: LinearGradient(
        colors: [Color(0xFF0D9488), Color(0xFF14B8A6)],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      ),
      navPillGradient: LinearGradient(
        colors: [Color(0xFF0D9488), Color(0xFF14B8A6)],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      ),
    ),
    ThemePresetConfig(
      preset: AppThemePreset.midnightSapphire,
      key: 'theme_preset_sapphire',
      titleVi: 'Lam Biển Sapphire',
      titleEn: 'Midnight Sapphire',
      primary: Color(0xFF2563EB),          // Royal Electric Blue
      primaryDark: Color(0xFF1E3A8A),
      primaryLight: Color(0xFF3B82F6),
      primaryAccent: Color(0xFF60A5FA),
      previewColor: Color(0xFF2563EB),
      icon: Icons.water_drop_rounded,
      brandHero: LinearGradient(
        colors: [Color(0xFF1D4ED8), Color(0xFF3B82F6)],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      ),
      navPillGradient: LinearGradient(
        colors: [Color(0xFF1D4ED8), Color(0xFF3B82F6)],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      ),
    ),
    ThemePresetConfig(
      preset: AppThemePreset.amethystTwilight,
      key: 'theme_preset_amethyst',
      titleVi: 'Thạch Anh Tím',
      titleEn: 'Amethyst Twilight',
      primary: Color(0xFF7C3AED),          // Mystic Amethyst Violet
      primaryDark: Color(0xFF4C1D95),
      primaryLight: Color(0xFF8B5CF6),
      primaryAccent: Color(0xFFA78BFA),
      previewColor: Color(0xFF7C3AED),
      icon: Icons.auto_awesome_rounded,
      brandHero: LinearGradient(
        colors: [Color(0xFF6D28D9), Color(0xFF8B5CF6)],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      ),
      navPillGradient: LinearGradient(
        colors: [Color(0xFF6D28D9), Color(0xFF8B5CF6)],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      ),
    ),
    ThemePresetConfig(
      preset: AppThemePreset.champagneGold,
      key: 'theme_preset_gold',
      titleVi: 'Hoàng Kim Hổ Phách',
      titleEn: 'Champagne Gold',
      primary: Color(0xFFD97706),          // Champagne Amber
      primaryDark: Color(0xFF78350F),
      primaryLight: Color(0xFFF59E0B),
      primaryAccent: Color(0xFFFCD34D),
      previewColor: Color(0xFFF59E0B),
      icon: Icons.wb_sunny_rounded,
      brandHero: LinearGradient(
        colors: [Color(0xFFB45309), Color(0xFFF59E0B)],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      ),
      navPillGradient: LinearGradient(
        colors: [Color(0xFFB45309), Color(0xFFF59E0B)],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      ),
    ),
    ThemePresetConfig(
      preset: AppThemePreset.rubyCoral,
      key: 'theme_preset_ruby',
      titleVi: 'Hồng Ngọc San Hô',
      titleEn: 'Ruby Coral',
      primary: Color(0xFFE11D48),          // Passion Ruby Coral
      primaryDark: Color(0xFF881337),
      primaryLight: Color(0xFFF43F5E),
      primaryAccent: Color(0xFFFB7185),
      previewColor: Color(0xFFF43F5E),
      icon: Icons.favorite_rounded,
      brandHero: LinearGradient(
        colors: [Color(0xFFBE123C), Color(0xFFF43F5E)],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      ),
      navPillGradient: LinearGradient(
        colors: [Color(0xFFBE123C), Color(0xFFF43F5E)],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      ),
    ),
    ThemePresetConfig(
      preset: AppThemePreset.obsidianCyber,
      key: 'theme_preset_cyber',
      titleVi: 'Titanium Công Nghệ',
      titleEn: 'Titanium Slate',
      primary: Color(0xFF475569),          // Minimal Titanium Slate
      primaryDark: Color(0xFF0F172A),
      primaryLight: Color(0xFF64748B),
      primaryAccent: Color(0xFF94A3B8),
      previewColor: Color(0xFF64748B),
      icon: Icons.layers_rounded,
      brandHero: LinearGradient(
        colors: [Color(0xFF334155), Color(0xFF64748B)],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      ),
      navPillGradient: LinearGradient(
        colors: [Color(0xFF334155), Color(0xFF64748B)],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      ),
    ),
  ];

  static ThemePresetConfig fromPreset(AppThemePreset preset) {
    return presets.firstWhere(
      (p) => p.preset == preset,
      orElse: () => presets.first,
    );
  }

  static AppThemePreset fromString(String? val) {
    if (val == null) return AppThemePreset.emeraldZen;
    for (final p in AppThemePreset.values) {
      if (p.name == val) return p;
    }
    return AppThemePreset.emeraldZen;
  }
}

/// ThemeExtension hỗ trợ truy xuất linh hoạt bảng màu và gradient theo Preset được chọn
class ZenThemeColorsExtension extends ThemeExtension<ZenThemeColorsExtension> {
  final Color primary;
  final Color primaryDark;
  final Color primaryLight;
  final Color primaryAccent;
  final LinearGradient brandHero;
  final LinearGradient navPillGradient;
  final Color activeGlow;

  const ZenThemeColorsExtension({
    required this.primary,
    required this.primaryDark,
    required this.primaryLight,
    required this.primaryAccent,
    required this.brandHero,
    required this.navPillGradient,
    required this.activeGlow,
  });

  @override
  ZenThemeColorsExtension copyWith({
    Color? primary,
    Color? primaryDark,
    Color? primaryLight,
    Color? primaryAccent,
    LinearGradient? brandHero,
    LinearGradient? navPillGradient,
    Color? activeGlow,
  }) {
    return ZenThemeColorsExtension(
      primary: primary ?? this.primary,
      primaryDark: primaryDark ?? this.primaryDark,
      primaryLight: primaryLight ?? this.primaryLight,
      primaryAccent: primaryAccent ?? this.primaryAccent,
      brandHero: brandHero ?? this.brandHero,
      navPillGradient: navPillGradient ?? this.navPillGradient,
      activeGlow: activeGlow ?? this.activeGlow,
    );
  }

  @override
  ZenThemeColorsExtension lerp(ThemeExtension<ZenThemeColorsExtension>? other, double t) {
    if (other is! ZenThemeColorsExtension) return this;
    return ZenThemeColorsExtension(
      primary: Color.lerp(primary, other.primary, t)!,
      primaryDark: Color.lerp(primaryDark, other.primaryDark, t)!,
      primaryLight: Color.lerp(primaryLight, other.primaryLight, t)!,
      primaryAccent: Color.lerp(primaryAccent, other.primaryAccent, t)!,
      brandHero: LinearGradient.lerp(brandHero, other.brandHero, t) ?? brandHero,
      navPillGradient: LinearGradient.lerp(navPillGradient, other.navPillGradient, t) ?? navPillGradient,
      activeGlow: Color.lerp(activeGlow, other.activeGlow, t)!,
    );
  }
}

/// Helper extension trên BuildContext để truy xuất màu chủ đề hiện tại
extension ZenThemeContext on BuildContext {
  ZenThemeColorsExtension get zenColors =>
      Theme.of(this).extension<ZenThemeColorsExtension>() ??
      ZenThemeColorsExtension(
        primary: AppColors.primary,
        primaryDark: AppColors.primaryDark,
        primaryLight: AppColors.primaryLight,
        primaryAccent: AppColors.primaryAccent,
        brandHero: AppColors.brandHero,
        navPillGradient: AppColors.navPillGradient,
        activeGlow: AppColors.primaryAccent,
      );
}

/// Bảng màu & Hệ thống thiết kế chuẩn Zen Luxury Minimalist Smart Home
/// Phong cách: Obsidian Titanium & Ambient Glassmorphic Luminescence
class AppColors {
  // Brand & Accent Colors mặc định (Emerald Zen)
  static const Color primary = Color(0xFF0D9488);          // Royal Emerald Teal
  static const Color primaryDark = Color(0xFF042F2E);      // Midnight Forest Obsidian
  static const Color primaryLight = Color(0xFF14B8A6);     // Mint Jade Glow
  static const Color primaryAccent = Color(0xFF2DD4BF);    // Cyber Mint Highlight

  // Functional Accents & Ambient Luminescence
  static const Color amberGlow = Color(0xFFF59E0B);        // Đèn ấm / Sun Gold
  static const Color amberDeep = Color(0xFFD97706);
  static const Color champagneGold = Color(0xFFEAB308);    // Hoàng kim sang trọng
  static const Color cyanGlow = Color(0xFF06B6D4);         // Quạt / Glacier Breeze
  static const Color cyanDeep = Color(0xFF0284C7);
  static const Color emeraldGlow = Color(0xFF10B981);      // Trực tuyến / An toàn
  static const Color emeraldDeep = Color(0xFF059669);
  static const Color roseGlow = Color(0xFFF43F5E);         // Cảnh báo / San hô
  static const Color purpleGlow = Color(0xFF8B5CF6);       // Ngữ cảnh thông minh / Twilight
  static const Color purpleDeep = Color(0xFF6D28D9);

  // Light Mode Surfaces (Warm Alabaster Silk & Nordic Slate)
  static const Color lightBg = Color(0xFFF6F8FC);          // Warm Alabaster Silk
  static const Color lightCard = Color(0xFFFFFFFF);        // Pure Crisp White
  static const Color lightCardElevated = Color(0xFFF1F5F9);// Subtle Layer Card
  static const Color lightCardBorder = Color(0xFFE2E8F0);  // Sharp Defined Border
  static const Color lightText = Color(0xFF0B132B);        // Deep Slate Black
  static const Color lightTextMuted = Color(0xFF64748B);   // Readable Slate Muted

  // Dark Mode Surfaces (Deep Obsidian Titanium - True Zero Haze)
  static const Color darkBg = Color(0xFF070A12);          // Deep Obsidian Night
  static const Color darkCard = Color(0xFF0F1626);        // Titanium Surface
  static const Color darkCardElevated = Color(0xFF162035);// Higher Layer Floating Card
  static const Color darkCardBorder = Color(0x2E38BDF8);   // Micro-Reflective Tech Border
  static const Color darkText = Color(0xFFF8FAFC);        // Crisp High-Readability Text
  static const Color darkTextMuted = Color(0xFF94A3B8);   // Soft Silver Muted

  // Luxury Ambient Gradients
  static const LinearGradient brandHero = LinearGradient(
    colors: [Color(0xFF0D9488), Color(0xFF14B8A6)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const LinearGradient mintHighlight = LinearGradient(
    colors: [Color(0xFF0F766E), Color(0xFF2DD4BF)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const LinearGradient weatherDay = LinearGradient(
    colors: [Color(0xFF0284C7), Color(0xFF0D9488)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const LinearGradient weatherNight = LinearGradient(
    colors: [Color(0xFF0A0F1D), Color(0xFF1E1B4B)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const LinearGradient lightOn = LinearGradient(
    colors: [Color(0xFFF59E0B), Color(0xFFEA580C)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const LinearGradient fanOn = LinearGradient(
    colors: [Color(0xFF06B6D4), Color(0xFF0284C7)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const LinearGradient deviceDefaultOn = LinearGradient(
    colors: [Color(0xFF0D9488), Color(0xFF10B981)],
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
  static ThemeData get lightTheme => getLightTheme(AppThemePreset.emeraldZen);
  static ThemeData get darkTheme => getDarkTheme(AppThemePreset.emeraldZen);

  static ThemeData getLightTheme([AppThemePreset preset = AppThemePreset.emeraldZen]) {
    final cfg = ThemePresetConfig.fromPreset(preset);

    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.light,
      scaffoldBackgroundColor: AppColors.lightBg,
      primaryColor: cfg.primary,
      colorScheme: ColorScheme.fromSeed(
        seedColor: cfg.primary,
        brightness: Brightness.light,
        primary: cfg.primary,
        secondary: cfg.primaryLight,
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
      dialogTheme: DialogThemeData(
        backgroundColor: Colors.white.withOpacity(0.88),
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(28),
          side: BorderSide(color: Colors.white.withOpacity(0.9), width: 1.2),
        ),
      ),
      popupMenuTheme: PopupMenuThemeData(
        color: Colors.white.withOpacity(0.90),
        surfaceTintColor: Colors.transparent,
        elevation: 10,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: const BorderSide(color: AppColors.lightCardBorder, width: 1.0),
        ),
      ),
      bottomSheetTheme: const BottomSheetThemeData(
        backgroundColor: Colors.transparent,
        surfaceTintColor: Colors.transparent,
        modalBackgroundColor: Colors.transparent,
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        backgroundColor: const Color(0xFF0F172A).withOpacity(0.86),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      ),
      extensions: [
        ZenThemeColorsExtension(
          primary: cfg.primary,
          primaryDark: cfg.primaryDark,
          primaryLight: cfg.primaryLight,
          primaryAccent: cfg.primaryAccent,
          brandHero: cfg.brandHero,
          navPillGradient: cfg.navPillGradient,
          activeGlow: cfg.primaryAccent,
        ),
      ],
    );
  }

  static ThemeData getDarkTheme([AppThemePreset preset = AppThemePreset.emeraldZen]) {
    final cfg = ThemePresetConfig.fromPreset(preset);

    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      scaffoldBackgroundColor: AppColors.darkBg,
      primaryColor: cfg.primaryLight,
      colorScheme: ColorScheme.fromSeed(
        seedColor: cfg.primaryLight,
        brightness: Brightness.dark,
        primary: cfg.primaryLight,
        secondary: cfg.primaryAccent,
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
      dialogTheme: DialogThemeData(
        backgroundColor: const Color(0xFF0D1528).withOpacity(0.86),
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(28),
          side: BorderSide(color: Colors.white.withOpacity(0.16), width: 1.2),
        ),
      ),
      popupMenuTheme: PopupMenuThemeData(
        color: const Color(0xFF0E172A).withOpacity(0.90),
        surfaceTintColor: Colors.transparent,
        elevation: 12,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: BorderSide(color: Colors.white.withOpacity(0.14), width: 1.0),
        ),
      ),
      bottomSheetTheme: const BottomSheetThemeData(
        backgroundColor: Colors.transparent,
        surfaceTintColor: Colors.transparent,
        modalBackgroundColor: Colors.transparent,
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        backgroundColor: const Color(0xFF0F172A).withOpacity(0.88),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      ),
      extensions: [
        ZenThemeColorsExtension(
          primary: cfg.primary,
          primaryDark: cfg.primaryDark,
          primaryLight: cfg.primaryLight,
          primaryAccent: cfg.primaryAccent,
          brandHero: cfg.brandHero,
          navPillGradient: cfg.navPillGradient,
          activeGlow: cfg.primaryAccent,
        ),
      ],
    );
  }
}

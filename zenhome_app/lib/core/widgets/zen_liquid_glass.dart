import 'dart:ui';
import 'package:flutter/material.dart';

/// ============================================================================
/// HỆ THỐNG GIAO DIỆN KÍNH LỎNG QUANG HỌC (ZEN LIQUID GLASS SYSTEM)
/// ============================================================================
/// Chuẩn thiết kế Frosted Glassmorphism cao cấp:
/// - Kính mờ khúc xạ ánh sáng (Optical Refractive Blur)
/// - Viền phản xạ ánh kim hai chiều (Bilateral Specular Highlight Border)
/// - Hào quang phát quang thích ứng theo trạng thái (Adaptive Ambient Glow)
/// - Chiều sâu bóng đổ đa tầng mịn mượt (Multi-tier Depth Shadows)
/// ============================================================================

/// 1. Widget Kính Lỏng Cốt Lõi (Core Frosted Glass Component)
class ZenLiquidGlass extends StatelessWidget {
  final Widget child;
  final double borderRadius;
  final EdgeInsetsGeometry? padding;
  final EdgeInsetsGeometry? margin;
  final double? width;
  final double? height;
  final AlignmentGeometry? alignment;
  final Color? surfaceColor;
  final Color? glowColor;
  final double blurSigma;
  final BoxBorder? customBorder;
  final Gradient? customGradient;
  final List<BoxShadow>? customShadows;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;

  const ZenLiquidGlass({
    super.key,
    required this.child,
    this.borderRadius = 24.0,
    this.padding,
    this.margin,
    this.width,
    this.height,
    this.alignment,
    this.surfaceColor,
    this.glowColor,
    this.blurSigma = 16.0,
    this.customBorder,
    this.customGradient,
    this.customShadows,
    this.onTap,
    this.onLongPress,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    // Nước kính lỏng quang học trong suốt
    final effectiveSurface = surfaceColor ??
        (isDark
            ? const Color(0xFF0F1626).withOpacity(0.68)
            : Colors.white.withOpacity(0.78));

    // Viền phản xạ ánh sáng (Specular Highlight Edge)
    final effectiveBorder = customBorder ??
        Border.all(
          color: glowColor != null
              ? glowColor!.withOpacity(isDark ? 0.40 : 0.28)
              : (isDark
                  ? Colors.white.withOpacity(0.14)
                  : const Color(0xFFCBD5E1).withOpacity(0.65)),
          width: 1.2,
        );

    // Bóng đổ quang học đa tầng (Multi-tier Ambient Shadows)
    final effectiveShadows = customShadows ?? [
      if (glowColor != null)
        BoxShadow(
          color: glowColor!.withOpacity(isDark ? 0.22 : 0.12),
          blurRadius: 22,
          spreadRadius: 0,
          offset: const Offset(0, 6),
        ),
      BoxShadow(
        color: Colors.black.withOpacity(isDark ? 0.32 : 0.05),
        blurRadius: 24,
        spreadRadius: 0,
        offset: const Offset(0, 8),
      ),
    ];

    Widget body = Container(
      width: width,
      height: height,
      alignment: alignment,
      padding: padding,
      decoration: BoxDecoration(
        color: effectiveSurface,
        borderRadius: BorderRadius.circular(borderRadius),
        border: effectiveBorder,
        gradient: customGradient ??
            LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: isDark
                  ? [
                      Colors.white.withOpacity(0.09),
                      Colors.white.withOpacity(0.02),
                    ]
                  : [
                      Colors.white.withOpacity(0.65),
                      Colors.white.withOpacity(0.20),
                    ],
            ),
      ),
      child: child,
    );

    // Tối ưu hóa: Nếu blurSigma > 0 mới áp dụng BackdropFilter
    if (blurSigma > 0) {
      body = BackdropFilter(
        filter: ImageFilter.blur(sigmaX: blurSigma, sigmaY: blurSigma),
        child: body,
      );
    }

    Widget glassContainer = Container(
      margin: margin,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(borderRadius),
        boxShadow: effectiveShadows,
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(borderRadius),
        child: body,
      ),
    );

    if (onTap != null || onLongPress != null) {
      return Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(borderRadius),
          onTap: onTap,
          onLongPress: onLongPress,
          child: glassContainer,
        ),
      );
    }

    return glassContainer;
  }
}

/// 2. Thẻ Kính Chuyên Dụng (Zen Glass Card)
/// Dành cho Thẻ Thiết Bị, Thẻ Ngữ Cảnh, Thẻ Thông Báo
class ZenGlassCard extends StatelessWidget {
  final Widget child;
  final double borderRadius;
  final EdgeInsetsGeometry padding;
  final EdgeInsetsGeometry? margin;
  final double? width;
  final double? height;
  final Color? glowColor;
  final bool isActive;
  final double blurSigma;
  final BoxBorder? border;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;

  const ZenGlassCard({
    super.key,
    required this.child,
    this.borderRadius = 24.0,
    this.padding = const EdgeInsets.all(16.0),
    this.margin,
    this.width,
    this.height,
    this.glowColor,
    this.isActive = false,
    this.blurSigma = 14.0,
    this.border,
    this.onTap,
    this.onLongPress,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final Color effectiveGlow = glowColor ??
        (isDark ? const Color(0xFF6366F1) : const Color(0xFF0F766E));

    final Color surface = isActive
        ? (isDark
            ? const Color(0xFF0F172A).withOpacity(0.72)
            : Colors.white.withOpacity(0.85))
        : (isDark
            ? const Color(0xFF0F172A).withOpacity(0.55)
            : Colors.white.withOpacity(0.72));

    final Gradient gradient = LinearGradient(
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
      colors: isActive
          ? (isDark
              ? [
                  effectiveGlow.withOpacity(0.24),
                  effectiveGlow.withOpacity(0.06),
                  const Color(0xFF0F172A).withOpacity(0.6),
                ]
              : [
                  effectiveGlow.withOpacity(0.16),
                  Colors.white.withOpacity(0.9),
                  Colors.white.withOpacity(0.75),
                ])
          : (isDark
              ? [
                  Colors.white.withOpacity(0.08),
                  Colors.white.withOpacity(0.02),
                ]
              : [
                  Colors.white.withOpacity(0.7),
                  Colors.white.withOpacity(0.3),
                ]),
    );

    final BoxBorder effectiveBorder = border ??
        Border.all(
          color: isActive
              ? effectiveGlow.withOpacity(isDark ? 0.6 : 0.45)
              : (isDark
                  ? Colors.white.withOpacity(0.12)
                  : const Color(0xFFE2E8F0).withOpacity(0.8)),
          width: isActive ? 1.4 : 1.1,
        );

    final List<BoxShadow> shadows = [
      if (isActive)
        BoxShadow(
          color: effectiveGlow.withOpacity(isDark ? 0.28 : 0.16),
          blurRadius: 18,
          spreadRadius: 0,
          offset: const Offset(0, 5),
        ),
      BoxShadow(
        color: Colors.black.withOpacity(isDark ? 0.28 : 0.04),
        blurRadius: 16,
        spreadRadius: 0,
        offset: const Offset(0, 6),
      ),
    ];

    return ZenLiquidGlass(
      borderRadius: borderRadius,
      padding: padding,
      margin: margin,
      width: width,
      height: height,
      surfaceColor: surface,
      glowColor: isActive ? effectiveGlow : null,
      blurSigma: blurSigma,
      customBorder: effectiveBorder,
      customGradient: gradient,
      customShadows: shadows,
      onTap: onTap,
      onLongPress: onLongPress,
      child: child,
    );
  }
}

/// 3. Viên Nhộng Kính Siêu Mịn (Zen Glass Pill)
/// Dành cho Status Badges (LAN, BLE, Cloud), Room Tabs, Chips
class ZenGlassPill extends StatelessWidget {
  final Widget child;
  final double borderRadius;
  final EdgeInsetsGeometry padding;
  final EdgeInsetsGeometry? margin;
  final Color? color;
  final Color? glowColor;
  final bool isSelected;
  final double blurSigma;
  final Gradient? customGradient;
  final VoidCallback? onTap;

  const ZenGlassPill({
    super.key,
    required this.child,
    this.borderRadius = 22.0,
    this.padding = const EdgeInsets.symmetric(horizontal: 14.0, vertical: 7.0),
    this.margin,
    this.color,
    this.glowColor,
    this.isSelected = false,
    this.blurSigma = 12.0,
    this.customGradient,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final Color activeColor = glowColor ?? color ?? const Color(0xFF0F766E);

    final Color surface = isSelected
        ? activeColor.withOpacity(isDark ? 0.26 : 0.18)
        : (isDark
            ? Colors.white.withOpacity(0.06)
            : Colors.white.withOpacity(0.65));

    final BoxBorder border = Border.all(
      color: isSelected
          ? activeColor.withOpacity(isDark ? 0.65 : 0.5)
          : (isDark
              ? Colors.white.withOpacity(0.12)
              : const Color(0xFFCBD5E1).withOpacity(0.7)),
      width: isSelected ? 1.3 : 1.0,
    );

    final List<BoxShadow> shadows = [
      if (isSelected)
        BoxShadow(
          color: activeColor.withOpacity(isDark ? 0.32 : 0.20),
          blurRadius: 10,
          spreadRadius: 0,
          offset: const Offset(0, 3),
        ),
      BoxShadow(
        color: Colors.black.withOpacity(isDark ? 0.15 : 0.03),
        blurRadius: 8,
        spreadRadius: 0,
        offset: const Offset(0, 2),
      ),
    ];

    return ZenLiquidGlass(
      borderRadius: borderRadius,
      padding: padding,
      margin: margin,
      surfaceColor: customGradient != null && isSelected ? null : surface,
      customGradient: customGradient,
      glowColor: isSelected ? activeColor : null,
      blurSigma: blurSigma,
      customBorder: border,
      customShadows: shadows,
      onTap: onTap,
      child: child,
    );
  }
}

/// 4. Container Kính Nổi Cấu Trúc (Zen Glass Floating Container)
/// Dành cho Floating Bottom Navigation Bar, Floating App Bar
class ZenGlassContainer extends StatelessWidget {
  final Widget child;
  final double borderRadius;
  final EdgeInsetsGeometry padding;
  final EdgeInsetsGeometry margin;
  final Color? glowColor;
  final double blurSigma;

  const ZenGlassContainer({
    super.key,
    required this.child,
    this.borderRadius = 32.0,
    this.padding = const EdgeInsets.symmetric(horizontal: 10.0, vertical: 8.0),
    this.margin = const EdgeInsets.symmetric(horizontal: 18.0, vertical: 16.0),
    this.glowColor,
    this.blurSigma = 24.0,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final Color surface = isDark
        ? const Color(0xFF0F172A).withOpacity(0.82)
        : Colors.white.withOpacity(0.88);

    final BoxBorder border = Border.all(
      color: isDark
          ? Colors.white.withOpacity(0.16)
          : const Color(0xFFCBD5E1).withOpacity(0.75),
      width: 1.2,
    );

    final List<BoxShadow> shadows = [
      if (glowColor != null)
        BoxShadow(
          color: glowColor!.withOpacity(isDark ? 0.22 : 0.12),
          blurRadius: 24,
          spreadRadius: 0,
          offset: const Offset(0, 6),
        ),
      BoxShadow(
        color: Colors.black.withOpacity(isDark ? 0.45 : 0.08),
        blurRadius: 30,
        spreadRadius: 0,
        offset: const Offset(0, 10),
      ),
      if (isDark)
        BoxShadow(
          color: Colors.white.withOpacity(0.04),
          blurRadius: 10,
          spreadRadius: -2,
          offset: const Offset(0, -2),
        ),
    ];

    return ZenLiquidGlass(
      borderRadius: borderRadius,
      padding: padding,
      margin: margin,
      surfaceColor: surface,
      glowColor: glowColor,
      blurSigma: blurSigma,
      customBorder: border,
      customShadows: shadows,
      child: child,
    );
  }
}

/// 5. Tiện ích hiển thị Bottom Sheet Kính Lỏng (Zen Glass Bottom Sheet)
Future<T?> showZenGlassBottomSheet<T>({
  required BuildContext context,
  required WidgetBuilder builder,
  bool isScrollControlled = true,
  double maxHeightFactor = 0.88,
}) {
  final isDark = Theme.of(context).brightness == Brightness.dark;

  return showModalBottomSheet<T>(
    context: context,
    isScrollControlled: isScrollControlled,
    backgroundColor: Colors.transparent,
    barrierColor: Colors.black.withOpacity(0.58),
    elevation: 0,
    builder: (ctx) {
      final Color sheetSurface = isDark
          ? const Color(0xFF0F172A).withOpacity(0.88)
          : Colors.white.withOpacity(0.92);

      return ClipRRect(
        borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 24, sigmaY: 24),
          child: Container(
            constraints: BoxConstraints(
              maxHeight: MediaQuery.of(ctx).size.height * maxHeightFactor,
            ),
            decoration: BoxDecoration(
              color: sheetSurface,
              borderRadius:
                  const BorderRadius.vertical(top: Radius.circular(32)),
              border: Border(
                top: BorderSide(
                  color: isDark
                      ? Colors.white.withOpacity(0.18)
                      : Colors.white.withOpacity(0.8),
                  width: 1.4,
                ),
                left: BorderSide(
                  color: isDark
                      ? Colors.white.withOpacity(0.08)
                      : const Color(0xFFE2E8F0),
                  width: 1.0,
                ),
                right: BorderSide(
                  color: isDark
                      ? Colors.white.withOpacity(0.08)
                      : const Color(0xFFE2E8F0),
                  width: 1.0,
                ),
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(isDark ? 0.55 : 0.16),
                  blurRadius: 36,
                  offset: const Offset(0, -8),
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Handle bar kéo kính
                Center(
                  child: Container(
                    margin: const EdgeInsets.only(top: 12, bottom: 8),
                    width: 42,
                    height: 5,
                    decoration: BoxDecoration(
                      color: (isDark ? Colors.white : Colors.black)
                          .withOpacity(0.22),
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                ),
                Flexible(child: builder(ctx)),
              ],
            ),
          ),
        ),
      );
    },
  );
}

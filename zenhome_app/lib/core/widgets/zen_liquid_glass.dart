import 'dart:math' as math;
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../theme/app_theme.dart';

/// ============================================================================
/// HỆ THỐNG GIAO DIỆN KÍNH LỎNG QUANG HỌC 2.0 (ZEN LIQUID GLASS 2.0 ENGINE)
/// ============================================================================
/// Chuẩn thiết kế Optical Liquid Glassmorphism toàn diện:
/// 1. Nền Cực Quang Khúc Xạ (ZenAmbientMeshBackground) tạo nguồn sáng đa sắc
/// 2. Kính Mờ Khúc Xạ Thực (Optical Refractive BackdropFilter)
/// 3. Viền Vát Quang Học 3D (3D Directional Specular Beveled Rim Painter)
/// 4. Vệt Phản Xạ Đỉnh Kính (Top Prismatic Inner Caustic Sheen)
/// 5. Đồng bộ 100% với 6 Chủ Đề Zen Luxury (Dynamic ZenThemeColorsExtension)
/// ============================================================================

/// Painter vẽ viền kính vát 3D phản xạ ánh sáng theo góc nghiêng quang học
class _ZenSpecularRimPainter extends CustomPainter {
  final double borderRadius;
  final double strokeWidth;
  final bool isDark;
  final Color? glowColor;
  final bool drawFullRim;

  const _ZenSpecularRimPainter({
    required this.borderRadius,
    required this.strokeWidth,
    required this.isDark,
    this.glowColor,
    this.drawFullRim = true,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (size.isEmpty) return;

    final rect = Offset.zero & size;
    final rrect = RRect.fromRectAndRadius(
      rect.deflate(strokeWidth / 2),
      Radius.circular(math.max(0, borderRadius - strokeWidth / 2)),
    );

    if (drawFullRim) {
      final Color topLeftHighlight = glowColor != null
          ? Color.lerp(Colors.white, glowColor!, isDark ? 0.35 : 0.22)!
              .withOpacity(isDark ? 0.72 : 0.92)
          : Colors.white.withOpacity(isDark ? 0.36 : 0.92);

      final Color midEdge = glowColor != null
          ? glowColor!.withOpacity(isDark ? 0.22 : 0.18)
          : (isDark
              ? Colors.white.withOpacity(0.07)
              : const Color(0xFFCBD5E1).withOpacity(0.42));

      final Color bottomRightCaustic = glowColor != null
          ? glowColor!.withOpacity(isDark ? 0.55 : 0.42)
          : (isDark
              ? Colors.white.withOpacity(0.16)
              : const Color(0xFF94A3B8).withOpacity(0.45));

      final rimPaint = Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = strokeWidth
        ..shader = LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          stops: const [0.0, 0.48, 1.0],
          colors: [
            topLeftHighlight,
            midEdge,
            bottomRightCaustic,
          ],
        ).createShader(rect);

      canvas.drawRRect(rrect, rimPaint);
    }

    // Vệt sáng khúc xạ mép trên (Top Inner Prismatic Sheen)
    if (size.width > 28 && size.height > 20) {
      final sheenInset = strokeWidth + 0.6;
      final sheenWidth = (size.width - borderRadius * 1.4).clamp(12.0, size.width);
      final sheenLeft = (size.width - sheenWidth) / 2;
      final sheenRect = Rect.fromLTWH(sheenLeft, sheenInset, sheenWidth, 1.2);

      final sheenPaint = Paint()
        ..shader = LinearGradient(
          colors: [
            Colors.white.withOpacity(0.0),
            Colors.white.withOpacity(isDark ? 0.26 : 0.75),
            Colors.white.withOpacity(0.0),
          ],
        ).createShader(sheenRect);

      canvas.drawRect(sheenRect, sheenPaint);
    }
  }

  @override
  bool shouldRepaint(covariant _ZenSpecularRimPainter oldDelegate) {
    return oldDelegate.borderRadius != borderRadius ||
        oldDelegate.strokeWidth != strokeWidth ||
        oldDelegate.isDark != isDark ||
        oldDelegate.glowColor != glowColor ||
        oldDelegate.drawFullRim != drawFullRim;
  }
}

/// 0. Nền Cực Quang Khúc Xạ Đa Tầng (Ambient Refractive Aurora Mesh Background)
/// Cung cấp nguồn sáng màu mềm mại phía sau lớp kính để BackdropFilter tạo hiệu ứng
/// khúc xạ quang học chân thực ở mọi màn hình (Sáng & Tối, tương thích 6 Theme Presets).
class ZenAmbientMeshBackground extends StatefulWidget {
  final Widget? child;
  final double intensity;
  final bool animate;

  const ZenAmbientMeshBackground({
    super.key,
    this.child,
    this.intensity = 1.0,
    this.animate = true,
  });

  @override
  State<ZenAmbientMeshBackground> createState() =>
      _ZenAmbientMeshBackgroundState();
}

class _ZenAmbientMeshBackgroundState extends State<ZenAmbientMeshBackground>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 16),
    );
    if (widget.animate) {
      _controller.repeat(reverse: true);
    }
  }

  @override
  void didUpdateWidget(covariant ZenAmbientMeshBackground oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.animate && !_controller.isAnimating) {
      _controller.repeat(reverse: true);
    } else if (!widget.animate && _controller.isAnimating) {
      _controller.stop();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final zen = context.zenColors;
    final disableMotion = MediaQuery.maybeDisableAnimationsOf(context) ?? false;

    final Widget meshLayer = RepaintBoundary(
      child: IgnorePointer(
        child: AnimatedBuilder(
          animation: _controller,
          builder: (context, _) {
            final t = disableMotion ? 0.35 : _controller.value;
            return CustomPaint(
              painter: _ZenAuroraMeshPainter(
                progress: t,
                isDark: isDark,
                primary: zen.primary,
                accent: zen.primaryAccent,
                intensity: widget.intensity,
              ),
              size: Size.infinite,
            );
          },
        ),
      ),
    );

    if (widget.child == null) {
      return Positioned.fill(child: meshLayer);
    }

    return Stack(
      fit: StackFit.expand,
      children: [
        Positioned.fill(child: meshLayer),
        widget.child!,
      ],
    );
  }
}

class _ZenAuroraMeshPainter extends CustomPainter {
  final double progress;
  final bool isDark;
  final Color primary;
  final Color accent;
  final double intensity;

  // Tối ưu hóa GPU: Tái sử dụng đối tượng Paint để tránh cấp phát bộ nhớ liên tục trong vòng lặp vẽ
  static final Paint _reusableBasePaint = Paint();
  static final Paint _reusableOrbPaint = Paint();

  const _ZenAuroraMeshPainter({
    required this.progress,
    required this.isDark,
    required this.primary,
    required this.accent,
    required this.intensity,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (size.isEmpty) return;

    // 1. Nền cơ sở chuẩn Sáng / Tối
    final bgRect = Offset.zero & size;
    _reusableBasePaint.shader = LinearGradient(
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
      colors: isDark
          ? const [
              Color(0xFF060913),
              Color(0xFF0A1020),
              Color(0xFF070B16),
            ]
          : const [
              Color(0xFFF4F7FB),
              Color(0xFFEEF4FA),
              Color(0xFFF8FAFC),
            ],
    ).createShader(bgRect);
    canvas.drawRect(bgRect, _reusableBasePaint);

    final double shortest = size.shortestSide;
    final double phase = progress * math.pi;

    // 2. Quầng sáng Chủ đề Chính (Top-Left Aurora Orb)
    final Offset orb1Center = Offset(
      size.width * (0.16 + 0.12 * math.sin(phase)),
      size.height * (0.12 + 0.06 * math.cos(phase)),
    );
    _drawOrb(
      canvas,
      center: orb1Center,
      radius: shortest * 0.78,
      color: primary,
      opacity: (isDark ? 0.24 : 0.16) * intensity,
    );

    // 3. Quầng sáng Tương phản Phụ (Middle-Right Crystal Cyan/Violet Orb)
    final Color secondaryHue =
        Color.lerp(accent, const Color(0xFF6366F1), isDark ? 0.42 : 0.30)!;
    final Offset orb2Center = Offset(
      size.width * (0.88 - 0.10 * math.cos(phase)),
      size.height * (0.42 + 0.08 * math.sin(phase * 0.8)),
    );
    _drawOrb(
      canvas,
      center: orb2Center,
      radius: shortest * 0.72,
      color: secondaryHue,
      opacity: (isDark ? 0.18 : 0.13) * intensity,
    );

    // 4. Quầng sáng Đáy Ấm/Dịu (Bottom-Left Ambient Glow)
    final Color tertiaryHue =
        Color.lerp(accent, const Color(0xFF0EA5E9), 0.45)!;
    final Offset orb3Center = Offset(
      size.width * (0.25 + 0.14 * math.cos(phase * 0.7)),
      size.height * (0.84 - 0.06 * math.sin(phase)),
    );
    _drawOrb(
      canvas,
      center: orb3Center,
      radius: shortest * 0.76,
      color: tertiaryHue,
      opacity: (isDark ? 0.17 : 0.12) * intensity,
    );
  }

  void _drawOrb(
    Canvas canvas, {
    required Offset center,
    required double radius,
    required Color color,
    required double opacity,
  }) {
    if (radius <= 0 || opacity <= 0) return;
    final rect = Rect.fromCircle(center: center, radius: radius);
    _reusableOrbPaint.shader = RadialGradient(
      colors: [
        color.withOpacity(opacity.clamp(0.0, 1.0)),
        color.withOpacity((opacity * 0.38).clamp(0.0, 1.0)),
        color.withOpacity(0.0),
      ],
      stops: const [0.0, 0.48, 1.0],
    ).createShader(rect);
    canvas.drawCircle(center, radius, _reusableOrbPaint);
  }

  @override
  bool shouldRepaint(covariant _ZenAuroraMeshPainter oldDelegate) {
    return oldDelegate.progress != progress ||
        oldDelegate.isDark != isDark ||
        oldDelegate.primary != primary ||
        oldDelegate.accent != accent ||
        oldDelegate.intensity != intensity;
  }
}

/// 1. Widget Kính Lỏng Cốt Lõi (Core Frosted Glass 2.0 Component)
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
  final bool enableSpecularRim;
  final double rimWidth;

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
    this.blurSigma = 18.0,
    this.customBorder,
    this.customGradient,
    this.customShadows,
    this.onTap,
    this.onLongPress,
    this.enableSpecularRim = true,
    this.rimWidth = 1.2,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    // Nước kính lỏng quang học trong trẻo, cho phép ánh sáng cực quang xuyên qua
    final effectiveSurface = surfaceColor ??
        (isDark
            ? const Color(0xFF0E1628).withOpacity(0.56)
            : Colors.white.withOpacity(0.68));

    // Bóng đổ quang học đa tầng (Multi-tier Ambient & Caustic Shadows)
    final effectiveShadows = customShadows ??
        [
          if (glowColor != null)
            BoxShadow(
              color: glowColor!.withOpacity(isDark ? 0.25 : 0.15),
              blurRadius: 24,
              spreadRadius: 0,
              offset: const Offset(0, 6),
            ),
          BoxShadow(
            color: Colors.black.withOpacity(isDark ? 0.34 : 0.06),
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
        border: customBorder,
        gradient: customGradient ??
            LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              stops: const [0.0, 0.45, 1.0],
              colors: isDark
                  ? [
                      Colors.white.withOpacity(0.12),
                      Colors.white.withOpacity(0.03),
                      (glowColor ?? Colors.white).withOpacity(0.04),
                    ]
                  : [
                      Colors.white.withOpacity(0.78),
                      Colors.white.withOpacity(0.38),
                      (glowColor ?? Colors.white).withOpacity(0.24),
                    ],
            ),
      ),
      child: child,
    );

    if (enableSpecularRim) {
      body = CustomPaint(
        foregroundPainter: _ZenSpecularRimPainter(
          borderRadius: borderRadius,
          strokeWidth: rimWidth,
          isDark: isDark,
          glowColor: glowColor,
          drawFullRim: customBorder == null,
        ),
        child: body,
      );
    }

    // Tối ưu hóa GPU: Chỉ gắn BackdropFilter khi blurSigma > 0
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
          splashColor: (glowColor ?? context.zenColors.primary)
              .withOpacity(isDark ? 0.16 : 0.10),
          highlightColor: Colors.white.withOpacity(isDark ? 0.05 : 0.15),
          onTap: onTap,
          onLongPress: onLongPress,
          child: glassContainer,
        ),
      );
    }

    return glassContainer;
  }
}

/// 2. Thẻ Kính Chuyên Dụng (Zen Glass Card 2.0)
/// Dành cho Thẻ Thiết Bị, Thẻ Ngữ Cảnh, Thẻ Cài Đặt, Thẻ Thông Báo
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
    this.blurSigma = 16.0,
    this.border,
    this.onTap,
    this.onLongPress,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final zen = context.zenColors;

    final Color effectiveGlow =
        glowColor ?? (isDark ? zen.primaryAccent : zen.primary);

    final Color surface = isActive
        ? (isDark
            ? const Color(0xFF0F172A).withOpacity(0.62)
            : Colors.white.withOpacity(0.78))
        : (isDark
            ? const Color(0xFF0E1628).withOpacity(0.48)
            : Colors.white.withOpacity(0.64));

    final Gradient gradient = LinearGradient(
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
      colors: isActive
          ? (isDark
              ? [
                  effectiveGlow.withOpacity(0.24),
                  effectiveGlow.withOpacity(0.07),
                  const Color(0xFF0F172A).withOpacity(0.45),
                ]
              : [
                  effectiveGlow.withOpacity(0.16),
                  Colors.white.withOpacity(0.84),
                  Colors.white.withOpacity(0.66),
                ])
          : (isDark
              ? [
                  Colors.white.withOpacity(0.10),
                  Colors.white.withOpacity(0.03),
                  Colors.white.withOpacity(0.01),
                ]
              : [
                  Colors.white.withOpacity(0.76),
                  Colors.white.withOpacity(0.45),
                  Colors.white.withOpacity(0.30),
                ]),
    );

    final List<BoxShadow> shadows = [
      if (isActive)
        BoxShadow(
          color: effectiveGlow.withOpacity(isDark ? 0.28 : 0.16),
          blurRadius: 20,
          spreadRadius: 0,
          offset: const Offset(0, 6),
        ),
      BoxShadow(
        color: Colors.black.withOpacity(isDark ? 0.28 : 0.05),
        blurRadius: 18,
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
      customBorder: border,
      rimWidth: isActive ? 1.45 : 1.15,
      customGradient: gradient,
      customShadows: shadows,
      onTap: onTap,
      onLongPress: onLongPress,
      child: child,
    );
  }
}

/// 3. Viên Nhộng Kính Siêu Mịn (Zen Glass Pill 2.0)
/// Dành cho Status Badges (LAN, BLE, Cloud), Room Tabs, Filter Chips
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
    this.blurSigma = 14.0,
    this.customGradient,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final zen = context.zenColors;
    final Color activeColor = glowColor ?? color ?? zen.primary;

    final Color surface = isSelected
        ? activeColor.withOpacity(isDark ? 0.28 : 0.18)
        : (isDark
            ? Colors.white.withOpacity(0.07)
            : Colors.white.withOpacity(0.62));

    final List<BoxShadow> shadows = [
      if (isSelected)
        BoxShadow(
          color: activeColor.withOpacity(isDark ? 0.32 : 0.20),
          blurRadius: 12,
          spreadRadius: 0,
          offset: const Offset(0, 3),
        ),
      BoxShadow(
        color: Colors.black.withOpacity(isDark ? 0.16 : 0.04),
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
      rimWidth: isSelected ? 1.35 : 1.05,
      customShadows: shadows,
      onTap: onTap,
      child: child,
    );
  }
}

/// 4. Container Kính Nổi Cấu Trúc (Zen Glass Floating Container 2.0)
/// Dành cho Floating Bottom Navigation Bar, Floating Dock, Segmented Bars
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
    this.blurSigma = 26.0,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final Color surface = isDark
        ? const Color(0xFF0B1222).withOpacity(0.68)
        : Colors.white.withOpacity(0.76);

    final List<BoxShadow> shadows = [
      if (glowColor != null)
        BoxShadow(
          color: glowColor!.withOpacity(isDark ? 0.24 : 0.14),
          blurRadius: 26,
          spreadRadius: 0,
          offset: const Offset(0, 6),
        ),
      BoxShadow(
        color: Colors.black.withOpacity(isDark ? 0.45 : 0.09),
        blurRadius: 30,
        spreadRadius: 0,
        offset: const Offset(0, 10),
      ),
    ];

    return ZenLiquidGlass(
      borderRadius: borderRadius,
      padding: padding,
      margin: margin,
      surfaceColor: surface,
      glowColor: glowColor,
      blurSigma: blurSigma,
      rimWidth: 1.3,
      customShadows: shadows,
      child: child,
    );
  }
}

/// ============================================================================
/// HỆ THỐNG THANH MENU & PHÂN ĐOẠN ĐỒNG BỘ (UNIFIED ZEN GLASS MENUS)
/// ============================================================================

/// Mục cho Thanh Menu Phân Đoạn Kính Lỏng (Zen Glass Segmented Item)
class ZenGlassSegmentedItem<T> {
  final T value;
  final String label;
  final IconData? icon;
  final Widget? customWidget;
  final Color? activeGlowColor;

  const ZenGlassSegmentedItem({
    required this.value,
    required this.label,
    this.icon,
    this.customWidget,
    this.activeGlowColor,
  });
}

/// 4b. Thanh Menu Phân Đoạn Kính Lỏng Cao Cấp (Zen Glass Segmented Bar 2.0)
/// Đồng bộ 100% thuộc tính thị giác và động lực học lò xo của Thanh Menu Chính (Main Bottom Navigation Dock).
/// Sử dụng quy tắc "Single-Pass BackdropFilter": Vỏ ngoài làm mờ 1 lần duy nhất, các phần tử con
/// và giọt kính lỏng trượt bên trong đặt blurSigma: 0 để đạt chuẩn mượt mà 60-120 FPS!
class ZenGlassSegmentedBar<T> extends StatelessWidget {
  final List<ZenGlassSegmentedItem<T>> items;
  final T selectedValue;
  final ValueChanged<T> onValueChanged;
  final double height;
  final double borderRadius;
  final EdgeInsetsGeometry margin;
  final EdgeInsetsGeometry padding;
  final double blurSigma;
  final Color? glowColor;
  final Gradient? activeGradient;

  const ZenGlassSegmentedBar({
    super.key,
    required this.items,
    required this.selectedValue,
    required this.onValueChanged,
    this.height = 46.0,
    this.borderRadius = 28.0,
    this.margin = const EdgeInsets.symmetric(horizontal: 0.0, vertical: 6.0),
    this.padding = const EdgeInsets.all(4.0),
    this.blurSigma = 18.0,
    this.glowColor,
    this.activeGradient,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final zen = context.zenColors;

    final selectedIndex = items.indexWhere((it) => it.value == selectedValue);
    final activeItem = selectedIndex != -1 ? items[selectedIndex] : null;
    final Color effectiveGlow = activeItem?.activeGlowColor ??
        glowColor ??
        (isDark ? zen.primaryAccent : zen.primary);

    return RepaintBoundary(
      child: ZenGlassContainer(
        borderRadius: borderRadius,
        margin: margin,
        padding: padding,
        blurSigma: blurSigma,
        glowColor: effectiveGlow,
        child: SizedBox(
          height: height,
          child: LayoutBuilder(
            builder: (context, constraints) {
              final double totalWidth = constraints.maxWidth;
              final int count = items.length;
              if (count == 0) return const SizedBox.shrink();

              final double itemWidth = totalWidth / count;
              final double pillLeft =
                  selectedIndex >= 0 ? selectedIndex * itemWidth : 0.0;

              return Stack(
                children: [
                  // Giọt Kính Lỏng Trượt Lò Xo (Spring Liquid Droplet Pill)
                  if (selectedIndex >= 0)
                    AnimatedPositioned(
                      duration: const Duration(milliseconds: 340),
                      curve: Curves.easeOutBack,
                      left: pillLeft,
                      top: 0,
                      bottom: 0,
                      width: itemWidth,
                      child: Container(
                        margin: const EdgeInsets.symmetric(
                          horizontal: 2.5,
                          vertical: 2.0,
                        ),
                        decoration: BoxDecoration(
                          gradient: activeGradient ?? zen.navPillGradient,
                          borderRadius: BorderRadius.circular(
                            math.max(12.0, borderRadius - 6.0),
                          ),
                          border: Border.all(
                            color: Colors.white.withOpacity(isDark ? 0.42 : 0.65),
                            width: 1.2,
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: effectiveGlow.withOpacity(isDark ? 0.38 : 0.22),
                              blurRadius: 14,
                              spreadRadius: 0,
                              offset: const Offset(0, 3),
                            ),
                          ],
                        ),
                      ),
                    ),

                  // Các Mục Lựa Chọn (Interactive Tab Items)
                  Row(
                    children: items.map((item) {
                      final bool isSelected = item.value == selectedValue;
                      const Color activeTextColor = Colors.white;
                      final Color inactiveTextColor = isDark
                          ? AppColors.darkTextMuted
                          : AppColors.lightTextMuted;

                      return Expanded(
                        child: Material(
                          color: Colors.transparent,
                          child: InkWell(
                            borderRadius: BorderRadius.circular(
                              math.max(12.0, borderRadius - 6.0),
                            ),
                            splashColor: effectiveGlow.withOpacity(0.15),
                            highlightColor: Colors.transparent,
                            onTap: () {
                              HapticFeedback.selectionClick();
                              if (item.value != selectedValue) {
                                onValueChanged(item.value);
                              }
                            },
                            child: Center(
                              child: item.customWidget ??
                                  Row(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      if (item.icon != null) ...[
                                        AnimatedScale(
                                          scale: isSelected ? 1.12 : 0.95,
                                          duration:
                                              const Duration(milliseconds: 240),
                                          curve: Curves.easeOutBack,
                                          child: Icon(
                                            item.icon,
                                            size: 17.5,
                                            color: isSelected
                                                ? activeTextColor
                                                : inactiveTextColor,
                                          ),
                                        ),
                                        const SizedBox(width: 6),
                                      ],
                                      AnimatedDefaultTextStyle(
                                        duration:
                                            const Duration(milliseconds: 220),
                                        curve: Curves.easeOutCubic,
                                        style: TextStyle(
                                          fontSize: 13,
                                          fontWeight: isSelected
                                              ? FontWeight.w800
                                              : FontWeight.w600,
                                          color: isSelected
                                              ? activeTextColor
                                              : inactiveTextColor,
                                          letterSpacing: 0.2,
                                        ),
                                        child: Text(
                                          item.label,
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ),
                                    ],
                                  ),
                            ),
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }
}

/// Mục cho Thanh Lọc Danh Mục Kính Lỏng (Zen Glass Filter Item)
class ZenGlassFilterItem<T> {
  final T value;
  final String label;
  final IconData? icon;
  final Color? color;
  final int? badgeCount;

  const ZenGlassFilterItem({
    required this.value,
    required this.label,
    this.icon,
    this.color,
    this.badgeCount,
  });
}

/// 4c. Thanh Lọc Phân Loại Kính Lỏng Cuộn Ngang (Zen Glass Scrollable Filter Bar 2.0)
/// Dành cho Thanh Phân Loại Thông Báo, Dải Tab Phòng, Danh Mục Tiện Ích.
/// Thiết kế rãnh kính lỏng cao cấp với hiệu ứng giọt sáng chỉ báo, viền vát 3D và tối ưu 0 blur cục bộ đạt 120 FPS.
class ZenGlassScrollableFilterBar<T> extends StatelessWidget {
  final List<ZenGlassFilterItem<T>> items;
  final T selectedValue;
  final ValueChanged<T> onSelected;
  final double height;
  final EdgeInsetsGeometry padding;
  final double borderRadius;
  final double blurSigma;
  final bool showOuterContainer;

  const ZenGlassScrollableFilterBar({
    super.key,
    required this.items,
    required this.selectedValue,
    required this.onSelected,
    this.height = 46.0,
    this.padding = const EdgeInsets.symmetric(horizontal: 16.0),
    this.borderRadius = 22.0,
    this.blurSigma = 18.0,
    this.showOuterContainer = false,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final zen = context.zenColors;

    Widget listView = SizedBox(
      height: height,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        physics: const BouncingScrollPhysics(),
        padding: padding,
        itemCount: items.length,
        itemBuilder: (context, index) {
          final item = items[index];
          final bool isSelected = item.value == selectedValue;
          final Color itemColor =
              item.color ?? (isDark ? zen.primaryAccent : zen.primary);

          final LinearGradient? activeGradient = item.color != null
              ? LinearGradient(
                  colors: [
                    item.color!.withOpacity(0.95),
                    Color.lerp(item.color!, Colors.white, 0.20)!,
                  ],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                )
              : zen.navPillGradient;

          return RepaintBoundary(
            child: Padding(
              padding: EdgeInsets.only(
                right: index == items.length - 1 ? 0 : 8.0,
              ),
              child: ZenGlassPill(
                isSelected: isSelected,
                glowColor: itemColor,
                blurSigma: 0, // Tối ưu GPU: 0 blur trên từng chip để đạt 120 FPS khi cuộn!
                customGradient: isSelected ? activeGradient : null,
                borderRadius: borderRadius,
                padding: const EdgeInsets.symmetric(
                  horizontal: 15,
                  vertical: 8,
                ),
                onTap: () {
                  HapticFeedback.selectionClick();
                  if (item.value != selectedValue) {
                    onSelected(item.value);
                  }
                },
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (item.icon != null) ...[
                      AnimatedScale(
                        scale: isSelected ? 1.15 : 1.0,
                        duration: const Duration(milliseconds: 240),
                        curve: Curves.easeOutBack,
                        child: Icon(
                          item.icon,
                          size: 16,
                          color: isSelected
                              ? Colors.white
                              : (isDark
                                  ? itemColor.withOpacity(0.95)
                                  : itemColor),
                        ),
                      ),
                      const SizedBox(width: 6),
                    ],
                    AnimatedDefaultTextStyle(
                      duration: const Duration(milliseconds: 200),
                      curve: Curves.easeOutCubic,
                      style: TextStyle(
                        fontSize: 12.5,
                        fontWeight:
                            isSelected ? FontWeight.w800 : FontWeight.w600,
                        color: isSelected
                            ? Colors.white
                            : (isDark
                                ? AppColors.darkText
                                : AppColors.lightText),
                        letterSpacing: 0.15,
                      ),
                      child: Text(item.label),
                    ),
                    if (item.badgeCount != null && item.badgeCount! > 0) ...[
                      const SizedBox(width: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 6,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: isSelected
                              ? Colors.white.withOpacity(0.28)
                              : itemColor.withOpacity(0.18),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Text(
                          '${item.badgeCount}',
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w800,
                            color: isSelected ? Colors.white : itemColor,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );

    if (showOuterContainer) {
      return RepaintBoundary(
        child: ZenGlassContainer(
          borderRadius: borderRadius + 6,
          margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
          blurSigma: blurSigma,
          child: listView,
        ),
      );
    }

    return RepaintBoundary(child: listView);
  }
}

/// 5. Nút Icon Kính Lỏng (Zen Glass Icon Button)
/// Dùng cho nút Back, nút Tùy chọn, nút Hành động trên AppBar và Thẻ
class ZenGlassIconButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback? onTap;
  final double size;
  final double iconSize;
  final double borderRadius;
  final Color? iconColor;
  final Color? glowColor;
  final String? tooltip;
  final double blurSigma;

  const ZenGlassIconButton({
    super.key,
    required this.icon,
    this.onTap,
    this.size = 40.0,
    this.iconSize = 20.0,
    this.borderRadius = 14.0,
    this.iconColor,
    this.glowColor,
    this.tooltip,
    this.blurSigma = 14.0,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final effectiveIconColor =
        iconColor ?? (isDark ? AppColors.darkText : AppColors.lightText);

    Widget btn = ZenLiquidGlass(
      width: size,
      height: size,
      borderRadius: borderRadius,
      blurSigma: blurSigma,
      glowColor: glowColor,
      surfaceColor: isDark
          ? Colors.white.withOpacity(0.08)
          : Colors.white.withOpacity(0.68),
      customShadows: [
        BoxShadow(
          color: Colors.black.withOpacity(isDark ? 0.22 : 0.05),
          blurRadius: 10,
          offset: const Offset(0, 3),
        ),
      ],
      onTap: onTap != null
          ? () {
              HapticFeedback.selectionClick();
              onTap!();
            }
          : null,
      alignment: Alignment.center,
      child: Icon(icon, size: iconSize, color: effectiveIconColor),
    );

    if (tooltip != null && tooltip!.isNotEmpty) {
      btn = Tooltip(message: tooltip!, child: btn);
    }
    return btn;
  }
}

/// 6. Thanh Tiêu Đề Kính Mờ Quang Học (Zen Glass AppBar)
class ZenGlassAppBar extends StatelessWidget implements PreferredSizeWidget {
  final Widget? title;
  final String? titleText;
  final Widget? leading;
  final List<Widget>? actions;
  final bool centerTitle;
  final bool automaticallyImplyLeading;
  final VoidCallback? onBack;
  final PreferredSizeWidget? bottom;
  final double toolbarHeight;
  final double blurSigma;

  const ZenGlassAppBar({
    super.key,
    this.title,
    this.titleText,
    this.leading,
    this.actions,
    this.centerTitle = false,
    this.automaticallyImplyLeading = true,
    this.onBack,
    this.bottom,
    this.toolbarHeight = 60.0,
    this.blurSigma = 22.0,
  });

  @override
  Size get preferredSize => Size.fromHeight(
        toolbarHeight + (bottom?.preferredSize.height ?? 0.0),
      );

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final canPop = ModalRoute.of(context)?.canPop ?? false;

    Widget? effectiveLeading = leading;
    if (effectiveLeading == null && automaticallyImplyLeading && canPop) {
      effectiveLeading = Center(
        child: Padding(
          padding: const EdgeInsets.only(left: 12),
          child: ZenGlassIconButton(
            icon: Icons.arrow_back_ios_new_rounded,
            size: 38,
            iconSize: 17,
            blurSigma: 0,
            onTap: onBack ?? () => Navigator.of(context).maybePop(),
          ),
        ),
      );
    }

    final Widget? effectiveTitle = title ??
        (titleText != null
            ? Text(
                titleText!,
                style: TextStyle(
                  fontSize: 19,
                  fontWeight: FontWeight.w800,
                  letterSpacing: -0.3,
                  color: isDark ? AppColors.darkText : AppColors.lightText,
                ),
              )
            : null);

    return ClipRect(
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: blurSigma, sigmaY: blurSigma),
        child: Container(
          decoration: BoxDecoration(
            color: isDark
                ? const Color(0xFF080D1A).withOpacity(0.56)
                : Colors.white.withOpacity(0.66),
            border: Border(
              bottom: BorderSide(
                color: isDark
                    ? Colors.white.withOpacity(0.10)
                    : const Color(0xFFCBD5E1).withOpacity(0.65),
                width: 1.0,
              ),
            ),
          ),
          child: AppBar(
            toolbarHeight: toolbarHeight,
            backgroundColor: Colors.transparent,
            surfaceTintColor: Colors.transparent,
            elevation: 0,
            scrolledUnderElevation: 0,
            centerTitle: centerTitle,
            automaticallyImplyLeading: false,
            leadingWidth: effectiveLeading != null ? 54 : null,
            leading: effectiveLeading,
            title: effectiveTitle,
            actions: actions != null
                ? [
                    ...actions!,
                    const SizedBox(width: 8),
                  ]
                : null,
            bottom: bottom,
          ),
        ),
      ),
    );
  }
}

/// 7. Khung Màn Hình Kính Lỏng Chuẩn (Zen Glass Scaffold)
class ZenGlassScaffold extends StatelessWidget {
  final PreferredSizeWidget? appBar;
  final Widget body;
  final Widget? bottomNavigationBar;
  final Widget? floatingActionButton;
  final FloatingActionButtonLocation? floatingActionButtonLocation;
  final bool extendBodyBehindAppBar;
  final bool extendBody;
  final bool resizeToAvoidBottomInset;
  final double meshIntensity;

  const ZenGlassScaffold({
    super.key,
    this.appBar,
    required this.body,
    this.bottomNavigationBar,
    this.floatingActionButton,
    this.floatingActionButtonLocation,
    this.extendBodyBehindAppBar = false,
    this.extendBody = false,
    this.resizeToAvoidBottomInset = true,
    this.meshIntensity = 1.0,
  });

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [
        ZenAmbientMeshBackground(intensity: meshIntensity),
        Scaffold(
          backgroundColor: Colors.transparent,
          extendBodyBehindAppBar: extendBodyBehindAppBar,
          extendBody: extendBody,
          resizeToAvoidBottomInset: resizeToAvoidBottomInset,
          appBar: appBar,
          body: body,
          bottomNavigationBar: bottomNavigationBar,
          floatingActionButton: floatingActionButton,
          floatingActionButtonLocation: floatingActionButtonLocation,
        ),
      ],
    );
  }
}

/// 8. Nút Bấm Kính Lỏng & Phát Quang (Zen Glass Button)
class ZenGlassButton extends StatelessWidget {
  final String label;
  final IconData? icon;
  final VoidCallback? onPressed;
  final bool isPrimary;
  final bool isDanger;
  final bool isLoading;
  final double borderRadius;
  final EdgeInsetsGeometry padding;
  final Color? accentColor;
  final double? width;
  final double? height;

  const ZenGlassButton({
    super.key,
    required this.label,
    this.icon,
    this.onPressed,
    this.isPrimary = true,
    this.isDanger = false,
    this.isLoading = false,
    this.borderRadius = 16.0,
    this.padding = const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
    this.accentColor,
    this.width,
    this.height,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final zen = context.zenColors;
    final Color baseColor = isDanger
        ? zen.danger
        : (accentColor ?? zen.primary);

    final Gradient? gradient = isPrimary
        ? (isDanger
            ? zen.dangerGradient
            : (accentColor != null
                ? LinearGradient(
                    colors: [
                      accentColor!,
                      Color.lerp(accentColor!, Colors.white, 0.18)!,
                    ],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  )
                : zen.brandHero))
        : null;

    final Color fgColor = isPrimary
        ? Colors.white
        : (isDanger
            ? zen.danger
            : (isDark ? AppColors.darkText : AppColors.lightText));

    return Opacity(
      opacity: onPressed == null && !isLoading ? 0.5 : 1.0,
      child: ZenLiquidGlass(
        width: width,
        height: height,
        borderRadius: borderRadius,
        padding: padding,
        blurSigma: 0,
        glowColor: isPrimary ? baseColor : null,
        surfaceColor: isPrimary
            ? baseColor.withOpacity(0.90)
            : (isDark
                ? Colors.white.withOpacity(0.08)
                : Colors.white.withOpacity(0.72)),
        customGradient: gradient,
        rimWidth: isPrimary ? 1.3 : 1.1,
        customShadows: isPrimary
            ? [
                BoxShadow(
                  color: baseColor.withOpacity(isDark ? 0.36 : 0.24),
                  blurRadius: 16,
                  offset: const Offset(0, 5),
                ),
              ]
            : [
                BoxShadow(
                  color: Colors.black.withOpacity(isDark ? 0.18 : 0.04),
                  blurRadius: 8,
                  offset: const Offset(0, 3),
                ),
              ],
        onTap: isLoading ? null : onPressed,
        alignment: (width != null || height != null) ? Alignment.center : null,
        child: Row(
          mainAxisSize: (width != null && width == double.infinity)
              ? MainAxisSize.max
              : MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            if (isLoading) ...[
              SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(
                  strokeWidth: 2.2,
                  color: fgColor,
                ),
              ),
              const SizedBox(width: 10),
            ] else if (icon != null) ...[
              Icon(icon, size: 18, color: fgColor),
              const SizedBox(width: 8),
            ],
            Flexible(
              child: Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: fgColor,
                  fontWeight: FontWeight.w700,
                  fontSize: 14.5,
                  letterSpacing: 0.1,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// 9. Input Decoration Kính Lỏng Đồng Bộ (Zen Glass Input Decoration)
InputDecoration zenGlassInputDecoration(
  BuildContext context, {
  String? labelText,
  String? hintText,
  String? helperText,
  String? errorText,
  IconData? prefixIcon,
  Widget? prefix,
  Widget? suffixIcon,
  EdgeInsetsGeometry? contentPadding,
  double borderRadius = 16.0,
  Color? accentColor,
}) {
  final isDark = Theme.of(context).brightness == Brightness.dark;
  final zen = context.zenColors;
  final focusColor = accentColor ?? zen.primary;

  return InputDecoration(
    labelText: labelText,
    hintText: hintText,
    helperText: helperText,
    errorText: errorText,
    labelStyle: TextStyle(
      color: isDark ? AppColors.darkTextMuted : AppColors.lightTextMuted,
      fontSize: 14,
    ),
    hintStyle: TextStyle(
      color: (isDark ? AppColors.darkTextMuted : AppColors.lightTextMuted)
          .withOpacity(0.75),
      fontSize: 14,
    ),
    prefixIcon: prefixIcon != null
        ? Icon(
            prefixIcon,
            size: 20,
            color: isDark ? zen.primaryAccent : zen.primary,
          )
        : prefix,
    suffixIcon: suffixIcon,
    filled: true,
    fillColor: isDark
        ? Colors.white.withOpacity(0.06)
        : Colors.white.withOpacity(0.68),
    contentPadding: contentPadding ??
        const EdgeInsets.symmetric(horizontal: 16, vertical: 15),
    enabledBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(borderRadius),
      borderSide: BorderSide(
        color: isDark
            ? Colors.white.withOpacity(0.14)
            : const Color(0xFFCBD5E1).withOpacity(0.75),
        width: 1.1,
      ),
    ),
    focusedBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(borderRadius),
      borderSide: BorderSide(
        color: focusColor,
        width: 1.6,
      ),
    ),
    errorBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(borderRadius),
      borderSide: BorderSide(
        color: zen.danger,
        width: 1.3,
      ),
    ),
    focusedErrorBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(borderRadius),
      borderSide: BorderSide(
        color: zen.danger,
        width: 1.6,
      ),
    ),
    disabledBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(borderRadius),
      borderSide: BorderSide(
        color: isDark
            ? Colors.white.withOpacity(0.07)
            : const Color(0xFFE2E8F0).withOpacity(0.6),
        width: 1.0,
      ),
    ),
  );
}

/// 10. Hộp Thoại Kính Lỏng Quang Học (Zen Glass Modal Dialog)
class ZenGlassDialogSurface extends StatelessWidget {
  final Widget child;
  final Color? accentColor;
  final double borderRadius;
  final EdgeInsetsGeometry padding;
  final double maxWidth;

  const ZenGlassDialogSurface({
    super.key,
    required this.child,
    this.accentColor,
    this.borderRadius = 28.0,
    this.padding = const EdgeInsets.fromLTRB(24, 24, 24, 20),
    this.maxWidth = 400.0,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final zen = context.zenColors;
    final glow = accentColor ?? zen.primary;

    return ConstrainedBox(
      constraints: BoxConstraints(maxWidth: maxWidth),
      child: ZenLiquidGlass(
        borderRadius: borderRadius,
        blurSigma: 24.0,
        glowColor: glow,
        rimWidth: 1.35,
        surfaceColor: isDark
            ? const Color(0xFF0C1426).withOpacity(0.74)
            : Colors.white.withOpacity(0.82),
        customShadows: [
          BoxShadow(
            color: glow.withOpacity(isDark ? 0.22 : 0.14),
            blurRadius: 32,
            offset: const Offset(0, 10),
          ),
          BoxShadow(
            color: Colors.black.withOpacity(isDark ? 0.55 : 0.14),
            blurRadius: 36,
            offset: const Offset(0, 14),
          ),
        ],
        child: Stack(
          children: [
            // Hào quang khúc xạ đỉnh hộp thoại
            Positioned(
              top: -48,
              right: -32,
              child: IgnorePointer(
                child: Container(
                  width: 150,
                  height: 150,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: RadialGradient(
                      colors: [
                        glow.withOpacity(isDark ? 0.26 : 0.18),
                        glow.withOpacity(0.0),
                      ],
                    ),
                  ),
                ),
              ),
            ),
            Padding(
              padding: padding,
              child: child,
            ),
          ],
        ),
      ),
    );
  }
}

Future<T?> showZenGlassDialog<T>({
  required BuildContext context,
  required WidgetBuilder builder,
  bool barrierDismissible = true,
  Color? accentColor,
  double borderRadius = 28.0,
  EdgeInsetsGeometry padding = const EdgeInsets.fromLTRB(24, 24, 24, 20),
  double maxWidth = 400.0,
}) {
  return showGeneralDialog<T>(
    context: context,
    barrierDismissible: barrierDismissible,
    barrierLabel: MaterialLocalizations.of(context).modalBarrierDismissLabel,
    barrierColor: Colors.black.withOpacity(0.56),
    transitionDuration: const Duration(milliseconds: 230),
    pageBuilder: (ctx, anim1, anim2) {
      return SafeArea(
        child: Center(
          child: Padding(
            padding: EdgeInsets.only(
              left: 20,
              right: 20,
              top: 16,
              bottom: 16 + MediaQuery.viewInsetsOf(ctx).bottom,
            ),
            child: Material(
              color: Colors.transparent,
              child: ZenGlassDialogSurface(
                accentColor: accentColor,
                borderRadius: borderRadius,
                padding: padding,
                maxWidth: maxWidth,
                child: builder(ctx),
              ),
            ),
          ),
        ),
      );
    },
    transitionBuilder: (ctx, anim, secondaryAnim, child) {
      final curved = CurvedAnimation(
        parent: anim,
        curve: Curves.easeOutBack,
        reverseCurve: Curves.easeInCubic,
      );
      return FadeTransition(
        opacity: CurvedAnimation(parent: anim, curve: Curves.easeOut),
        child: ScaleTransition(
          scale: Tween<double>(begin: 0.90, end: 1.0).animate(curved),
          child: child,
        ),
      );
    },
  );
}

/// 11. Thanh Menu Nổi Kính Lỏng (Zen Glass Popup Menu)
/// Thay thế PopupMenuButton phẳng truyền thống bằng Menu Kính Mờ Khúc Xạ 3D
class ZenGlassMenuOption<T> {
  final T value;
  final String label;
  final String? subtitle;
  final IconData? icon;
  final Color? color;
  final bool isDanger;
  final bool showDividerAbove;

  const ZenGlassMenuOption({
    required this.value,
    required this.label,
    this.subtitle,
    this.icon,
    this.color,
    this.isDanger = false,
    this.showDividerAbove = false,
  });
}

class ZenGlassPopupMenuButton<T> extends StatelessWidget {
  final List<ZenGlassMenuOption<T>> items;
  final ValueChanged<T> onSelected;
  final Widget? child;
  final IconData icon;
  final Color? iconColor;
  final double iconSize;
  final String? tooltip;

  const ZenGlassPopupMenuButton({
    super.key,
    required this.items,
    required this.onSelected,
    this.child,
    this.icon = Icons.more_vert_rounded,
    this.iconColor,
    this.iconSize = 20.0,
    this.tooltip,
  });

  Future<void> _openMenu(BuildContext context) async {
    HapticFeedback.selectionClick();
    final box = context.findRenderObject() as RenderBox?;
    final overlay =
        Overlay.of(context).context.findRenderObject() as RenderBox?;
    if (box == null || overlay == null) return;

    final targetGlobal = box.localToGlobal(Offset.zero, ancestor: overlay);
    final triggerRect = targetGlobal & box.size;

    final result = await Navigator.of(context).push<T>(
      _ZenGlassPopupRoute<T>(
        triggerRect: triggerRect,
        overlaySize: overlay.size,
        items: items,
      ),
    );

    if (result != null) {
      onSelected(result);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (child != null) {
      return GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () => _openMenu(context),
        child: child,
      );
    }
    return ZenGlassIconButton(
      icon: icon,
      iconSize: iconSize,
      iconColor: iconColor,
      tooltip: tooltip,
      size: 36,
      borderRadius: 12,
      blurSigma: 0,
      onTap: () => _openMenu(context),
    );
  }
}

class _ZenGlassPopupRoute<T> extends PopupRoute<T> {
  final Rect triggerRect;
  final Size overlaySize;
  final List<ZenGlassMenuOption<T>> items;

  _ZenGlassPopupRoute({
    required this.triggerRect,
    required this.overlaySize,
    required this.items,
  });

  @override
  Color? get barrierColor => Colors.black.withOpacity(0.18);

  @override
  bool get barrierDismissible => true;

  @override
  String? get barrierLabel => 'Dismiss menu';

  @override
  Duration get transitionDuration => const Duration(milliseconds: 190);

  @override
  Widget buildPage(
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
  ) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final zen = context.zenColors;
    const double menuWidth = 232.0;

    double left = triggerRect.right - menuWidth;
    if (left < 12) left = 12;
    if (left + menuWidth > overlaySize.width - 12) {
      left = overlaySize.width - menuWidth - 12;
    }

    final double estimatedHeight = items.length * 50.0 + 18.0;
    final bool openUpwards =
        triggerRect.bottom + estimatedHeight > overlaySize.height - 24 &&
            triggerRect.top > estimatedHeight;

    final double top = openUpwards
        ? (triggerRect.top - estimatedHeight - 6).clamp(16.0, overlaySize.height)
        : triggerRect.bottom + 6;

    final Alignment scaleOrigin = openUpwards
        ? Alignment.bottomRight
        : Alignment.topRight;

    return Stack(
      children: [
        Positioned(
          left: left,
          top: top,
          width: menuWidth,
          child: ScaleTransition(
            alignment: scaleOrigin,
            scale: CurvedAnimation(
              parent: animation,
              curve: Curves.easeOutBack,
            ),
            child: FadeTransition(
              opacity: CurvedAnimation(
                parent: animation,
                curve: Curves.easeOut,
              ),
              child: Material(
                color: Colors.transparent,
                child: ZenLiquidGlass(
                  borderRadius: 20,
                  blurSigma: 24,
                  rimWidth: 1.3,
                  padding: const EdgeInsets.symmetric(vertical: 6),
                  surfaceColor: isDark
                      ? const Color(0xFF0D1528).withOpacity(0.78)
                      : Colors.white.withOpacity(0.84),
                  customShadows: [
                    BoxShadow(
                      color: Colors.black.withOpacity(isDark ? 0.48 : 0.14),
                      blurRadius: 28,
                      offset: const Offset(0, 10),
                    ),
                  ],
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      for (final item in items) ...[
                        if (item.showDividerAbove)
                          Divider(
                            height: 8,
                            thickness: 1,
                            indent: 14,
                            endIndent: 14,
                            color: isDark
                                ? Colors.white.withOpacity(0.09)
                                : const Color(0xFFE2E8F0),
                          ),
                        InkWell(
                          onTap: () {
                            HapticFeedback.lightImpact();
                            Navigator.of(context).pop(item.value);
                          },
                          child: Padding(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 14,
                              vertical: 11,
                            ),
                            child: Row(
                              children: [
                                if (item.icon != null) ...[
                                  Container(
                                    width: 30,
                                    height: 30,
                                    decoration: BoxDecoration(
                                      color: (item.isDanger
                                              ? zen.danger
                                              : (item.color ?? zen.primary))
                                          .withOpacity(isDark ? 0.18 : 0.12),
                                      borderRadius: BorderRadius.circular(9),
                                    ),
                                    child: Icon(
                                      item.icon,
                                      size: 16.5,
                                      color: item.isDanger
                                          ? zen.danger
                                          : (item.color ??
                                              (isDark
                                                  ? zen.primaryAccent
                                                  : zen.primary)),
                                    ),
                                  ),
                                  const SizedBox(width: 11),
                                ],
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Text(
                                        item.label,
                                        style: TextStyle(
                                          fontSize: 14,
                                          fontWeight: FontWeight.w600,
                                          color: item.isDanger
                                              ? zen.danger
                                              : (item.color ??
                                                  (isDark
                                                      ? AppColors.darkText
                                                      : AppColors.lightText)),
                                        ),
                                      ),
                                      if (item.subtitle != null)
                                        Text(
                                          item.subtitle!,
                                          style: TextStyle(
                                            fontSize: 11.5,
                                            color: isDark
                                                ? AppColors.darkTextMuted
                                                : AppColors.lightTextMuted,
                                          ),
                                        ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

/// 12. Tiện ích hiển thị Bottom Sheet Kính Lỏng 2.0 (Zen Glass Bottom Sheet)
Future<T?> showZenGlassBottomSheet<T>({
  required BuildContext context,
  required WidgetBuilder builder,
  bool isScrollControlled = true,
  double maxHeightFactor = 0.88,
  Color? accentColor,
  bool padBottomForKeyboard = false,
  bool showHandle = true,
}) {
  final isDark = Theme.of(context).brightness == Brightness.dark;
  final zen = context.zenColors;
  final glow = accentColor ?? zen.primary;

  return showModalBottomSheet<T>(
    context: context,
    isScrollControlled: isScrollControlled,
    backgroundColor: Colors.transparent,
    barrierColor: Colors.black.withOpacity(0.56),
    elevation: 0,
    builder: (ctx) {
      final Color sheetSurface = isDark
          ? const Color(0xFF0C1426).withOpacity(0.78)
          : Colors.white.withOpacity(0.84);

      Widget sheet = ClipRRect(
        borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 26, sigmaY: 26),
          child: Container(
            constraints: BoxConstraints(
              maxHeight: MediaQuery.of(ctx).size.height * maxHeightFactor,
            ),
            decoration: BoxDecoration(
              color: sheetSurface,
              borderRadius:
                  const BorderRadius.vertical(top: Radius.circular(32)),
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: isDark
                    ? [
                        glow.withOpacity(0.10),
                        const Color(0xFF0C1426).withOpacity(0.78),
                      ]
                    : [
                        Colors.white.withOpacity(0.90),
                        Colors.white.withOpacity(0.80),
                      ],
              ),
              border: Border(
                top: BorderSide(
                  color: isDark
                      ? Colors.white.withOpacity(0.24)
                      : Colors.white.withOpacity(0.95),
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
                  color: glow.withOpacity(isDark ? 0.16 : 0.08),
                  blurRadius: 30,
                  offset: const Offset(0, -6),
                ),
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
                if (showHandle)
                  Center(
                    child: Container(
                      margin: const EdgeInsets.only(top: 12, bottom: 8),
                      width: 44,
                      height: 5,
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [
                            (isDark ? Colors.white : Colors.black)
                                .withOpacity(0.16),
                            (isDark ? Colors.white : Colors.black)
                                .withOpacity(0.32),
                            (isDark ? Colors.white : Colors.black)
                                .withOpacity(0.16),
                          ],
                        ),
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

      if (padBottomForKeyboard) {
        sheet = AnimatedPadding(
          duration: const Duration(milliseconds: 160),
          curve: Curves.easeOut,
          padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(ctx).bottom),
          child: sheet,
        );
      }

      return sheet;
    },
  );
}

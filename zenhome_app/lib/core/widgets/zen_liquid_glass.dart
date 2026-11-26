import 'dart:math' as math;
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../theme/app_theme.dart';

/// ============================================================================
/// HỆ THỐNG GIAO DIỆN KÍNH LỎNG QUANG HỌC 2.0 (ZEN LIQUID GLASS 2.0 ENGINE)
/// Soft Luxury Translucent Glass + 120Hz Hybrid Architecture
/// ============================================================================

/// Shared bottom scroll clearance for pages sitting above MainLayout's floating dock.
double zenBottomNavClearance(BuildContext context) =>
    MediaQuery.paddingOf(context).bottom + 104.0;

/// Rendering tier for Zen glass surfaces.
enum ZenGlassSurfaceMode {
  /// Single-pass live BackdropFilter (capped sigma 10-14).
  /// Reserved strictly for static overlays: bottom dock, pinned AppBar,
  /// pinned SegmentedBar, Dialogs, BottomSheets, LoadingOverlay, FloatingToast.
  frostedBlur,

  /// Zero-blur translucent frosted tint (blurSigma = 0.0, 120fps).
  /// Mandatory for all scrolling cards, GridView/ListView items, PageViews,
  /// RoomTabs, and elements nested inside frostedBlur parents.
  tintedGlass,

  /// Crisp elevated surface (blurSigma = 0.0) for dense inputs & pickers.
  solidElevated,
}

/// Painter rendering a single restrained hairline rim (no harsh double top glare).
class _ZenSpecularRimPainter extends CustomPainter {
  final double borderRadius;
  final double strokeWidth;
  final bool isDark;
  final Color? glowColor;
  final bool drawFullRim;
  final bool enableTopSheen;

  const _ZenSpecularRimPainter({
    required this.borderRadius,
    required this.strokeWidth,
    required this.isDark,
    this.glowColor,
    this.drawFullRim = true,
    this.enableTopSheen = false,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (size.isEmpty) return;

    final effectiveStroke = strokeWidth.clamp(0.7, 0.85);
    final rect = Offset.zero & size;
    final rrect = RRect.fromRectAndRadius(
      rect.deflate(effectiveStroke / 2),
      Radius.circular(math.max(0, borderRadius - effectiveStroke / 2)),
    );

    if (drawFullRim) {
      const Color lightNeutral = Color(0xFF94A3B8);

      final Color topLeftHighlight = isDark
          ? (glowColor != null
              ? Color.lerp(Colors.white, glowColor!, 0.25)!
                  .withValues(alpha: 0.14)
              : Colors.white.withValues(alpha: 0.13))
          : (glowColor != null
              ? Color.lerp(lightNeutral, glowColor!, 0.35)!
                  .withValues(alpha: 0.14)
              : Color.lerp(Colors.white, lightNeutral, 0.35)!
                  .withValues(alpha: 0.14));

      final Color midEdge = isDark
          ? (glowColor != null
              ? Color.lerp(Colors.white, glowColor!, 0.15)!
                  .withValues(alpha: 0.08)
              : Colors.white.withValues(alpha: 0.08))
          : (glowColor != null
              ? Color.lerp(lightNeutral, glowColor!, 0.20)!
                  .withValues(alpha: 0.10)
              : lightNeutral.withValues(alpha: 0.10));

      final Color bottomRightCaustic = isDark
          ? (glowColor != null
              ? Color.lerp(Colors.white, glowColor!, 0.08)!
                  .withValues(alpha: 0.03)
              : Colors.white.withValues(alpha: 0.03))
          : (glowColor != null
              ? Color.lerp(lightNeutral, glowColor!, 0.10)!
                  .withValues(alpha: 0.07)
              : lightNeutral.withValues(alpha: 0.07));

      final rimPaint = Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = effectiveStroke
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

    if (enableTopSheen && size.width > 28 && size.height > 20) {
      final sheenInset = effectiveStroke + 0.5;
      final sheenWidth =
          (size.width - borderRadius * 1.4).clamp(12.0, size.width);
      final sheenLeft = (size.width - sheenWidth) / 2;
      final sheenRect = Rect.fromLTWH(sheenLeft, sheenInset, sheenWidth, 1.0);

      final sheenPaint = Paint()
        ..shader = LinearGradient(
          colors: [
            Colors.white.withValues(alpha: 0.0),
            Colors.white.withValues(alpha: isDark ? 0.05 : 0.10),
            Colors.white.withValues(alpha: 0.0),
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
        oldDelegate.drawFullRim != drawFullRim ||
        oldDelegate.enableTopSheen != enableTopSheen;
  }
}

/// 0. Ambient Refractive Aurora Mesh Background
/// Static by default (animate: false) so static BackdropFilters can reuse cached
/// GPU backdrop textures without 120Hz full-screen re-blurring.
class ZenAmbientMeshBackground extends StatefulWidget {
  final Widget? child;
  final double intensity;
  final bool animate;

  const ZenAmbientMeshBackground({
    super.key,
    this.child,
    this.intensity = 1.0,
    this.animate = false,
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
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _syncMotion();
  }

  @override
  void didUpdateWidget(covariant ZenAmbientMeshBackground oldWidget) {
    super.didUpdateWidget(oldWidget);
    _syncMotion();
  }

  void _syncMotion() {
    final animate = widget.animate &&
        !(MediaQuery.maybeDisableAnimationsOf(context) ?? false) &&
        TickerMode.of(context);
    if (animate && !_controller.isAnimating) {
      _controller.repeat(reverse: true);
    } else if (!animate) {
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
    final bool shouldAnimate = widget.animate && !disableMotion;

    final Widget meshLayer = RepaintBoundary(
      child: IgnorePointer(
        child: shouldAnimate
            ? AnimatedBuilder(
                animation: _controller,
                builder: (context, _) {
                  return CustomPaint(
                    painter: _ZenAuroraMeshPainter(
                      progress: _controller.value,
                      isDark: isDark,
                      primary: zen.primary,
                      accent: zen.primaryAccent,
                      intensity: widget.intensity,
                    ),
                    size: Size.infinite,
                  );
                },
              )
            : CustomPaint(
                painter: _ZenAuroraMeshPainter(
                  progress: 0.35,
                  isDark: isDark,
                  primary: zen.primary,
                  accent: zen.primaryAccent,
                  intensity: widget.intensity,
                ),
                size: Size.infinite,
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

    final bgRect = Offset.zero & size;
    _reusableBasePaint.shader = LinearGradient(
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
      colors: isDark
          ? const [
              Color(0xFF060911),
              Color(0xFF0B101E),
              Color(0xFF080D18),
            ]
          : const [
              Color(0xFFF4F7FB),
              Color(0xFFEEF3F9),
              Color(0xFFF8FAFC),
            ],
    ).createShader(bgRect);
    canvas.drawRect(bgRect, _reusableBasePaint);

    final double shortest = size.shortestSide;
    final double phase = progress * math.pi;

    final Offset orb1Center = Offset(
      size.width * (0.16 + 0.12 * math.sin(phase)),
      size.height * (0.12 + 0.06 * math.cos(phase)),
    );
    _drawOrb(
      canvas,
      center: orb1Center,
      radius: shortest * 0.78,
      color: primary,
      opacity: (isDark ? 0.085 : 0.060) * intensity,
    );

    final Color secondaryHue =
        Color.lerp(accent, const Color(0xFF0EA5E9), isDark ? 0.35 : 0.25)!;
    final Offset orb2Center = Offset(
      size.width * (0.88 - 0.10 * math.cos(phase)),
      size.height * (0.42 + 0.08 * math.sin(phase * 0.8)),
    );
    _drawOrb(
      canvas,
      center: orb2Center,
      radius: shortest * 0.72,
      color: secondaryHue,
      opacity: (isDark ? 0.068 : 0.048) * intensity,
    );

    final Color tertiaryHue =
        Color.lerp(accent, const Color(0xFF0284C7), 0.35)!;
    final Offset orb3Center = Offset(
      size.width * (0.25 + 0.14 * math.cos(phase * 0.7)),
      size.height * (0.84 - 0.06 * math.sin(phase)),
    );
    _drawOrb(
      canvas,
      center: orb3Center,
      radius: shortest * 0.76,
      color: tertiaryHue,
      opacity: (isDark ? 0.060 : 0.045) * intensity,
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
        color.withValues(alpha: opacity.clamp(0.0, 1.0)),
        color.withValues(alpha: (opacity * 0.38).clamp(0.0, 1.0)),
        color.withValues(alpha: 0.0),
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

/// 1. Core Soft Translucent Glass Component (ZenLiquidGlass 2.0)
/// Preserves true surfaceColor RGB by baking surfaceColor into gradient stops
/// rather than passing both color and gradient to BoxDecoration.
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
  final bool isLightweight;
  final ZenGlassSurfaceMode? surfaceMode;
  final bool enableTopSheen;

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
    this.blurSigma = 10.0,
    this.customBorder,
    this.customGradient,
    this.customShadows,
    this.onTap,
    this.onLongPress,
    this.enableSpecularRim = true,
    this.rimWidth = 0.8,
    this.isLightweight = false,
    this.surfaceMode,
    this.enableTopSheen = false,
  });

  /// Zero-blur translucent glass for 120fps scrolling lists and grids.
  const ZenLiquidGlass.lightweight({
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
    this.customBorder,
    this.customGradient,
    this.customShadows,
    this.onTap,
    this.onLongPress,
    this.enableSpecularRim = true,
    this.rimWidth = 0.8,
    this.enableTopSheen = false,
  })  : isLightweight = true,
        blurSigma = 0.0,
        surfaceMode = ZenGlassSurfaceMode.tintedGlass;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final ZenGlassSurfaceMode effectiveMode = surfaceMode ??
        ((isLightweight || blurSigma <= 0)
            ? ZenGlassSurfaceMode.tintedGlass
            : ZenGlassSurfaceMode.frostedBlur);
    final double effectiveBlur = effectiveMode == ZenGlassSurfaceMode.frostedBlur
        ? (blurSigma > 0 ? blurSigma.clamp(0.0, 14.0) : 10.0)
        : 0.0;

    final Color effectiveSurface = surfaceColor ??
        (effectiveMode == ZenGlassSurfaceMode.solidElevated
            ? (isDark
                ? const Color(0xFF141C2E).withValues(alpha: 0.92)
                : Colors.white.withValues(alpha: 0.94))
            : effectiveMode == ZenGlassSurfaceMode.tintedGlass
                ? (isDark
                    ? const Color(0xFF11192C).withValues(alpha: 0.54)
                    : Colors.white.withValues(alpha: 0.60))
                : (isDark
                    ? const Color(0xFF0E1525).withValues(alpha: 0.58)
                    : Colors.white.withValues(alpha: 0.62)));

    final effectiveShadows = customShadows ?? [
      if (effectiveBlur > 0)
        BoxShadow(
          color: Colors.black.withValues(alpha: isDark ? 0.16 : 0.05),
          blurRadius: 12,
          offset: const Offset(0, 3),
        ),
    ];

    final Gradient effectiveGradient;
    if (customGradient != null) {
      effectiveGradient = customGradient!;
    } else {
      final Color topTint = isDark
          ? Color.lerp(effectiveSurface, Colors.white, 0.04)!
          : Color.lerp(effectiveSurface, Colors.white, 0.12)!;
      final Color bottomTint = glowColor != null
          ? Color.lerp(effectiveSurface, glowColor!, isDark ? 0.05 : 0.03)!
          : effectiveSurface;
      effectiveGradient = LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        stops: const [0.0, 0.50, 1.0],
        colors: [topTint, effectiveSurface, bottomTint],
      );
    }

    Widget body = Container(
      width: width,
      height: height,
      alignment: alignment,
      padding: padding,
      decoration: BoxDecoration(
        color: null,
        borderRadius: BorderRadius.circular(borderRadius),
        border: customBorder,
        gradient: effectiveGradient,
      ),
      child: child,
    );

    if (enableSpecularRim && (customBorder == null || enableTopSheen)) {
      body = CustomPaint(
        foregroundPainter: _ZenSpecularRimPainter(
          borderRadius: borderRadius,
          strokeWidth: rimWidth,
          isDark: isDark,
          glowColor: glowColor,
          drawFullRim: customBorder == null,
          enableTopSheen: enableTopSheen,
        ),
        child: body,
      );
    }

    if (effectiveBlur > 0) {
      body = BackdropFilter(
        filter: ImageFilter.blur(sigmaX: effectiveBlur, sigmaY: effectiveBlur),
        child: body,
      );
    }

    final Widget glassContainer = Container(
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
              .withValues(alpha: isDark ? 0.12 : 0.07),
          highlightColor: Colors.white.withValues(alpha: isDark ? 0.03 : 0.08),
          onTap: onTap,
          onLongPress: onLongPress,
          child: glassContainer,
        ),
      );
    }

    return glassContainer;
  }
}

/// 2. Zen Glass Card 2.0 (defaults to zero-blur tintedGlass for 120fps safety).
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
  final bool isLightweight;
  final ZenGlassSurfaceMode? surfaceMode;

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
    this.blurSigma = 0.0,
    this.border,
    this.onTap,
    this.onLongPress,
    this.isLightweight = false,
    this.surfaceMode,
  });

  const ZenGlassCard.lightweight({
    super.key,
    required this.child,
    this.borderRadius = 24.0,
    this.padding = const EdgeInsets.all(16.0),
    this.margin,
    this.width,
    this.height,
    this.glowColor,
    this.isActive = false,
    this.border,
    this.onTap,
    this.onLongPress,
  })  : isLightweight = true,
        blurSigma = 0.0,
        surfaceMode = ZenGlassSurfaceMode.tintedGlass;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final zen = context.zenColors;
    final ZenGlassSurfaceMode effectiveMode = surfaceMode ??
        ((isLightweight || blurSigma <= 0)
            ? ZenGlassSurfaceMode.tintedGlass
            : ZenGlassSurfaceMode.frostedBlur);
    final double effectiveBlur = effectiveMode == ZenGlassSurfaceMode.frostedBlur
        ? (blurSigma > 0 ? blurSigma.clamp(0.0, 14.0) : 10.0)
        : 0.0;

    final Color effectiveGlow =
        glowColor ?? (isDark ? zen.primaryAccent : zen.primary);

    final Color surfaceStart;
    final Color surfaceEnd;
    if (isActive) {
      if (isDark) {
        final base = Color.lerp(const Color(0xFF131D33), effectiveGlow, 0.09)!;
        surfaceStart = base.withValues(alpha: 0.60);
        surfaceEnd = base.withValues(alpha: 0.48);
      } else {
        final base = Color.lerp(Colors.white, effectiveGlow, 0.05)!;
        surfaceStart = base.withValues(alpha: 0.66);
        surfaceEnd = base.withValues(alpha: 0.56);
      }
    } else {
      if (isDark) {
        surfaceStart = const Color(0xFF11192C).withValues(alpha: 0.54);
        surfaceEnd = const Color(0xFF11192C).withValues(alpha: 0.44);
      } else {
        surfaceStart = Colors.white.withValues(alpha: 0.60);
        surfaceEnd = Colors.white.withValues(alpha: 0.52);
      }
    }

    final Gradient gradient = LinearGradient(
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
      colors: [surfaceStart, surfaceEnd],
    );

    return ZenLiquidGlass(
      borderRadius: borderRadius,
      padding: padding,
      margin: margin,
      width: width,
      height: height,
      surfaceColor: surfaceStart,
      glowColor: isActive ? effectiveGlow : null,
      blurSigma: effectiveBlur,
      isLightweight: effectiveMode != ZenGlassSurfaceMode.frostedBlur,
      surfaceMode: effectiveMode,
      customBorder: border,
      rimWidth: 0.8,
      enableTopSheen: false,
      customGradient: gradient,
      onTap: onTap,
      onLongPress: onLongPress,
      child: child,
    );
  }
}

/// 3. Zen Glass Pill 2.0 (zero-blur tintedGlass by default for 120fps lists).
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
  final bool isLightweight;
  final ZenGlassSurfaceMode? surfaceMode;

  const ZenGlassPill({
    super.key,
    required this.child,
    this.borderRadius = 22.0,
    this.padding = const EdgeInsets.symmetric(horizontal: 14.0, vertical: 7.0),
    this.margin,
    this.color,
    this.glowColor,
    this.isSelected = false,
    this.blurSigma = 0.0,
    this.customGradient,
    this.onTap,
    this.isLightweight = false,
    this.surfaceMode,
  });

  const ZenGlassPill.lightweight({
    super.key,
    required this.child,
    this.borderRadius = 22.0,
    this.padding = const EdgeInsets.symmetric(horizontal: 14.0, vertical: 7.0),
    this.margin,
    this.color,
    this.glowColor,
    this.isSelected = false,
    this.customGradient,
    this.onTap,
  })  : isLightweight = true,
        blurSigma = 0.0,
        surfaceMode = ZenGlassSurfaceMode.tintedGlass;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final zen = context.zenColors;
    final Color activeColor = glowColor ?? color ?? zen.primary;
    final ZenGlassSurfaceMode effectiveMode = surfaceMode ??
        ((isLightweight || blurSigma <= 0)
            ? ZenGlassSurfaceMode.tintedGlass
            : ZenGlassSurfaceMode.frostedBlur);
    final double effectiveBlur = effectiveMode == ZenGlassSurfaceMode.frostedBlur
        ? (blurSigma > 0 ? blurSigma.clamp(0.0, 14.0) : 10.0)
        : 0.0;

    final Color surface = isSelected
        ? activeColor.withValues(alpha: isDark ? 0.20 : 0.12)
        : (isDark
            ? const Color(0xFF11192C).withValues(alpha: 0.54)
            : Colors.white.withValues(alpha: 0.60));

    return ZenLiquidGlass(
      borderRadius: borderRadius,
      padding: padding,
      margin: margin,
      surfaceColor: customGradient != null && isSelected ? null : surface,
      customGradient: customGradient,
      glowColor: isSelected ? activeColor : null,
      blurSigma: effectiveBlur,
      isLightweight: effectiveMode != ZenGlassSurfaceMode.frostedBlur,
      surfaceMode: effectiveMode,
      rimWidth: 0.8,
      enableTopSheen: false,
      onTap: onTap,
      child: child,
    );
  }
}

/// 4. Zen Glass Floating Container 2.0 (for static Bottom Navigation Dock / Segmented Bars).
class ZenGlassContainer extends StatelessWidget {
  final Widget child;
  final double borderRadius;
  final EdgeInsetsGeometry padding;
  final EdgeInsetsGeometry margin;
  final Color? glowColor;
  final double blurSigma;
  final bool isLightweight;
  final ZenGlassSurfaceMode? surfaceMode;

  const ZenGlassContainer({
    super.key,
    required this.child,
    this.borderRadius = 32.0,
    this.padding = const EdgeInsets.symmetric(horizontal: 10.0, vertical: 8.0),
    this.margin = const EdgeInsets.symmetric(horizontal: 18.0, vertical: 16.0),
    this.glowColor,
    this.blurSigma = 10.0,
    this.isLightweight = false,
    this.surfaceMode,
  });

  const ZenGlassContainer.lightweight({
    super.key,
    required this.child,
    this.borderRadius = 32.0,
    this.padding = const EdgeInsets.symmetric(horizontal: 10.0, vertical: 8.0),
    this.margin = const EdgeInsets.symmetric(horizontal: 18.0, vertical: 16.0),
    this.glowColor,
  })  : isLightweight = true,
        blurSigma = 0.0,
        surfaceMode = ZenGlassSurfaceMode.tintedGlass;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final ZenGlassSurfaceMode effectiveMode = surfaceMode ??
        ((isLightweight || blurSigma <= 0)
            ? ZenGlassSurfaceMode.tintedGlass
            : ZenGlassSurfaceMode.frostedBlur);
    final double effectiveBlur = effectiveMode == ZenGlassSurfaceMode.frostedBlur
        ? (blurSigma > 0 ? blurSigma.clamp(0.0, 14.0) : 10.0)
        : 0.0;

    final Gradient gradient = LinearGradient(
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
      colors: isDark
          ? [
              const Color(0xFF0E1525).withValues(alpha: 0.58),
              const Color(0xFF0E1525).withValues(alpha: 0.48),
            ]
          : [
              Colors.white.withValues(alpha: 0.62),
              Colors.white.withValues(alpha: 0.54),
            ],
    );

    return ZenLiquidGlass(
      borderRadius: borderRadius,
      padding: padding,
      margin: margin,
      customGradient: gradient,
      glowColor: glowColor,
      blurSigma: effectiveBlur,
      isLightweight: effectiveMode != ZenGlassSurfaceMode.frostedBlur,
      surfaceMode: effectiveMode,
      rimWidth: 0.8,
      enableTopSheen: false,
      child: child,
    );
  }
}

/// ============================================================================
/// UNIFIED ZEN GLASS MENUS
/// ============================================================================

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

/// 4b. Zen Glass Segmented Bar 2.0 (Single-pass frostedBlur, zero overshoot).
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
  final ZenGlassSurfaceMode surfaceMode;
  final Curve slideCurve;
  final Duration slideDuration;

  const ZenGlassSegmentedBar({
    super.key,
    required this.items,
    required this.selectedValue,
    required this.onValueChanged,
    this.height = 46.0,
    this.borderRadius = 28.0,
    this.margin = const EdgeInsets.symmetric(horizontal: 0.0, vertical: 6.0),
    this.padding = const EdgeInsets.all(4.0),
    this.blurSigma = 10.0,
    this.glowColor,
    this.activeGradient,
    this.surfaceMode = ZenGlassSurfaceMode.frostedBlur,
    this.slideCurve = Curves.easeOutCubic,
    this.slideDuration = const Duration(milliseconds: 240),
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
        blurSigma: surfaceMode == ZenGlassSurfaceMode.frostedBlur
            ? blurSigma.clamp(0.0, 14.0)
            : 0.0,
        surfaceMode: surfaceMode,
        glowColor: effectiveGlow,
        child: ConstrainedBox(
          constraints: BoxConstraints(minHeight: height),
          child: LayoutBuilder(
            builder: (context, constraints) {
              final double totalWidth = constraints.maxWidth;
              final int count = items.length;
              if (count == 0) return const SizedBox.shrink();

              final double itemWidth = totalWidth / count;
              final double pillLeft =
                  selectedIndex >= 0 ? selectedIndex * itemWidth : 0.0;
              final bool isCompact = itemWidth < 145.0;

              return Stack(
                alignment: Alignment.center,
                children: [
                  if (selectedIndex >= 0)
                    AnimatedPositioned(
                      duration: slideDuration,
                      curve: slideCurve,
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
                            color: isDark
                                ? Colors.white.withValues(alpha: 0.14)
                                : effectiveGlow.withValues(alpha: 0.14),
                            width: 0.8,
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: effectiveGlow.withValues(
                                alpha: isDark ? 0.14 : 0.08,
                              ),
                              blurRadius: 10,
                              spreadRadius: 0,
                              offset: const Offset(0, 2),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ConstrainedBox(
                    constraints: BoxConstraints(minHeight: height),
                    child: Row(
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
                              splashColor:
                                  effectiveGlow.withValues(alpha: 0.12),
                              highlightColor: Colors.transparent,
                              onTap: () {
                                HapticFeedback.selectionClick();
                                if (item.value != selectedValue) {
                                  onValueChanged(item.value);
                                }
                              },
                              child: Center(
                                child: Padding(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 6,
                                    vertical: 8,
                                  ),
                                  child: item.customWidget ??
                                      Row(
                                        mainAxisAlignment:
                                            MainAxisAlignment.center,
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          if (item.icon != null) ...[
                                            AnimatedScale(
                                              scale: isSelected ? 1.05 : 1.0,
                                              duration: const Duration(
                                                milliseconds: 220,
                                              ),
                                              curve: Curves.easeOutCubic,
                                              child: Icon(
                                                item.icon,
                                                size: isCompact ? 15.5 : 17.5,
                                                color: isSelected
                                                    ? activeTextColor
                                                    : inactiveTextColor,
                                              ),
                                            ),
                                            SizedBox(
                                              width: isCompact ? 4.0 : 6.0,
                                            ),
                                          ],
                                          Flexible(
                                            child: AnimatedDefaultTextStyle(
                                              duration: const Duration(
                                                milliseconds: 220,
                                              ),
                                              curve: Curves.easeOutCubic,
                                              style: TextStyle(
                                                fontSize:
                                                    isCompact ? 12.2 : 13.0,
                                                fontWeight: isSelected
                                                    ? FontWeight.w800
                                                    : FontWeight.w600,
                                                color: isSelected
                                                    ? activeTextColor
                                                    : inactiveTextColor,
                                                letterSpacing: 0.15,
                                              ),
                                              child: Text(
                                                item.label,
                                                maxLines: 1,
                                                overflow: TextOverflow.ellipsis,
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                ),
                              ),
                            ),
                          ),
                        );
                      }).toList(),
                    ),
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

/// 4c. Zen Glass Scrollable Filter Bar 2.0 (zero-blur pills for 120fps).
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
    this.blurSigma = 10.0,
    this.showOuterContainer = false,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final zen = context.zenColors;
    final double adaptiveHeight = math.max(
      height,
      34.0 + MediaQuery.textScalerOf(context).scale(14.0),
    );

    final Widget listView = SizedBox(
      height: adaptiveHeight,
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

          final LinearGradient activeGradient = item.color != null
              ? LinearGradient(
                  colors: [
                    item.color!,
                    Color.lerp(item.color!, Colors.black, 0.10)!,
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
              child: ZenGlassPill.lightweight(
                isSelected: isSelected,
                glowColor: itemColor,
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
                        scale: isSelected ? 1.06 : 1.0,
                        duration: const Duration(milliseconds: 200),
                        curve: Curves.easeOutCubic,
                        child: Icon(
                          item.icon,
                          size: 16,
                          color: isSelected
                              ? Colors.white
                              : (isDark
                                  ? itemColor.withValues(alpha: 0.92)
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
                      child: Text(
                        item.label,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
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
                              ? Colors.white.withValues(alpha: 0.24)
                              : itemColor.withValues(alpha: 0.16),
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
          blurSigma: blurSigma.clamp(0.0, 14.0),
          child: listView,
        ),
      );
    }

    return RepaintBoundary(child: listView);
  }
}

/// 5. Zen Glass Icon Button (defaults to zero-blur tintedGlass).
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
  final bool isLightweight;
  final ZenGlassSurfaceMode? surfaceMode;

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
    this.blurSigma = 0.0,
    this.isLightweight = false,
    this.surfaceMode,
  });

  const ZenGlassIconButton.lightweight({
    super.key,
    required this.icon,
    this.onTap,
    this.size = 40.0,
    this.iconSize = 20.0,
    this.borderRadius = 14.0,
    this.iconColor,
    this.glowColor,
    this.tooltip,
  })  : isLightweight = true,
        blurSigma = 0.0,
        surfaceMode = ZenGlassSurfaceMode.tintedGlass;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final effectiveIconColor =
        iconColor ?? (isDark ? AppColors.darkText : AppColors.lightText);
    final ZenGlassSurfaceMode effectiveMode = surfaceMode ??
        ((isLightweight || blurSigma <= 0)
            ? ZenGlassSurfaceMode.tintedGlass
            : ZenGlassSurfaceMode.frostedBlur);
    final double effectiveBlur = effectiveMode == ZenGlassSurfaceMode.frostedBlur
        ? (blurSigma > 0 ? blurSigma.clamp(0.0, 14.0) : 10.0)
        : 0.0;

    Widget btn = ZenLiquidGlass(
      width: size,
      height: size,
      borderRadius: borderRadius,
      blurSigma: effectiveBlur,
      isLightweight: effectiveMode != ZenGlassSurfaceMode.frostedBlur,
      surfaceMode: effectiveMode,
      glowColor: glowColor,
      rimWidth: 0.8,
      enableTopSheen: false,
      surfaceColor: isDark
          ? const Color(0xFF11192C).withValues(alpha: 0.54)
          : Colors.white.withValues(alpha: 0.62),
      customShadows: [
        BoxShadow(
          color: Colors.black.withValues(alpha: isDark ? 0.16 : 0.03),
          blurRadius: 8,
          offset: const Offset(0, 2),
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

/// 6. Zen Glass AppBar (pinned single-pass blur capped at 10-14).
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
    this.blurSigma = 10.0,
  });

  @override
  Size get preferredSize => Size.fromHeight(
        toolbarHeight + (bottom?.preferredSize.height ?? 0.0),
      );

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final canPop = ModalRoute.of(context)?.canPop ?? false;
    final double cappedBlur = blurSigma.clamp(0.0, 14.0);

    Widget? effectiveLeading = leading;
    if (effectiveLeading == null && automaticallyImplyLeading && canPop) {
      effectiveLeading = Center(
        child: Padding(
          padding: const EdgeInsets.only(left: 12),
          child: ZenGlassIconButton.lightweight(
            icon: Icons.arrow_back_ios_new_rounded,
            size: 38,
            iconSize: 17,
            onTap: onBack ?? () => Navigator.of(context).maybePop(),
          ),
        ),
      );
    }

    final Widget? effectiveTitle = title ??
        (titleText != null
            ? Text(
                titleText!,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 19,
                  fontWeight: FontWeight.w800,
                  letterSpacing: -0.3,
                  color: isDark ? AppColors.darkText : AppColors.lightText,
                ),
              )
            : null);

    final Widget appBarBody = Container(
      decoration: BoxDecoration(
        color: isDark
            ? const Color(0xFF0B101E).withValues(alpha: 0.56)
            : Colors.white.withValues(alpha: 0.68),
        border: Border(
          bottom: BorderSide(
            color: isDark
                ? Colors.white.withValues(alpha: 0.10)
                : const Color(0xFF94A3B8).withValues(alpha: 0.18),
            width: 0.8,
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
    );

    if (cappedBlur <= 0) {
      return appBarBody;
    }

    return ClipRect(
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: cappedBlur, sigmaY: cappedBlur),
        child: appBarBody,
      ),
    );
  }
}

/// 7. Zen Glass Scaffold
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
  final bool animateMesh;

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
    this.animateMesh = false,
  });

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [
        ZenAmbientMeshBackground(
          intensity: meshIntensity,
          animate: animateMesh,
        ),
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

/// 8. Zen Glass Button (no white specular glare on primary solid buttons).
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
  final bool isLightweight;
  final int maxLines;
  final TextAlign textAlign;
  final ZenGlassSurfaceMode? surfaceMode;

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
    this.isLightweight = true,
    this.maxLines = 1,
    this.textAlign = TextAlign.center,
    this.surfaceMode,
  });

  const ZenGlassButton.lightweight({
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
    this.maxLines = 1,
    this.textAlign = TextAlign.center,
  })  : isLightweight = true,
        surfaceMode = ZenGlassSurfaceMode.tintedGlass;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final zen = context.zenColors;
    final Color baseColor =
        isDanger ? zen.danger : (accentColor ?? zen.primary);
    final ZenGlassSurfaceMode effectiveMode = surfaceMode ??
        (isLightweight
            ? ZenGlassSurfaceMode.tintedGlass
            : ZenGlassSurfaceMode.frostedBlur);

    final Gradient? gradient = isPrimary
        ? (isDanger
            ? zen.dangerGradient
            : (accentColor != null
                ? LinearGradient(
                    colors: [
                      accentColor!,
                      Color.lerp(accentColor!, Colors.black, 0.10)!,
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

    final bool flexibleMultiLine = maxLines > 1 && height != null;

    Widget buttonGlass = ZenLiquidGlass(
      width: width,
      height: flexibleMultiLine ? null : height,
      borderRadius: borderRadius,
      padding: padding,
      blurSigma:
          effectiveMode == ZenGlassSurfaceMode.frostedBlur ? 10.0 : 0.0,
      isLightweight: effectiveMode != ZenGlassSurfaceMode.frostedBlur,
      surfaceMode: effectiveMode,
      enableSpecularRim: !isPrimary,
      enableTopSheen: false,
      glowColor: isPrimary ? baseColor : null,
      surfaceColor: isPrimary
          ? baseColor
          : (isDark
              ? const Color(0xFF11192C).withValues(alpha: 0.50)
              : Colors.white.withValues(alpha: 0.60)),
      customGradient: gradient,
      rimWidth: 0.8,
      customShadows: isPrimary
          ? [
              BoxShadow(
                color: baseColor.withValues(alpha: isDark ? 0.18 : 0.12),
                blurRadius: 10,
                offset: const Offset(0, 3),
              ),
            ]
          : [
              BoxShadow(
                color: Colors.black.withValues(alpha: isDark ? 0.14 : 0.03),
                blurRadius: 8,
                offset: const Offset(0, 2),
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
              maxLines: maxLines,
              overflow: TextOverflow.ellipsis,
              textAlign: textAlign,
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
    );

    if (flexibleMultiLine) {
      buttonGlass = ConstrainedBox(
        constraints: BoxConstraints(minHeight: height!),
        child: buttonGlass,
      );
    }

    return Opacity(
      opacity: onPressed == null && !isLoading ? 0.5 : 1.0,
      child: buttonGlass,
    );
  }
}

/// 9. Zen Glass Input Decoration
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
    errorMaxLines: 4,
    labelStyle: TextStyle(
      color: isDark ? AppColors.darkTextMuted : AppColors.lightTextMuted,
      fontSize: 14,
      fontWeight: FontWeight.w500,
    ),
    hintStyle: TextStyle(
      color: (isDark ? AppColors.darkTextMuted : AppColors.lightTextMuted)
          .withValues(alpha: 0.85),
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
        ? const Color(0xFF11192C).withValues(alpha: 0.45)
        : Colors.white.withValues(alpha: 0.66),
    contentPadding: contentPadding ??
        const EdgeInsets.symmetric(horizontal: 16, vertical: 15),
    enabledBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(borderRadius),
      borderSide: BorderSide(
        color: isDark
            ? Colors.white.withValues(alpha: 0.12)
            : const Color(0xFF94A3B8).withValues(alpha: 0.28),
        width: 1.0,
      ),
    ),
    focusedBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(borderRadius),
      borderSide: BorderSide(
        color: focusColor,
        width: 1.5,
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
        width: 1.5,
      ),
    ),
    disabledBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(borderRadius),
      borderSide: BorderSide(
        color: isDark
            ? Colors.white.withValues(alpha: 0.07)
            : const Color(0xFFE2E8F0).withValues(alpha: 0.6),
        width: 1.0,
      ),
    ),
  );
}

/// 10. Zen Glass Modal Dialog Surface (bounded maxHeight + scrollable by default).
class ZenGlassDialogSurface extends StatelessWidget {
  final Widget child;
  final Color? accentColor;
  final double borderRadius;
  final EdgeInsetsGeometry padding;
  final double maxWidth;
  final bool scrollable;
  final double maxHeightFactor;

  const ZenGlassDialogSurface({
    super.key,
    required this.child,
    this.accentColor,
    this.borderRadius = 28.0,
    this.padding = const EdgeInsets.fromLTRB(24, 24, 24, 20),
    this.maxWidth = 400.0,
    this.scrollable = true,
    this.maxHeightFactor = 0.85,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final zen = context.zenColors;
    final glow = accentColor ?? zen.primary;
    final double maxHeight =
        MediaQuery.sizeOf(context).height * maxHeightFactor;

    Widget content = Padding(
      padding: padding,
      child: child,
    );

    if (scrollable) {
      content = SingleChildScrollView(
        physics: const BouncingScrollPhysics(),
        child: content,
      );
    }

    return ConstrainedBox(
      constraints: BoxConstraints(
        maxWidth: maxWidth,
        maxHeight: maxHeight,
      ),
      child: ZenLiquidGlass(
        borderRadius: borderRadius,
        blurSigma: 12.0,
        surfaceMode: ZenGlassSurfaceMode.frostedBlur,
        glowColor: glow,
        rimWidth: 0.8,
        enableTopSheen: false,
        surfaceColor: isDark
            ? const Color(0xFF0D1424).withValues(alpha: 0.72)
            : Colors.white.withValues(alpha: 0.76),
        customShadows: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.26 : 0.07),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
        child: content,
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
  bool scrollable = true,
  double maxHeightFactor = 0.85,
}) {
  final isDark = Theme.of(context).brightness == Brightness.dark;
  return showGeneralDialog<T>(
    context: context,
    barrierDismissible: barrierDismissible,
    barrierLabel: MaterialLocalizations.of(context).modalBarrierDismissLabel,
    barrierColor: Colors.black.withValues(alpha: isDark ? 0.50 : 0.34),
    transitionDuration: const Duration(milliseconds: 220),
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
                scrollable: scrollable,
                maxHeightFactor: maxHeightFactor,
                child: builder(ctx),
              ),
            ),
          ),
        ),
      );
    },
    transitionBuilder: (ctx, anim, secondaryAnim, child) {
      if (MediaQuery.maybeDisableAnimationsOf(ctx) ?? false) {
        return child;
      }
      final Animation<double> curved = anim.drive(
        CurveTween(
          curve: anim.status == AnimationStatus.reverse
              ? Curves.easeInCubic
              : Curves.easeOutCubic,
        ),
      );
      return FadeTransition(
        opacity: curved,
        child: ScaleTransition(
          scale: Tween<double>(begin: 0.95, end: 1.0).animate(curved),
          child: child,
        ),
      );
    },
  );
}

/// 11. Zen Glass Popup Menu
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
    return ZenGlassIconButton.lightweight(
      icon: icon,
      iconSize: iconSize,
      iconColor: iconColor,
      tooltip: tooltip,
      size: 36,
      borderRadius: 12,
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
  Color? get barrierColor => Colors.black.withValues(alpha: 0.16);

  @override
  bool get barrierDismissible => true;

  @override
  String? get barrierLabel => 'Dismiss menu';

  @override
  Duration get transitionDuration => const Duration(milliseconds: 200);

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
        ? (triggerRect.top - estimatedHeight - 6)
            .clamp(16.0, overlaySize.height)
        : triggerRect.bottom + 6;

    final Alignment scaleOrigin =
        openUpwards ? Alignment.bottomRight : Alignment.topRight;

    final Animation<double> curved = animation.drive(
      CurveTween(curve: Curves.easeOutCubic),
    );

    return Stack(
      children: [
        Positioned(
          left: left,
          top: top,
          width: menuWidth,
          child: ScaleTransition(
            alignment: scaleOrigin,
            scale: Tween<double>(begin: 0.94, end: 1.0).animate(curved),
            child: FadeTransition(
              opacity: curved,
              child: Material(
                color: Colors.transparent,
                child: ZenLiquidGlass(
                  borderRadius: 20,
                  blurSigma: 12.0,
                  surfaceMode: ZenGlassSurfaceMode.frostedBlur,
                  rimWidth: 0.8,
                  enableTopSheen: false,
                  padding: const EdgeInsets.symmetric(vertical: 6),
                  surfaceColor: isDark
                      ? const Color(0xFF0D1424).withValues(alpha: 0.74)
                      : Colors.white.withValues(alpha: 0.78),
                  customShadows: [
                    BoxShadow(
                      color:
                          Colors.black.withValues(alpha: isDark ? 0.24 : 0.07),
                      blurRadius: 18,
                      offset: const Offset(0, 6),
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
                                ? Colors.white.withValues(alpha: 0.08)
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
                                          .withValues(
                                        alpha: isDark ? 0.16 : 0.10,
                                      ),
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
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
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
                                          maxLines: 2,
                                          overflow: TextOverflow.ellipsis,
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

/// 12. Zen Glass Bottom Sheet 2.0
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
    barrierColor: Colors.black.withValues(alpha: isDark ? 0.50 : 0.34),
    elevation: 0,
    builder: (ctx) {
      Widget sheet = ClipRRect(
        borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 12.0, sigmaY: 12.0),
          child: Container(
            constraints: BoxConstraints(
              maxHeight: MediaQuery.sizeOf(ctx).height * maxHeightFactor,
            ),
            decoration: BoxDecoration(
              borderRadius:
                  const BorderRadius.vertical(top: Radius.circular(32)),
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: isDark
                    ? [
                        Color.lerp(const Color(0xFF0D1424), glow, 0.04)!
                            .withValues(alpha: 0.74),
                        const Color(0xFF0B101E).withValues(alpha: 0.66),
                      ]
                    : [
                        Colors.white.withValues(alpha: 0.78),
                        Colors.white.withValues(alpha: 0.70),
                      ],
              ),
              border: Border(
                top: BorderSide(
                  color: isDark
                      ? Colors.white.withValues(alpha: 0.14)
                      : const Color(0xFF94A3B8).withValues(alpha: 0.14),
                  width: 0.9,
                ),
                left: BorderSide(
                  color: isDark
                      ? Colors.white.withValues(alpha: 0.06)
                      : const Color(0xFFCBD5E1).withValues(alpha: 0.35),
                  width: 0.7,
                ),
                right: BorderSide(
                  color: isDark
                      ? Colors.white.withValues(alpha: 0.06)
                      : const Color(0xFFCBD5E1).withValues(alpha: 0.35),
                  width: 0.7,
                ),
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: isDark ? 0.24 : 0.06),
                  blurRadius: 20,
                  offset: const Offset(0, -4),
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
                      height: 4.5,
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [
                            (isDark ? Colors.white : Colors.black)
                                .withValues(alpha: 0.12),
                            (isDark ? Colors.white : Colors.black)
                                .withValues(alpha: 0.26),
                            (isDark ? Colors.white : Colors.black)
                                .withValues(alpha: 0.12),
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
          curve: Curves.easeOutCubic,
          padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(ctx).bottom),
          child: sheet,
        );
      }

      return sheet;
    },
  );
}

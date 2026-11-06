import 'dart:ui';
import 'package:flutter/material.dart';

/// Thành phần giao diện Kính Lỏng (Liquid Glass / Frosted Glassmorphism)
/// Đạt chuẩn phong cách Zen Luxury: Kính mờ quang học, phản chiếu viền specular hai chiều,
/// độ bóng đa tầng siêu mịn, không gây đục mờ khó chịu.
class ZenLiquidGlass extends StatelessWidget {
  final Widget child;
  final double borderRadius;
  final EdgeInsetsGeometry? padding;
  final EdgeInsetsGeometry? margin;
  final Color? surfaceColor;
  final Color? glowColor;
  final double blurSigma;
  final Border? customBorder;
  final VoidCallback? onTap;

  const ZenLiquidGlass({
    super.key,
    required this.child,
    this.borderRadius = 24.0,
    this.padding,
    this.margin,
    this.surfaceColor,
    this.glowColor,
    this.blurSigma = 16.0,
    this.customBorder,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    // Nước kính lỏng trong suốt quang học
    final effectiveSurface = surfaceColor ??
        (isDark
            ? const Color(0xFF0F1626).withOpacity(0.68)
            : Colors.white.withOpacity(0.78));

    // Viền khúc xạ ánh sáng (Specular Edge)
    final effectiveBorder = customBorder ??
        Border.all(
          color: glowColor != null
              ? glowColor!.withOpacity(isDark ? 0.35 : 0.25)
              : (isDark
                  ? Colors.white.withOpacity(0.14)
                  : const Color(0xFFE2E8F0).withOpacity(0.8)),
          width: 1.2,
        );

    Widget content = Container(
      margin: margin,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(borderRadius),
        boxShadow: [
          // Ambient Glow đa tầng
          if (glowColor != null)
            BoxShadow(
              color: glowColor!.withOpacity(isDark ? 0.16 : 0.08),
              blurRadius: 20,
              spreadRadius: 0,
              offset: const Offset(0, 6),
            ),
          BoxShadow(
            color: Colors.black.withOpacity(isDark ? 0.32 : 0.05),
            blurRadius: 24,
            spreadRadius: 0,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(borderRadius),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: blurSigma, sigmaY: blurSigma),
          child: Container(
            padding: padding,
            decoration: BoxDecoration(
              color: effectiveSurface,
              borderRadius: BorderRadius.circular(borderRadius),
              border: effectiveBorder,
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: isDark
                    ? [
                        Colors.white.withOpacity(0.08),
                        Colors.white.withOpacity(0.02),
                      ]
                    : [
                        Colors.white.withOpacity(0.6),
                        Colors.white.withOpacity(0.2),
                      ],
              ),
            ),
            child: child,
          ),
        ),
      ),
    );

    if (onTap != null) {
      return Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(borderRadius),
          onTap: onTap,
          child: content,
        ),
      );
    }

    return content;
  }
}

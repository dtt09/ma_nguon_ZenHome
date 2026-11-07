import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:zenhome_app/core/theme/app_theme.dart';
import 'package:zenhome_app/core/widgets/zen_liquid_glass.dart';

/// Custom Track Shape cho Slider phong cách Liquid Glass 2.0
class LuxurySliderTrackShape extends RoundedRectSliderTrackShape {
  final List<Color> activeGradient;
  final Color inactiveColor;
  final Color borderColor;
  final double trackHeight;
  final bool enableGlow;

  const LuxurySliderTrackShape({
    this.activeGradient = const [Color(0xFFF59E0B), Color(0xFFEA580C)],
    this.inactiveColor = const Color(0x1FFFFFFF),
    this.borderColor = const Color(0x26FFFFFF),
    this.trackHeight = 10.0,
    this.enableGlow = true,
  });

  @override
  Rect getPreferredRect({
    required RenderBox parentBox,
    Offset offset = Offset.zero,
    required SliderThemeData sliderTheme,
    bool isEnabled = false,
    bool isDiscrete = false,
  }) {
    final double overlayWidth = sliderTheme.overlayShape
            ?.getPreferredSize(isEnabled, isDiscrete)
            .width ??
        24.0;
    final double trackLeft = offset.dx + overlayWidth / 2;
    final double trackTop = offset.dy + (parentBox.size.height - trackHeight) / 2;
    final double trackWidth = parentBox.size.width - overlayWidth;
    return Rect.fromLTWH(trackLeft, trackTop, trackWidth, trackHeight);
  }

  @override
  void paint(
    PaintingContext context,
    Offset offset, {
    required RenderBox parentBox,
    required SliderThemeData sliderTheme,
    required Animation<double> enableAnimation,
    required TextDirection textDirection,
    required Offset thumbCenter,
    Offset? secondaryOffset,
    bool isDiscrete = false,
    bool isEnabled = false,
    double additionalActiveTrackHeight = 0,
  }) {
    final Canvas canvas = context.canvas;
    final Rect trackRect = getPreferredRect(
      parentBox: parentBox,
      offset: offset,
      sliderTheme: sliderTheme,
      isEnabled: isEnabled,
      isDiscrete: isDiscrete,
    );

    final Radius trackRadius = Radius.circular(trackRect.height / 2);
    final RRect fullRRect = RRect.fromRectAndRadius(trackRect, trackRadius);

    // 1. Rãnh kính mờ không hoạt động (Translucent Glass Track)
    final Paint inactivePaint = Paint()
      ..color = inactiveColor
      ..style = PaintingStyle.fill;
    canvas.drawRRect(fullRRect, inactivePaint);

    final Paint borderPaint = Paint()
      ..color = borderColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.1;
    canvas.drawRRect(fullRRect, borderPaint);

    // 2. Rãnh đang hoạt động (Luminous Liquid Active Track)
    final double activeWidth =
        (thumbCenter.dx - trackRect.left).clamp(0.0, trackRect.width);
    if (activeWidth > 0) {
      final Rect activeRect = Rect.fromLTWH(
        trackRect.left,
        trackRect.top - additionalActiveTrackHeight / 2,
        activeWidth,
        trackRect.height + additionalActiveTrackHeight,
      );
      final RRect activeRRect = RRect.fromRectAndRadius(activeRect, trackRadius);

      if (enableGlow && activeGradient.isNotEmpty) {
        final Paint glowPaint = Paint()
          ..color = activeGradient.first.withOpacity(0.38)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 7);
        canvas.drawRRect(activeRRect, glowPaint);
      }

      final Paint activePaint = Paint()
        ..shader = LinearGradient(
          colors: activeGradient,
          begin: Alignment.centerLeft,
          end: Alignment.centerRight,
        ).createShader(activeRect)
        ..style = PaintingStyle.fill;

      canvas.drawRRect(activeRRect, activePaint);
    }
  }
}

/// Nút kéo Kính Ngọc 3D (Liquid Crystal Thumb)
class LuxurySliderThumbShape extends SliderComponentShape {
  final double enabledThumbRadius;
  final Color glowColor;
  final List<Color> coreGradient;

  const LuxurySliderThumbShape({
    this.enabledThumbRadius = 13.0,
    this.glowColor = const Color(0xFFF59E0B),
    this.coreGradient = const [Color(0xFFF59E0B), Color(0xFFEA580C)],
  });

  @override
  Size getPreferredSize(bool isEnabled, bool isDiscrete) {
    return Size.fromRadius(enabledThumbRadius);
  }

  @override
  void paint(
    PaintingContext context,
    Offset center, {
    required Animation<double> activationAnimation,
    required Animation<double> enableAnimation,
    required bool isDiscrete,
    required TextPainter labelPainter,
    required RenderBox parentBox,
    required SliderThemeData sliderTheme,
    required TextDirection textDirection,
    required double value,
    required double textScaleFactor,
    required Size sizeWithOverflow,
  }) {
    final Canvas canvas = context.canvas;

    final Path shadowPath = Path()
      ..addOval(
        Rect.fromCircle(
          center: center + const Offset(0, 3),
          radius: enabledThumbRadius + 1,
        ),
      );
    canvas.drawShadow(shadowPath, glowColor.withOpacity(0.55), 8, true);

    final Paint outerRingPaint = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.fill;
    canvas.drawCircle(center, enabledThumbRadius, outerRingPaint);

    final Rect coreRect =
        Rect.fromCircle(center: center, radius: enabledThumbRadius - 2.8);
    final Paint corePaint = Paint()
      ..shader = LinearGradient(
        colors: coreGradient,
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      ).createShader(coreRect)
      ..style = PaintingStyle.fill;
    canvas.drawCircle(center, enabledThumbRadius - 2.8, corePaint);

    final Paint gripPaint = Paint()
      ..color = Colors.white.withOpacity(0.92)
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeWidth = 1.8;
    canvas.drawLine(
      center - const Offset(0, 4),
      center + const Offset(0, 4),
      gripPaint,
    );
  }
}

/// Widget Thanh Trượt Kính Lỏng Cao Cấp (Luxury Liquid Glass Slider)
class LuxurySlider extends StatelessWidget {
  final double value;
  final double min;
  final double max;
  final ValueChanged<double> onChanged;
  final ValueChanged<double>? onChangeEnd;
  final List<Color>? activeGradient;
  final Color? glowColor;
  final List<int>? milestoneValues;
  final String Function(int)? milestoneLabelBuilder;

  const LuxurySlider({
    super.key,
    required this.value,
    this.min = 1.0,
    this.max = 720.0,
    required this.onChanged,
    this.onChangeEnd,
    this.activeGradient,
    this.glowColor,
    this.milestoneValues,
    this.milestoneLabelBuilder,
  });

  @override
  Widget build(BuildContext context) {
    final bool isDark = Theme.of(context).brightness == Brightness.dark;
    final zen = context.zenColors;
    final List<Color> effectiveGradient =
        activeGradient ?? zen.brandHero.colors;
    final Color effectiveGlow = glowColor ?? effectiveGradient.first;
    final Color inactiveTrack = isDark
        ? Colors.white.withOpacity(0.09)
        : const Color(0xFF94A3B8).withOpacity(0.20);
    final Color trackBorder = isDark
        ? Colors.white.withOpacity(0.14)
        : const Color(0xFFCBD5E1).withOpacity(0.75);

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        SliderTheme(
          data: SliderTheme.of(context).copyWith(
            trackHeight: 10,
            trackShape: LuxurySliderTrackShape(
              activeGradient: effectiveGradient,
              inactiveColor: inactiveTrack,
              borderColor: trackBorder,
              trackHeight: 10,
              enableGlow: true,
            ),
            thumbShape: LuxurySliderThumbShape(
              enabledThumbRadius: 13,
              glowColor: effectiveGlow,
              coreGradient: effectiveGradient,
            ),
            overlayShape: const RoundSliderOverlayShape(overlayRadius: 24),
            overlayColor: effectiveGlow.withOpacity(0.18),
          ),
          child: Slider(
            value: value.clamp(min, max),
            min: min,
            max: max,
            onChanged: (val) {
              if (val.round() != value.round()) {
                if (milestoneValues != null &&
                    milestoneValues!.contains(val.round())) {
                  HapticFeedback.mediumImpact();
                } else if (val.round() % 5 == 0) {
                  HapticFeedback.selectionClick();
                }
              }
              onChanged(val);
            },
            onChangeEnd: onChangeEnd,
          ),
        ),

        if (milestoneValues != null && milestoneValues!.isNotEmpty) ...[
          const SizedBox(height: 6),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 6),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: milestoneValues!.map((m) {
                final bool isSelected = value.round() == m;
                final bool isReached = value >= m;
                final String label = milestoneLabelBuilder != null
                    ? milestoneLabelBuilder!(m)
                    : (m < 60 ? '${m}m' : '${m ~/ 60}h');

                return ZenGlassPill(
                  blurSigma: 0,
                  isSelected: isSelected,
                  glowColor: effectiveGlow,
                  borderRadius: 12,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8.5,
                    vertical: 4.5,
                  ),
                  onTap: () {
                    HapticFeedback.selectionClick();
                    onChanged(m.toDouble());
                    onChangeEnd?.call(m.toDouble());
                  },
                  child: Text(
                    label,
                    style: TextStyle(
                      fontSize: 10.5,
                      fontWeight:
                          (isSelected || isReached) ? FontWeight.w800 : FontWeight.w600,
                      color: isSelected
                          ? (isDark ? Colors.white : effectiveGlow)
                          : (isReached
                              ? (isDark ? AppColors.darkText : AppColors.lightText)
                              : (isDark
                                  ? AppColors.darkTextMuted
                                  : AppColors.lightTextMuted)),
                    ),
                  ),
                );
              }).toList(),
            ),
          ),
        ],
      ],
    );
  }
}

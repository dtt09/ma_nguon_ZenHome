import 'dart:math' as math;
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:zenhome_app/core/theme/app_theme.dart';

/// Custom Track Shape cho Slider phong cách Luxury Smart Home
/// Có góc bo tròn hoàn hảo, hỗ trợ dải màu Gradient rực rỡ và viền bóng phát sáng
class LuxurySliderTrackShape extends RoundedRectSliderTrackShape {
  final List<Color> activeGradient;
  final Color inactiveColor;
  final double trackHeight;
  final bool enableGlow;

  const LuxurySliderTrackShape({
    this.activeGradient = const [Color(0xFFF59E0B), Color(0xFFEA580C)],
    this.inactiveColor = const Color(0x1FFFFFFF),
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
    final double overlayWidth = sliderTheme.overlayShape?.getPreferredSize(isEnabled, isDiscrete).width ?? 24.0;
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

    // 1. Vẽ rãnh không hoạt động (Inactive Track) với viền kính mờ tinh tế
    final Paint inactivePaint = Paint()
      ..color = inactiveColor
      ..style = PaintingStyle.fill;
    canvas.drawRRect(fullRRect, inactivePaint);

    // Đường viền mảnh chống chìm màu cho Inactive Track
    final Paint borderPaint = Paint()
      ..color = Colors.white.withOpacity(0.08)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.0;
    canvas.drawRRect(fullRRect, borderPaint);

    // 2. Vẽ rãnh đang hoạt động (Active Track) với Gradient rực rỡ
    final double activeWidth = (thumbCenter.dx - trackRect.left).clamp(0.0, trackRect.width);
    if (activeWidth > 0) {
      final Rect activeRect = Rect.fromLTWH(
        trackRect.left,
        trackRect.top - additionalActiveTrackHeight / 2,
        activeWidth,
        trackRect.height + additionalActiveTrackHeight,
      );
      final RRect activeRRect = RRect.fromRectAndRadius(activeRect, trackRadius);

      // Hiệu ứng phát sáng nhẹ bên dưới thanh active
      if (enableGlow && activeGradient.isNotEmpty) {
        final Paint glowPaint = Paint()
          ..color = activeGradient.first.withOpacity(0.35)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 6);
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

/// Custom Thumb Shape cho Slider: Nút kéo nổi 3D sang trọng
/// Vành ngoài màu trắng kim loại cao cấp + Lõi phát sáng gradient + Tâm phản quang
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

    // 1. Lớp bóng đổ sâu 3D (Ambient Glow & Depth Shadow)
    final Path shadowPath = Path()
      ..addOval(Rect.fromCircle(center: center + const Offset(0, 3), radius: enabledThumbRadius + 1));
    canvas.drawShadow(shadowPath, glowColor.withOpacity(0.55), 8, true);

    // 2. Vành ngoài màu trắng kim loại chống chìm màu tuyệt đối (Brushed Chrome Ring)
    final Paint outerRingPaint = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.fill;
    canvas.drawCircle(center, enabledThumbRadius, outerRingPaint);

    // 3. Lõi Gradient đá quý rực rỡ bên trong (Vibrant Core)
    final Rect coreRect = Rect.fromCircle(center: center, radius: enabledThumbRadius - 2.8);
    final Paint corePaint = Paint()
      ..shader = LinearGradient(
        colors: coreGradient,
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      ).createShader(coreRect)
      ..style = PaintingStyle.fill;
    canvas.drawCircle(center, enabledThumbRadius - 2.8, corePaint);

    // 4. Khía rãnh xúc giác ở tâm nút (Tactile Micro Grip)
    final Paint gripPaint = Paint()
      ..color = Colors.white.withOpacity(0.9)
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

/// Widget Thanh Trượt Cao Cấp (Luxury Slider) tích hợp sẵn Haptics, Milestones và Giao diện Sang trọng
class LuxurySlider extends StatelessWidget {
  final double value;
  final double min;
  final double max;
  final ValueChanged<double> onChanged;
  final ValueChanged<double>? onChangeEnd;
  final List<Color> activeGradient;
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
    this.activeGradient = const [Color(0xFFF59E0B), Color(0xFFEA580C)],
    this.glowColor,
    this.milestoneValues,
    this.milestoneLabelBuilder,
  });

  @override
  Widget build(BuildContext context) {
    final bool isDark = Theme.of(context).brightness == Brightness.dark;
    final Color effectiveGlow = glowColor ?? activeGradient.first;
    final Color inactiveTrack = isDark
        ? const Color(0xFF1E293B)
        : const Color(0xFFE2E8F0);

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        SliderTheme(
          data: SliderTheme.of(context).copyWith(
            trackHeight: 10,
            trackShape: LuxurySliderTrackShape(
              activeGradient: activeGradient,
              inactiveColor: inactiveTrack,
              trackHeight: 10,
              enableGlow: true,
            ),
            thumbShape: LuxurySliderThumbShape(
              enabledThumbRadius: 13,
              glowColor: effectiveGlow,
              coreGradient: activeGradient,
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
                // Rung nhẹ khi trượt qua từng nấc giá trị
                if (milestoneValues != null && milestoneValues!.contains(val.round())) {
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

        // Hàng đánh dấu mốc (Milestones) nếu được truyền vào
        if (milestoneValues != null && milestoneValues!.isNotEmpty) ...[
          const SizedBox(height: 4),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: milestoneValues!.map((m) {
                final bool isReached = value >= m;
                final String label = milestoneLabelBuilder != null
                    ? milestoneLabelBuilder!(m)
                    : (m < 60 ? '${m}m' : '${m ~/ 60}h');

                return GestureDetector(
                  onTap: () {
                    HapticFeedback.selectionClick();
                    onChanged(m.toDouble());
                    onChangeEnd?.call(m.toDouble());
                  },
                  child: AnimatedDefaultTextStyle(
                    duration: const Duration(milliseconds: 180),
                    style: TextStyle(
                      fontSize: 10.5,
                      fontWeight: isReached ? FontWeight.w800 : FontWeight.w600,
                      color: isReached
                          ? (isDark ? Colors.white : const Color(0xFF0F172A))
                          : (isDark ? const Color(0xFF64748B) : const Color(0xFF94A3B8)),
                    ),
                    child: Text(label),
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

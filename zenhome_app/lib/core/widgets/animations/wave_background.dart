import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:zenhome_app/core/theme/app_theme.dart';

/// Theme-aware curved header wave background.
///
/// Static by default (`animate: false`) for 120Hz performance and GPU backdrop
/// cache stability. Uses [context.zenColors] so all 6 theme presets stay cohesive.
class WaveBackground extends StatefulWidget {
  final double heightPercent;
  final Widget? child;
  final bool animate;

  const WaveBackground({
    super.key,
    this.heightPercent = 0.65,
    this.child,
    this.animate = false,
  });

  @override
  State<WaveBackground> createState() => _WaveBackgroundState();
}

class _WaveBackgroundState extends State<WaveBackground>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 6),
    );
    if (widget.animate) {
      _controller.repeat();
    }
  }

  @override
  void didUpdateWidget(covariant WaveBackground oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.animate && !_controller.isAnimating) {
      _controller.repeat();
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
    final bool isDark = Theme.of(context).brightness == Brightness.dark;
    final zen = context.zenColors;
    final double keyboardHeight = MediaQuery.viewInsetsOf(context).bottom;
    final bool disableMotion =
        MediaQuery.maybeDisableAnimationsOf(context) ?? false;
    final bool shouldAnimate = widget.animate && !disableMotion;

    final List<Color> gradientColors = isDark
        ? [
            zen.primaryDark.withValues(alpha: 0.72),
            AppColors.darkBg,
          ]
        : zen.brandHero.colors;

    if (!shouldAnimate) {
      return Stack(
        fit: StackFit.expand,
        children: [
          RepaintBoundary(
            child: IgnorePointer(
              child: CustomPaint(
                painter: _StaticWavePainter(
                  heightPercent: widget.heightPercent,
                  keyboardHeight: keyboardHeight,
                  colors: gradientColors,
                ),
                size: Size.infinite,
              ),
            ),
          ),
          if (widget.child != null) widget.child!,
        ],
      );
    }

    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        return ClipPath(
          clipper: AnimatedWaveClipper(
            _controller.value,
            widget.heightPercent,
            keyboardHeight,
          ),
          child: Stack(
            fit: StackFit.expand,
            children: [
              RepaintBoundary(
                child: IgnorePointer(
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: gradientColors,
                      ),
                    ),
                  ),
                ),
              ),
              if (widget.child != null) widget.child!,
            ],
          ),
        );
      },
    );
  }
}

class _StaticWavePainter extends CustomPainter {
  final double heightPercent;
  final double keyboardHeight;
  final List<Color> colors;

  const _StaticWavePainter({
    required this.heightPercent,
    required this.keyboardHeight,
    required this.colors,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (size.isEmpty) return;

    final double originalHeight = size.height + keyboardHeight;
    final double yOffset = originalHeight * heightPercent;
    final double amp = originalHeight * 0.045;

    final Path path = Path()..moveTo(0, 0)..lineTo(0, yOffset);
    path.cubicTo(
      size.width * 0.28,
      yOffset + amp,
      size.width * 0.68,
      yOffset - amp,
      size.width,
      yOffset + amp * 0.25,
    );
    path.lineTo(size.width, 0);
    path.close();

    final Paint paint = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: colors,
      ).createShader(Rect.fromLTWH(0, 0, size.width, yOffset + amp));

    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant _StaticWavePainter oldDelegate) {
    return oldDelegate.heightPercent != heightPercent ||
        oldDelegate.keyboardHeight != keyboardHeight ||
        oldDelegate.colors != colors;
  }
}

class AnimatedWaveClipper extends CustomClipper<Path> {
  final double animationValue;
  final double heightPercent;
  final double keyboardHeight;
  AnimatedWaveClipper(
    this.animationValue,
    this.heightPercent,
    this.keyboardHeight,
  );

  @override
  Path getClip(Size size) {
    final path = Path();
    final double originalHeight = size.height + keyboardHeight;
    final double yOffset = originalHeight * heightPercent;
    path.lineTo(0, yOffset);

    final double amplitude = originalHeight * 0.05;

    for (double x = 0; x <= size.width; x += size.width / 50) {
      final double y = (amplitude *
              math.sin(
                (x / size.width) * 1.5 * math.pi +
                    (animationValue * 2 * math.pi),
              )) +
          (amplitude *
              0.5 *
              math.cos(
                (x / size.width) * 2 * math.pi - (animationValue * 2 * math.pi),
              )) +
          yOffset;
      path.lineTo(x, y);
    }

    path.lineTo(size.width, yOffset);
    path.lineTo(size.width, 0);
    path.close();
    return path;
  }

  @override
  bool shouldReclip(AnimatedWaveClipper oldClipper) =>
      oldClipper.animationValue != animationValue ||
      oldClipper.heightPercent != heightPercent ||
      oldClipper.keyboardHeight != keyboardHeight;
}

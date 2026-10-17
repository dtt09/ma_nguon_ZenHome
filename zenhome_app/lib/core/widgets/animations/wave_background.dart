import 'package:flutter/material.dart';
import 'dart:math' as math;

class WaveBackground extends StatefulWidget {
  final double heightPercent;
  final Widget? child;

  const WaveBackground({super.key, this.heightPercent = 0.65, this.child});

  @override
  State<WaveBackground> createState() => _WaveBackgroundState();
}

class _WaveBackgroundState extends State<WaveBackground>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 4),
    )..repeat(); // Loop continuously
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    bool isDark = Theme.of(context).brightness == Brightness.dark;

    double keyboardHeight = MediaQuery.of(context).viewInsets.bottom;

    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        return ClipPath(
          clipper: AnimatedWaveClipper(_controller.value, widget.heightPercent, keyboardHeight),
          child: Stack(
            fit: StackFit.expand,
            children: [
              IgnorePointer(
                child: Container(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: isDark
                          ? [const Color(0xFF1E1E2C), const Color(0xFF090C15)]
                          : [const Color(0xFF14B8A6), const Color(0xFF0F766E)],
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

class AnimatedWaveClipper extends CustomClipper<Path> {
  final double animationValue;
  final double heightPercent;
  final double keyboardHeight;
  AnimatedWaveClipper(this.animationValue, this.heightPercent, this.keyboardHeight);

  @override
  Path getClip(Size size) {
    var path = Path();
    double originalHeight = size.height + keyboardHeight;
    double yOffset = originalHeight * heightPercent;
    path.lineTo(0, yOffset);

    double amplitude = originalHeight * 0.05;

    // Create an organic fluid wave using two sine waves with different frequencies and directions
    for (double x = 0; x <= size.width; x += size.width / 50) {
      double y =
          (amplitude *
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

    path.lineTo(
      size.width,
      yOffset,
    ); // Ensure it connects smoothly
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



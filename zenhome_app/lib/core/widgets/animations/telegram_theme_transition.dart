import 'dart:math' as math;
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';

double _hypot(double a, double b) => math.sqrt(a * a + b * b);

class TelegramThemeTransition extends StatefulWidget {
  final Widget child;

  const TelegramThemeTransition({
    super.key,
    required this.child,
  });

  static TelegramThemeTransitionState? of(BuildContext context) {
    return context.findAncestorStateOfType<TelegramThemeTransitionState>();
  }

  @override
  State<TelegramThemeTransition> createState() => TelegramThemeTransitionState();
}

class TelegramThemeTransitionState extends State<TelegramThemeTransition>
    with SingleTickerProviderStateMixin {
  final GlobalKey _boundaryKey = GlobalKey();
  late final AnimationController _animController;
  late final Animation<double> _curveAnimation;
  ui.Image? _oldScreenImage;
  Offset _revealCenter = Offset.zero;
  bool _isTransitioning = false;

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 550),
    );
    _curveAnimation = CurvedAnimation(
      parent: _animController,
      curve: Curves.easeOutCubic,
    );
  }

  @override
  void dispose() {
    _animController.dispose();
    _oldScreenImage?.dispose();
    super.dispose();
  }

  /// Triggers the Telegram-style circular wave transition
  Future<void> startThemeTransition({
    required Offset center,
    required Future<void> Function() performThemeChange,
  }) async {
    if (_isTransitioning) {
      await performThemeChange();
      return;
    }

    try {
      final boundary =
          _boundaryKey.currentContext?.findRenderObject() as RenderRepaintBoundary?;
      if (boundary != null) {
        final pixelRatio = View.of(context).devicePixelRatio;
        final image = await boundary.toImage(pixelRatio: math.min(pixelRatio, 2.0));

        if (!mounted) {
          image.dispose();
          return;
        }

        setState(() {
          _isTransitioning = true;
          _oldScreenImage?.dispose();
          _oldScreenImage = image;
          _revealCenter = center;
        });

        // Apply the new theme
        await performThemeChange();

        // Ensure the newly styled frame is ready beneath before animating
        await WidgetsBinding.instance.endOfFrame;

        // Animate circular reveal
        await _animController.forward(from: 0.0);

        if (mounted) {
          setState(() {
            _oldScreenImage?.dispose();
            _oldScreenImage = null;
            _isTransitioning = false;
          });
        }
        return;
      }
    } catch (e) {
      debugPrint("Telegram theme transition exception: $e");
    }

    _oldScreenImage?.dispose();
    _oldScreenImage = null;
    _isTransitioning = false;
    await performThemeChange();
  }

  @override
  Widget build(BuildContext context) {
    final screenSize = MediaQuery.of(context).size;
    final maxRadius = _hypot(
      math.max(_revealCenter.dx, screenSize.width - _revealCenter.dx),
      math.max(_revealCenter.dy, screenSize.height - _revealCenter.dy),
    );

    return RepaintBoundary(
      key: _boundaryKey,
      child: Stack(
        fit: StackFit.expand,
        children: [
          widget.child,
          if (_oldScreenImage != null)
            IgnorePointer(
              child: AnimatedBuilder(
                animation: _curveAnimation,
                builder: (context, _) {
                  return CustomPaint(
                    size: screenSize,
                    painter: TelegramRevealPainter(
                      image: _oldScreenImage!,
                      center: _revealCenter,
                      radius: _curveAnimation.value * maxRadius,
                    ),
                  );
                },
              ),
            ),
        ],
      ),
    );
  }
}

class TelegramRevealPainter extends CustomPainter {
  final ui.Image image;
  final Offset center;
  final double radius;

  TelegramRevealPainter({
    required this.image,
    required this.center,
    required this.radius,
  });

  @override
  void paint(Canvas canvas, Size size) {
    canvas.save();

    // Clip with an expanding circular cutout:
    // Outer rectangle + inner circle with evenOdd creates a hole revealing the layer below
    final path = Path()
      ..addRect(Rect.fromLTWH(0, 0, size.width, size.height))
      ..addOval(Rect.fromCircle(center: center, radius: math.max(0.0, radius)))
      ..fillType = PathFillType.evenOdd;

    canvas.clipPath(path);

    // Paint the captured old screen
    paintImage(
      canvas: canvas,
      rect: Rect.fromLTWH(0, 0, size.width, size.height),
      image: image,
      fit: BoxFit.cover,
    );

    canvas.restore();

    // Telegram subtle shining ripple contour along the advancing wave
    final screenDiagonal = _hypot(size.width, size.height);
    if (radius > 10 && radius < screenDiagonal * 1.1) {
      final ripplePaint = Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.5
        ..color = Colors.white.withOpacity(
          (0.35 * (1.0 - (radius / (screenDiagonal * 1.1)))).clamp(0.0, 0.35),
        );
      canvas.drawCircle(center, radius, ripplePaint);
    }
  }

  @override
  bool shouldRepaint(covariant TelegramRevealPainter oldDelegate) {
    return oldDelegate.radius != radius;
  }
}

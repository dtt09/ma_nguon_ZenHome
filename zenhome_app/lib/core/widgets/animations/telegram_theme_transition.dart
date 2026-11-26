import 'dart:math' as math;
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';

double _hypot(double a, double b) => math.sqrt(a * a + b * b);

class TelegramThemeTransition extends StatefulWidget {
  final Widget child;

  const TelegramThemeTransition({super.key, required this.child});

  static TelegramThemeTransitionState? of(BuildContext context) {
    return context.findAncestorStateOfType<TelegramThemeTransitionState>();
  }

  @override
  State<TelegramThemeTransition> createState() =>
      TelegramThemeTransitionState();
}

class TelegramThemeTransitionState extends State<TelegramThemeTransition>
    with SingleTickerProviderStateMixin {
  final GlobalKey _boundaryKey = GlobalKey();
  late final AnimationController _reveal = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 260),
  );
  Future<void> _pending = Future<void>.value();
  int _request = 0;
  ui.Image? _snapshot;
  Offset _origin = Offset.zero;

  Future<void> startThemeTransition({
    required Offset center,
    required Future<void> Function() performThemeChange,
  }) {
    final request = ++_request;
    _reveal.stop();
    final result = _pending.then((_) async {
      if (!mounted) return;
      final animate =
          request == _request &&
          !MediaQuery.disableAnimationsOf(context) &&
          TickerMode.valuesOf(context).enabled;
      final image = animate ? await _capture() : null;
      if (!mounted) {
        image?.dispose();
        return;
      }
      try {
        if (image != null && request == _request) {
          setState(() {
            _origin = center;
            _snapshot = image;
            _reveal.value = 0;
          });
        }
        await performThemeChange();
        if (image == null || !mounted || request != _request) return;
        await WidgetsBinding.instance.endOfFrame;
        if (mounted && request == _request) {
          try {
            await _reveal.forward().orCancel;
          } on TickerCanceled {
            // A newer selection or disposal interrupted this reveal.
          }
        }
      } finally {
        if (mounted && identical(image, _snapshot) && image != null) {
          setState(() => _snapshot = null);
        }
        image?.dispose();
      }
    });
    // Keep subsequent choices in tap order, including after a failed write.
    _pending = result.catchError((Object _) {});
    return result;
  }

  Future<ui.Image?> _capture() async {
    final boundary = _boundaryKey.currentContext?.findRenderObject();
    if (boundary is! RenderRepaintBoundary ||
        !boundary.hasSize ||
        boundary.size.isEmpty) {
      return null;
    }
    final size = boundary.size;
    final scale = math.min(
      View.of(context).devicePixelRatio,
      math.min(1.5, math.sqrt(1000000 / (size.width * size.height))),
    );
    try {
      return await boundary.toImage(pixelRatio: scale);
    } catch (_) {
      // The underlying render surface can disappear during a window resize.
      return null;
    }
  }

  @override
  void dispose() {
    _reveal.dispose();
    // The operation that captured the image also owns its disposal.
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Stack(
    fit: StackFit.expand,
    children: [
      RepaintBoundary(key: _boundaryKey, child: widget.child),
      if (_snapshot != null)
        IgnorePointer(
          child: RepaintBoundary(
            child: CustomPaint(
              painter: _ThemeRevealPainter(_snapshot!, _origin, _reveal),
            ),
          ),
        ),
    ],
  );
}

class _ThemeRevealPainter extends CustomPainter {
  _ThemeRevealPainter(this.image, this.center, this.progress)
    : super(repaint: progress);

  final ui.Image image;
  final Offset center;
  final Animation<double> progress;

  @override
  void paint(Canvas canvas, Size size) {
    final bounds = Offset.zero & size;
    final x = math.max(center.dx.abs(), (size.width - center.dx).abs());
    final y = math.max(center.dy.abs(), (size.height - center.dy).abs());
    final radius = _hypot(x, y) * Curves.easeOutCubic.transform(progress.value);
    final mask = Path()
      ..fillType = PathFillType.evenOdd
      ..addRect(bounds)
      ..addOval(Rect.fromCircle(center: center, radius: radius));
    canvas.save();
    // Also constrain the outer edge when the reveal circle crosses the window.
    canvas.clipRect(bounds);
    canvas.clipPath(mask);
    paintImage(canvas: canvas, rect: bounds, image: image, fit: BoxFit.fill);
    canvas.restore();
  }

  @override
  bool shouldRepaint(_ThemeRevealPainter old) =>
      image != old.image || center != old.center || progress != old.progress;
}

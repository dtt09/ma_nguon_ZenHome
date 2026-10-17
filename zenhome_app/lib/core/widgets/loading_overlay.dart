import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';

class LogoLoadingIndicator extends StatelessWidget {
  final Color color;
  final double size;
  const LogoLoadingIndicator({super.key, required this.color, this.size = 60});

  @override
  Widget build(BuildContext context) {
    return Image.asset(
      'public/zenhome_logo_transparent.png',
      width: size,
      height: size,
      color: color,
    ).animate(onPlay: (controller) => controller.repeat())
     .shimmer(duration: 1500.ms, color: Colors.white54, angle: 1)
     .shimmer(duration: 1500.ms, color: Colors.black12, angle: 1, delay: 750.ms);
  }
}

class LoadingOverlay {
  static OverlayEntry? _overlayEntry;
  static final ValueNotifier<String> _statusNotifier = ValueNotifier('loading'); // 'loading', 'success', 'error'

  static void show(BuildContext context) {
    if (_overlayEntry != null) return;
    _statusNotifier.value = 'loading';

    final overlayState = Overlay.of(context);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final color = isDark ? const Color(0xFF14B8A6) : const Color(0xFF0F766E);

    _overlayEntry = OverlayEntry(
      builder: (context) {
        return Stack(
          children: [
            BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 5.0, sigmaY: 5.0),
              child: Container(color: Colors.black.withOpacity(0.3)),
            ),
            Center(
              child: ValueListenableBuilder<String>(
                valueListenable: _statusNotifier,
                builder: (context, status, child) {
                  return Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 40,
                      vertical: 30,
                    ),
                    decoration: BoxDecoration(
                      color: isDark ? const Color(0xFF121827) : Colors.white,
                      borderRadius: BorderRadius.circular(20),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.2),
                          blurRadius: 20,
                          offset: const Offset(0, 10),
                        ),
                      ],
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (status == 'loading')
                          LogoLoadingIndicator(color: color)
                        else if (status == 'success')
                          const Icon(Icons.check_circle_outline_rounded, color: Colors.green, size: 60)
                            .animate().scale(duration: 400.ms, curve: Curves.easeOutBack)
                        else if (status == 'error')
                          const Icon(Icons.error_outline_rounded, color: Colors.red, size: 60)
                            .animate().scale(duration: 400.ms, curve: Curves.easeOutBack),
                      ],
                    ),
                  ).animate(key: ValueKey(status)).slideY(begin: 0.1, end: 0, duration: 200.ms, curve: Curves.easeOutQuad).scale(duration: 200.ms);
                },
              ),
            ),
          ],
        );
      },
    );

    overlayState.insert(_overlayEntry!);
  }

  static void hide() {
    if (_overlayEntry != null) {
      _overlayEntry!.remove();
      _overlayEntry = null;
    }
  }

  static Future<void> hideSuccess({int delayMs = 600}) async {
    if (_overlayEntry != null) {
      _statusNotifier.value = 'success';
      await Future.delayed(Duration(milliseconds: delayMs));
      hide();
    }
  }

  static Future<void> hideError({int delayMs = 600}) async {
    if (_overlayEntry != null) {
      _statusNotifier.value = 'error';
      await Future.delayed(Duration(milliseconds: delayMs));
      hide();
    }
  }
}



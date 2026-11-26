import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:zenhome_app/core/theme/app_theme.dart';
import 'package:zenhome_app/core/widgets/zen_liquid_glass.dart';

class LogoLoadingIndicator extends StatefulWidget {
  final Color color;
  final double size;
  const LogoLoadingIndicator({super.key, required this.color, this.size = 60});

  @override
  State<LogoLoadingIndicator> createState() => _LogoLoadingIndicatorState();
}

class _LogoLoadingIndicatorState extends State<LogoLoadingIndicator>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final CurvedAnimation _curvedAnimation;
  late final Animation<double> _scaleAnimation;
  late final Animation<double> _fadeAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1600),
    );
    _curvedAnimation = CurvedAnimation(
      parent: _controller,
      curve: Curves.easeInOutSine,
    );
    _scaleAnimation = Tween<double>(begin: 0.95, end: 1.03).animate(
      _curvedAnimation,
    );
    _fadeAnimation = Tween<double>(begin: 0.75, end: 1.0).animate(
      _curvedAnimation,
    );
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final bool disableAnimations =
        MediaQuery.maybeDisableAnimationsOf(context) ?? false;
    if (disableAnimations) {
      if (_controller.isAnimating) {
        _controller.stop();
      }
      _controller.value = 0.5;
    } else if (!_controller.isAnimating) {
      _controller.repeat(reverse: true);
    }
  }

  @override
  void dispose() {
    _curvedAnimation.dispose();
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final bool disableAnimations =
        MediaQuery.maybeDisableAnimationsOf(context) ?? false;

    final Widget logo = Image.asset(
      'public/zenhome_logo_transparent.png',
      width: widget.size,
      height: widget.size,
      color: widget.color,
    );

    if (disableAnimations) {
      return logo;
    }

    return RepaintBoundary(
      child: FadeTransition(
        opacity: _fadeAnimation,
        child: ScaleTransition(
          scale: _scaleAnimation,
          child: logo,
        ),
      ),
    );
  }
}

class LoadingOverlay {
  static OverlayEntry? _overlayEntry;
  static GlobalKey<_LoadingOverlayContentState>? _contentKey;
  static int _generation = 0;
  static final ValueNotifier<String> _statusNotifier =
      ValueNotifier('loading'); // 'loading', 'success', 'error'

  static void _removeCurrentEntryImmediately() {
    _generation++;
    final entry = _overlayEntry;
    _overlayEntry = null;
    _contentKey = null;
    if (entry != null) {
      try {
        entry.remove();
      } catch (_) {}
    }
  }

  static void show(BuildContext context) {
    if (_overlayEntry != null && _contentKey?.currentState?.isClosing == false) {
      return;
    }
    if (_overlayEntry != null) {
      _removeCurrentEntryImmediately();
    }

    _statusNotifier.value = 'loading';
    final int entryGeneration = ++_generation;
    final key = GlobalKey<_LoadingOverlayContentState>();
    _contentKey = key;

    final overlayState = Overlay.of(context);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final zen = context.zenColors;
    final baseColor = isDark ? zen.primaryAccent : zen.primary;

    _overlayEntry = OverlayEntry(
      builder: (ctx) => _LoadingOverlayContent(
        key: key,
        isDark: isDark,
        zen: zen,
        baseColor: baseColor,
        statusNotifier: _statusNotifier,
      ),
    );

    if (_generation == entryGeneration && _overlayEntry != null) {
      overlayState.insert(_overlayEntry!);
    }
  }

  static void hide() {
    final entry = _overlayEntry;
    if (entry == null) return;

    final int entryGeneration = _generation;
    final state = _contentKey?.currentState;
    if (state == null || !state.mounted) {
      _removeCurrentEntryImmediately();
      return;
    }

    state.dismiss().then((_) {
      if (_generation == entryGeneration && _overlayEntry == entry) {
        _overlayEntry = null;
        _contentKey = null;
        try {
          entry.remove();
        } catch (_) {}
      }
    });
  }

  static Future<void> hideSuccess({int delayMs = 600}) async {
    if (_overlayEntry == null) return;
    final int entryGeneration = _generation;
    _statusNotifier.value = 'success';
    await Future.delayed(Duration(milliseconds: delayMs));
    if (_generation == entryGeneration && _overlayEntry != null) {
      hide();
    }
  }

  static Future<void> hideError({int delayMs = 600}) async {
    if (_overlayEntry == null) return;
    final int entryGeneration = _generation;
    _statusNotifier.value = 'error';
    await Future.delayed(Duration(milliseconds: delayMs));
    if (_generation == entryGeneration && _overlayEntry != null) {
      hide();
    }
  }
}

class _LoadingOverlayContent extends StatefulWidget {
  final bool isDark;
  final ZenThemeColorsExtension zen;
  final Color baseColor;
  final ValueNotifier<String> statusNotifier;

  const _LoadingOverlayContent({
    super.key,
    required this.isDark,
    required this.zen,
    required this.baseColor,
    required this.statusNotifier,
  });

  @override
  State<_LoadingOverlayContent> createState() => _LoadingOverlayContentState();
}

class _LoadingOverlayContentState extends State<_LoadingOverlayContent>
    with SingleTickerProviderStateMixin {
  late final AnimationController _fadeController;
  late final Animation<double> _fadeAnimation;
  bool isClosing = false;

  @override
  void initState() {
    super.initState();
    _fadeController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 220),
      reverseDuration: const Duration(milliseconds: 180),
    );
    _fadeAnimation = CurvedAnimation(
      parent: _fadeController,
      curve: Curves.easeOutCubic,
      reverseCurve: Curves.easeInCubic,
    );
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (isClosing) return;
    final bool disableAnimations =
        MediaQuery.maybeDisableAnimationsOf(context) ?? false;
    if (disableAnimations) {
      _fadeController.value = 1.0;
    } else if (_fadeController.status == AnimationStatus.dismissed) {
      _fadeController.forward();
    }
  }

  Future<void> dismiss() async {
    if (isClosing) return;
    isClosing = true;
    final bool disableAnimations =
        !mounted || (MediaQuery.maybeDisableAnimationsOf(context) ?? false);
    if (disableAnimations) {
      _fadeController.value = 0.0;
      return;
    }
    await _fadeController.reverse();
  }

  @override
  void dispose() {
    _fadeController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final bool disableAnimations =
        MediaQuery.maybeDisableAnimationsOf(context) ?? false;

    return FadeTransition(
      opacity: _fadeAnimation,
      child: Stack(
        children: [
          BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 10.0, sigmaY: 10.0),
            child: ColoredBox(
              color: Colors.black.withValues(alpha: widget.isDark ? 0.46 : 0.28),
            ),
          ),
          Center(
            child: Material(
              color: Colors.transparent,
              child: ValueListenableBuilder<String>(
                valueListenable: widget.statusNotifier,
                builder: (context, status, child) {
                  final Color statusGlow = status == 'success'
                      ? widget.zen.success
                      : (status == 'error'
                          ? widget.zen.danger
                          : widget.baseColor);

                  return ZenLiquidGlass.lightweight(
                    borderRadius: 28,
                    glowColor: statusGlow,
                    rimWidth: 0.8,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 36,
                      vertical: 28,
                    ),
                    surfaceColor: widget.isDark
                        ? const Color(0xFF0D1424).withValues(alpha: 0.78)
                        : Colors.white.withValues(alpha: 0.80),
                    child: AnimatedSwitcher(
                      duration: disableAnimations
                          ? Duration.zero
                          : const Duration(milliseconds: 220),
                      switchInCurve: Curves.easeOutCubic,
                      switchOutCurve: Curves.easeInCubic,
                      transitionBuilder: (child, animation) => FadeTransition(
                        opacity: animation,
                        child: ScaleTransition(
                          scale: Tween<double>(
                            begin: 0.92,
                            end: 1.0,
                          ).animate(animation),
                          child: child,
                        ),
                      ),
                      child: KeyedSubtree(
                        key: ValueKey(status),
                        child: _buildStatusChild(status),
                      ),
                    ),
                  );
                },
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatusChild(String status) {
    if (status == 'success') {
      return Icon(
        Icons.check_circle_outline_rounded,
        color: widget.zen.success,
        size: 60,
      );
    }
    if (status == 'error') {
      return Icon(
        Icons.error_outline_rounded,
        color: widget.zen.danger,
        size: 60,
      );
    }
    return LogoLoadingIndicator(color: widget.baseColor);
  }
}

import 'package:flutter/material.dart';

/// Unified 120Hz page route transition for ZenHome screens.
///
/// Uses GPU-friendly fade, subtle vertical slide (0.025), and slight scale
/// (0.985 -> 1.0) on [Curves.easeOutCubic] without bounce overshoot.
class ZenPageRoute<T> extends PageRouteBuilder<T> {
  final WidgetBuilder builder;

  ZenPageRoute({
    required this.builder,
    super.settings,
    super.fullscreenDialog,
    Duration duration = const Duration(milliseconds: 280),
    Duration reverseDuration = const Duration(milliseconds: 240),
  }) : super(
          transitionDuration: duration,
          reverseTransitionDuration: reverseDuration,
          pageBuilder: (context, animation, secondaryAnimation) =>
              builder(context),
          transitionsBuilder: (context, animation, secondaryAnimation, child) {
            final disableMotion =
                MediaQuery.maybeDisableAnimationsOf(context) ?? false;
            if (disableMotion) {
              return child;
            }

            final Animation<double> curved = animation.drive(
              CurveTween(
                curve: animation.status == AnimationStatus.reverse
                    ? Curves.easeInCubic
                    : Curves.easeOutCubic,
              ),
            );

            return FadeTransition(
              opacity: curved,
              child: SlideTransition(
                position: Tween<Offset>(
                  begin: const Offset(0.0, 0.025),
                  end: Offset.zero,
                ).animate(curved),
                child: ScaleTransition(
                  scale: Tween<double>(begin: 0.985, end: 1.0).animate(curved),
                  child: child,
                ),
              ),
            );
          },
        );
}

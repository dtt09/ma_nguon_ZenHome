import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class BouncingButton extends StatefulWidget {
  final Widget child;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;
  final double scaleFactor;
  final Duration duration;
  final bool enableHaptics;

  const BouncingButton({
    super.key,
    required this.child,
    this.onTap,
    this.onLongPress,
    this.scaleFactor = 0.96,
    this.duration = const Duration(milliseconds: 110),
    this.enableHaptics = false,
  });

  @override
  State<BouncingButton> createState() => _BouncingButtonState();
}

class _BouncingButtonState extends State<BouncingButton>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late CurvedAnimation _curvedAnimation;
  late Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: widget.duration,
      reverseDuration: const Duration(milliseconds: 140),
    );
    _curvedAnimation = CurvedAnimation(
      parent: _controller,
      curve: Curves.easeOutCubic,
      reverseCurve: Curves.easeOutCubic,
    );
    _scaleAnimation = Tween<double>(
      begin: 1.0,
      end: widget.scaleFactor,
    ).animate(_curvedAnimation);
  }

  @override
  void didUpdateWidget(covariant BouncingButton oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.duration != widget.duration) {
      _controller.duration = widget.duration;
    }
    if (oldWidget.scaleFactor != widget.scaleFactor) {
      _scaleAnimation = Tween<double>(
        begin: 1.0,
        end: widget.scaleFactor,
      ).animate(_curvedAnimation);
    }
  }

  @override
  void dispose() {
    _curvedAnimation.dispose();
    _controller.dispose();
    super.dispose();
  }

  bool get _disableAnimations =>
      MediaQuery.maybeDisableAnimationsOf(context) ?? false;

  void _onTapDown(TapDownDetails details) {
    if (_disableAnimations) return;
    if (widget.onTap != null || widget.onLongPress != null) {
      _controller.forward();
    }
  }

  void _onTapUp(TapUpDetails details) {
    if (_disableAnimations) return;
    _controller.reverse();
  }

  void _onTapCancel() {
    if (_disableAnimations) return;
    _controller.reverse();
  }

  @override
  Widget build(BuildContext context) {
    final bool disableAnimations = _disableAnimations;

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTapDown: _onTapDown,
      onTapUp: _onTapUp,
      onTapCancel: _onTapCancel,
      onTap: widget.onTap != null
          ? () {
              if (widget.enableHaptics) {
                HapticFeedback.lightImpact();
              }
              widget.onTap!();
            }
          : null,
      onLongPress: widget.onLongPress != null
          ? () {
              if (!disableAnimations) {
                _controller.reverse();
              }
              HapticFeedback.heavyImpact();
              widget.onLongPress!();
            }
          : null,
      child: disableAnimations
          ? widget.child
          : AnimatedBuilder(
              animation: _scaleAnimation,
              builder: (context, child) => Transform.scale(
                scale: _scaleAnimation.value,
                child: child,
              ),
              child: widget.child,
            ),
    );
  }
}

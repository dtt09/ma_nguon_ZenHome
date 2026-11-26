import 'package:flutter/material.dart';

/// Smooth counting number text with tabular figures so digits never jitter inside
/// FittedBox or narrow rows during updates.
class AnimatedCountingNumber extends StatelessWidget {
  final num number;
  final TextStyle? style;
  final Duration duration;
  final Curve curve;
  final String? prefix;
  final String? suffix;
  final int fractionDigits;

  const AnimatedCountingNumber({
    super.key,
    required this.number,
    this.style,
    this.duration = const Duration(milliseconds: 500),
    this.curve = Curves.easeOutCubic,
    this.prefix,
    this.suffix,
    this.fractionDigits = 0,
  });

  @override
  Widget build(BuildContext context) {
    final bool disableMotion =
        MediaQuery.maybeDisableAnimationsOf(context) ?? false;
    final TextStyle effectiveStyle = (style ?? const TextStyle()).copyWith(
      fontFeatures: [
        ...?style?.fontFeatures,
        const FontFeature.tabularFigures(),
      ],
    );

    if (disableMotion) {
      final formatted = fractionDigits > 0
          ? number.toDouble().toStringAsFixed(fractionDigits)
          : number.round().toString();
      return Text(
        '${prefix ?? ''}$formatted${suffix ?? ''}',
        maxLines: 1,
        style: effectiveStyle,
      );
    }

    return TweenAnimationBuilder<double>(
      tween: Tween<double>(begin: number.toDouble(), end: number.toDouble()),
      duration: duration,
      curve: curve,
      builder: (context, value, child) {
        final formattedNumber = fractionDigits > 0
            ? value.toStringAsFixed(fractionDigits)
            : value.round().toString();

        return Text(
          '${prefix ?? ''}$formattedNumber${suffix ?? ''}',
          maxLines: 1,
          style: effectiveStyle,
        );
      },
    );
  }
}

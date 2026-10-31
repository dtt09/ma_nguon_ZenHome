import 'package:flutter/material.dart';

/// Component AnimatedCountingNumber theo phong cách Animate UI
/// Tự động cuộn số mượt mà khi giá trị thay đổi (Số thiết bị, Nhiệt độ, Độ ẩm)
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
    this.duration = const Duration(milliseconds: 650),
    this.curve = Curves.easeOutCubic,
    this.prefix,
    this.suffix,
    this.fractionDigits = 0,
  });

  @override
  Widget build(BuildContext context) {
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
          style: style,
        );
      },
    );
  }
}

import 'package:flutter/material.dart';

/// Gives the heading its own line when a status or action would crowd it out.
class AdaptiveHomeHeader extends StatelessWidget {
  const AdaptiveHomeHeader({
    super.key,
    required this.heading,
    required this.trailing,
  });

  final Widget heading;
  final Widget trailing;

  @override
  Widget build(BuildContext context) {
    final minimumRowWidth =
        164 + 10 * MediaQuery.textScalerOf(context).scale(16);
    return LayoutBuilder(
      builder: (context, constraints) {
        if (constraints.maxWidth < minimumRowWidth) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [heading, const SizedBox(height: 8), trailing],
          );
        }
        return Row(
          children: [
            Expanded(child: heading),
            const SizedBox(width: 10),
            trailing,
          ],
        );
      },
    );
  }
}

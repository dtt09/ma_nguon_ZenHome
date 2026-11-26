import 'package:flutter/material.dart';
import 'package:zenhome_app/core/theme/app_theme.dart';
import 'package:zenhome_app/core/utils/localization_extension.dart';
import 'package:zenhome_app/core/widgets/zen_liquid_glass.dart';

class PasswordStrengthEvaluation {
  final bool hasMinLength;
  final bool hasUppercase;
  final bool hasLowercase;
  final bool hasNumber;
  final bool hasSpecialChar;

  const PasswordStrengthEvaluation({
    required this.hasMinLength,
    required this.hasUppercase,
    required this.hasLowercase,
    required this.hasNumber,
    required this.hasSpecialChar,
  });

  int get passedCount =>
      (hasMinLength ? 1 : 0) +
      (hasUppercase ? 1 : 0) +
      (hasLowercase ? 1 : 0) +
      (hasNumber ? 1 : 0) +
      (hasSpecialChar ? 1 : 0);

  double get percent => passedCount / 5.0;

  bool get isValid => passedCount == 5;
}

class PasswordStrengthCard extends StatelessWidget {
  final String password;
  final EdgeInsetsGeometry padding;
  final double borderRadius;

  const PasswordStrengthCard({
    super.key,
    required this.password,
    this.padding = const EdgeInsets.all(14),
    this.borderRadius = 16.0,
  });

  static PasswordStrengthEvaluation evaluate(String password) {
    return PasswordStrengthEvaluation(
      hasMinLength: password.length >= 8,
      hasUppercase: password.contains(RegExp(r'[A-Z]')),
      hasLowercase: password.contains(RegExp(r'[a-z]')),
      hasNumber: password.contains(RegExp(r'[0-9]')),
      hasSpecialChar: password.contains(RegExp(r'[!@#\$%^&*(),.?":{}|<>]')),
    );
  }

  static bool isPasswordValid(String password) => evaluate(password).isValid;

  @override
  Widget build(BuildContext context) {
    final bool isDark = Theme.of(context).brightness == Brightness.dark;
    final bool disableAnimations =
        MediaQuery.maybeDisableAnimationsOf(context) ?? false;
    final zen = context.zenColors;
    final eval = evaluate(password);

    final Color strengthColor;
    if (eval.passedCount <= 2) {
      strengthColor = zen.danger;
    } else if (eval.passedCount <= 4) {
      strengthColor = zen.warning;
    } else {
      strengthColor = zen.success;
    }

    final Color trackColor = isDark
        ? Colors.white.withValues(alpha: 0.10)
        : const Color(0xFF94A3B8).withValues(alpha: 0.22);

    return ZenGlassCard.lightweight(
      borderRadius: borderRadius,
      padding: padding,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: SizedBox(
              height: 6,
              width: double.infinity,
              child: DecoratedBox(
                decoration: BoxDecoration(color: trackColor),
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: AnimatedFractionallySizedBox(
                    duration: disableAnimations
                        ? Duration.zero
                        : const Duration(milliseconds: 220),
                    curve: Curves.easeOutCubic,
                    widthFactor: eval.percent.clamp(0.0, 1.0),
                    heightFactor: 1.0,
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        color: strengthColor,
                        borderRadius: BorderRadius.circular(6),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(height: 10),
          _PasswordRequirementRow(
            label: context.tr('req_min_length'),
            met: eval.hasMinLength,
            isDark: isDark,
            metColor: zen.success,
          ),
          const SizedBox(height: 4),
          _PasswordRequirementRow(
            label: context.tr('req_uppercase'),
            met: eval.hasUppercase,
            isDark: isDark,
            metColor: zen.success,
          ),
          const SizedBox(height: 4),
          _PasswordRequirementRow(
            label: context.tr('req_lowercase'),
            met: eval.hasLowercase,
            isDark: isDark,
            metColor: zen.success,
          ),
          const SizedBox(height: 4),
          _PasswordRequirementRow(
            label: context.tr('req_number'),
            met: eval.hasNumber,
            isDark: isDark,
            metColor: zen.success,
          ),
          const SizedBox(height: 4),
          _PasswordRequirementRow(
            label: context.tr('req_special_char'),
            met: eval.hasSpecialChar,
            isDark: isDark,
            metColor: zen.success,
          ),
        ],
      ),
    );
  }
}

class _PasswordRequirementRow extends StatelessWidget {
  final String label;
  final bool met;
  final bool isDark;
  final Color metColor;

  const _PasswordRequirementRow({
    required this.label,
    required this.met,
    required this.isDark,
    required this.metColor,
  });

  @override
  Widget build(BuildContext context) {
    final Color mutedColor =
        isDark ? AppColors.darkTextMuted : AppColors.lightTextMuted;
    final Color activeTextColor =
        isDark ? AppColors.darkText : AppColors.lightText;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Icon(
          met
              ? Icons.check_circle_rounded
              : Icons.radio_button_unchecked_rounded,
          size: 16,
          color: met ? metColor : mutedColor,
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            label,
            style: TextStyle(
              fontSize: 12.5,
              fontWeight: met ? FontWeight.w600 : FontWeight.w500,
              color: met ? activeTextColor : mutedColor,
              height: 1.3,
            ),
          ),
        ),
      ],
    );
  }
}

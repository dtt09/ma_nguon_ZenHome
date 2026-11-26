import 'package:flutter/material.dart';
import 'package:zenhome_app/core/theme/app_theme.dart';
import 'package:zenhome_app/core/utils/haptic_helper.dart';
import 'package:zenhome_app/core/widgets/zen_liquid_glass.dart';

Future<bool?> showPremiumConfirmDialog({
  required BuildContext context,
  required String title,
  required String message,
  required String confirmText,
  required String cancelText,
  required VoidCallback onConfirm,
  bool isDanger = false,
  IconData? icon,
}) {
  if (isDanger) {
    HapticHelper.errorVibrate();
  } else {
    HapticHelper.light();
  }

  final isDark = Theme.of(context).brightness == Brightness.dark;
  final zen = context.zenColors;
  final Color accentColor = isDanger
      ? zen.danger
      : (isDark ? zen.primaryAccent : zen.primary);

  return showZenGlassDialog<bool>(
    context: context,
    accentColor: accentColor,
    builder: (ctx) {
      return Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Container(
              width: 60,
              height: 60,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: LinearGradient(
                  colors: [
                    accentColor.withValues(alpha: 0.16),
                    accentColor.withValues(alpha: 0.06),
                  ],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                border: Border.all(
                  color: accentColor.withValues(alpha: isDark ? 0.26 : 0.20),
                  width: 0.9,
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: isDark ? 0.22 : 0.08),
                    blurRadius: 12,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Icon(icon, size: 28, color: accentColor),
            ),
            const SizedBox(height: 18),
          ],
          Text(
            title,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w800,
              letterSpacing: -0.3,
              color: isDark ? AppColors.darkText : AppColors.lightText,
            ),
          ),
          const SizedBox(height: 10),
          Text(
            message,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 14.5,
              height: 1.45,
              color: isDark ? AppColors.darkTextMuted : AppColors.lightTextMuted,
            ),
          ),
          const SizedBox(height: 26),
          Row(
            children: [
              Expanded(
                child: ZenGlassButton(
                  label: cancelText,
                  isPrimary: false,
                  maxLines: 2,
                  onPressed: () => Navigator.of(ctx).pop(false),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: ZenGlassButton(
                  label: confirmText,
                  isPrimary: true,
                  isDanger: isDanger,
                  maxLines: 2,
                  onPressed: () {
                    onConfirm();
                    Navigator.of(ctx).pop(true);
                  },
                ),
              ),
            ],
          ),
        ],
      );
    },
  );
}

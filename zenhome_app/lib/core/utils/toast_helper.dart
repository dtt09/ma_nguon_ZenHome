import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:zenhome_app/core/theme/app_theme.dart';
import 'package:zenhome_app/core/utils/haptic_helper.dart';
import 'package:zenhome_app/core/widgets/zen_liquid_glass.dart';

void showFloatingToast(
  BuildContext context,
  String title,
  String message, {
  bool isError = false,
}) {
  if (isError) {
    HapticHelper.errorVibrate();
  } else {
    HapticHelper.medium();
  }

  final bool isDark = Theme.of(context).brightness == Brightness.dark;
  final zen = context.zenColors;
  final Color accent = isError ? AppColors.roseGlow : zen.primary;

  ScaffoldMessenger.of(context).hideCurrentSnackBar();
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(
      backgroundColor: Colors.transparent,
      elevation: 0,
      behavior: SnackBarBehavior.floating,
      padding: EdgeInsets.zero,
      margin: const EdgeInsets.only(bottom: 20, left: 16, right: 16),
      duration: const Duration(seconds: 3),
      content: ZenLiquidGlass(
        borderRadius: 22,
        blurSigma: 22,
        glowColor: accent,
        rimWidth: 1.35,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        surfaceColor: isDark
            ? const Color(0xFF0C1426).withOpacity(0.76)
            : Colors.white.withOpacity(0.84),
        customShadows: [
          BoxShadow(
            color: accent.withOpacity(isDark ? 0.28 : 0.16),
            blurRadius: 22,
            offset: const Offset(0, 6),
          ),
          BoxShadow(
            color: Colors.black.withOpacity(isDark ? 0.42 : 0.10),
            blurRadius: 24,
            offset: const Offset(0, 10),
          ),
        ],
        child: Row(
          children: [
            Container(
              width: 42,
              height: 42,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(14),
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: isError
                      ? [
                          AppColors.roseGlow.withOpacity(0.28),
                          AppColors.roseGlow.withOpacity(0.10),
                        ]
                      : [
                          accent.withOpacity(0.28),
                          zen.primaryAccent.withOpacity(0.12),
                        ],
                ),
                border: Border.all(
                  color: accent.withOpacity(isDark ? 0.50 : 0.35),
                  width: 1.1,
                ),
              ),
              child: Icon(
                isError ? Icons.close_rounded : Icons.check_rounded,
                color: isError
                    ? AppColors.roseGlow
                    : (isDark ? zen.primaryAccent : zen.primary),
                size: 24,
              ),
            )
                .animate()
                .scale(duration: 380.ms, curve: Curves.easeOutBack)
                .rotate(
                  begin: -0.35,
                  end: 0,
                  duration: 380.ms,
                  curve: Curves.easeOutBack,
                ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      fontWeight: FontWeight.w800,
                      fontSize: 15,
                      letterSpacing: -0.2,
                      color: isError
                          ? (isDark
                              ? const Color(0xFFFDA4AF)
                              : const Color(0xFFBE123C))
                          : (isDark ? AppColors.darkText : zen.primary),
                    ),
                  ),
                  if (message.isNotEmpty) ...[
                    const SizedBox(height: 3),
                    Text(
                      message,
                      style: TextStyle(
                        fontSize: 13.5,
                        color: isDark
                            ? AppColors.darkTextMuted
                            : AppColors.lightTextMuted,
                        height: 1.32,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ).animate().slideY(
            begin: 0.85,
            end: 0,
            duration: 280.ms,
            curve: Curves.easeOutQuart,
          ),
    ),
  );
}

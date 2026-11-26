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
  final bool disableAnimations =
      MediaQuery.maybeDisableAnimationsOf(context) ?? false;
  final zen = context.zenColors;
  final Color accent = isError ? zen.danger : zen.primary;

  final Widget toastCard = ZenLiquidGlass(
    borderRadius: 22,
    blurSigma: 12.0,
    surfaceMode: ZenGlassSurfaceMode.frostedBlur,
    glowColor: accent,
    rimWidth: 0.8,
    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
    surfaceColor: isDark
        ? const Color(0xFF0D1424).withValues(alpha: 0.78)
        : Colors.white.withValues(alpha: 0.80),
    customShadows: [
      BoxShadow(
        color: Colors.black.withValues(alpha: isDark ? 0.24 : 0.08),
        blurRadius: 18,
        offset: const Offset(0, 8),
      ),
    ],
    child: Row(
      children: [
        Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(13),
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: isError
                  ? [
                      zen.danger.withValues(alpha: 0.18),
                      zen.danger.withValues(alpha: 0.07),
                    ]
                  : [
                      accent.withValues(alpha: 0.18),
                      zen.primaryAccent.withValues(alpha: 0.08),
                    ],
            ),
            border: Border.all(
              color: accent.withValues(alpha: isDark ? 0.28 : 0.22),
              width: 0.9,
            ),
          ),
          child: Icon(
            isError ? Icons.close_rounded : Icons.check_rounded,
            color: isError
                ? zen.danger
                : (isDark ? zen.primaryAccent : zen.primary),
            size: 22,
          ),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
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
                  maxLines: 3,
                  overflow: TextOverflow.ellipsis,
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
  );

  final Widget animatedToast = disableAnimations
      ? toastCard
      : toastCard
          .animate()
          .fadeIn(duration: 180.ms, curve: Curves.easeOutCubic)
          .slideY(
            begin: 0.35,
            end: 0,
            duration: 220.ms,
            curve: Curves.easeOutCubic,
          );

  ScaffoldMessenger.of(context).hideCurrentSnackBar();
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(
      backgroundColor: Colors.transparent,
      elevation: 0,
      behavior: SnackBarBehavior.floating,
      padding: EdgeInsets.zero,
      margin: const EdgeInsets.only(bottom: 20, left: 16, right: 16),
      duration: const Duration(seconds: 3),
      content: animatedToast,
    ),
  );
}

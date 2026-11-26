import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:zenhome_app/core/theme/app_theme.dart';
import 'package:zenhome_app/core/widgets/zen_liquid_glass.dart';

class NotificationBadge extends StatelessWidget {
  final int unreadCount;
  final VoidCallback onPressed;
  final double blurSigma;
  final ZenGlassSurfaceMode surfaceMode;

  const NotificationBadge({
    super.key,
    required this.unreadCount,
    required this.onPressed,
    this.blurSigma = 0.0,
    this.surfaceMode = ZenGlassSurfaceMode.tintedGlass,
  });

  const NotificationBadge.lightweight({
    super.key,
    required this.unreadCount,
    required this.onPressed,
  })  : blurSigma = 0.0,
        surfaceMode = ZenGlassSurfaceMode.tintedGlass;

  @override
  Widget build(BuildContext context) {
    final bool isDark = Theme.of(context).brightness == Brightness.dark;
    final zen = context.zenColors;
    final bool hasUnread = unreadCount > 0;

    return Stack(
      clipBehavior: Clip.none,
      children: [
        ZenLiquidGlass(
          width: 44,
          height: 44,
          borderRadius: 16,
          blurSigma: blurSigma,
          surfaceMode: surfaceMode,
          rimWidth: 0.8,
          glowColor: hasUnread ? zen.danger : zen.primary,
          surfaceColor: isDark
              ? Colors.white.withValues(alpha: 0.07)
              : Colors.white.withValues(alpha: 0.72),
          alignment: Alignment.center,
          onTap: () {
            HapticFeedback.selectionClick();
            onPressed();
          },
          child: Icon(
            hasUnread
                ? Icons.notifications_active_rounded
                : Icons.notifications_none_rounded,
            size: 22,
            color: hasUnread
                ? (isDark ? Colors.white : zen.primary)
                : (isDark ? AppColors.darkText : AppColors.lightText),
          ),
        ),
        if (hasUnread)
          Positioned(
            right: -3,
            top: -3,
            child: IgnorePointer(
              child: Container(
                constraints: const BoxConstraints(minWidth: 19, minHeight: 19),
                padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  gradient: zen.dangerGradient,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: isDark ? AppColors.darkBg : Colors.white,
                    width: 1.2,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: zen.danger.withValues(alpha: 0.22),
                      blurRadius: 6,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Text(
                  unreadCount > 9 ? '9+' : unreadCount.toString(),
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 10,
                    fontWeight: FontWeight.w800,
                    height: 1.1,
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }
}

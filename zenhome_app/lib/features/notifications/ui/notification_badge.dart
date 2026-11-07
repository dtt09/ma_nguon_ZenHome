import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:zenhome_app/core/theme/app_theme.dart';
import 'package:zenhome_app/core/widgets/zen_liquid_glass.dart';

class NotificationBadge extends StatelessWidget {
  final int unreadCount;
  final VoidCallback onPressed;

  const NotificationBadge({
    super.key,
    required this.unreadCount,
    required this.onPressed,
  });

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
          blurSigma: 16,
          glowColor: hasUnread ? AppColors.roseGlow : zen.primary,
          surfaceColor: isDark
              ? Colors.white.withOpacity(0.08)
              : Colors.white.withOpacity(0.70),
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
                  gradient: const LinearGradient(
                    colors: [Color(0xFFE11D48), Color(0xFFF43F5E)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: isDark ? AppColors.darkBg : Colors.white,
                    width: 1.5,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: AppColors.roseGlow.withOpacity(0.55),
                      blurRadius: 8,
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

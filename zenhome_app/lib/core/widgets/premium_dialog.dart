import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:zenhome_app/core/utils/localization_extension.dart';

import 'package:zenhome_app/core/utils/haptic_helper.dart';

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
  }
  return showGeneralDialog<bool>(
    context: context,
    barrierDismissible: true,
    barrierLabel: '',
    barrierColor: Colors.black.withOpacity(0.6),
    transitionDuration: const Duration(milliseconds: 300),
    pageBuilder: (ctx, anim1, anim2) => const SizedBox(),
    transitionBuilder: (ctx, anim1, anim2, child) {
      bool isDark = Theme.of(context).brightness == Brightness.dark;
      Color confirmColor = isDanger ? Colors.redAccent : (isDark ? const Color(0xFF5C8CFF) : const Color(0xFF2A3A7C));
      Color iconColor = isDanger ? Colors.redAccent : (isDark ? const Color(0xFF5C8CFF) : const Color(0xFF2A3A7C));

      return Transform.scale(
        scale: 0.8 + (anim1.value * 0.2),
        child: Opacity(
          opacity: anim1.value,
          child: AlertDialog(
            backgroundColor: Colors.transparent,
            contentPadding: EdgeInsets.zero,
            elevation: 0,
            content: ClipRRect(
              borderRadius: BorderRadius.circular(28),
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
                child: Container(
                  width: double.maxFinite,
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    color: isDark ? const Color(0xFF1A2235).withOpacity(0.8) : Colors.white.withOpacity(0.9),
                    borderRadius: BorderRadius.circular(28),
                    border: Border.all(color: isDark ? Colors.white.withOpacity(0.1) : Colors.black.withOpacity(0.05)),
                    boxShadow: [
                      BoxShadow(color: Colors.black.withOpacity(0.2), blurRadius: 24, offset: const Offset(0, 10))
                    ],
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (icon != null) ...[
                        Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: iconColor.withOpacity(0.15),
                            shape: BoxShape.circle,
                          ),
                          child: Icon(icon, size: 32, color: iconColor),
                        ).animate().scale(delay: 200.ms, duration: 300.ms, curve: Curves.easeOutBack),
                        const SizedBox(height: 16),
                      ],
                      Text(
                        title,
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: isDark ? Colors.white : Colors.black87,
                        ),
                      ).animate().slideY(begin: 0.2, end: 0),
                      const SizedBox(height: 12),
                      Text(
                        message,
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 15,
                          height: 1.4,
                          color: isDark ? Colors.white70 : Colors.black54,
                        ),
                      ).animate().slideY(begin: 0.2, end: 0),
                      const SizedBox(height: 30),
                      Row(
                        children: [
                          Expanded(
                            child: FilledButton(
                              style: FilledButton.styleFrom(
                                backgroundColor: isDark ? Colors.white.withOpacity(0.1) : Colors.black.withOpacity(0.05),
                                foregroundColor: isDark ? Colors.white : Colors.black87,
                                padding: const EdgeInsets.symmetric(vertical: 14),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                                elevation: 0,
                              ),
                              onPressed: () => Navigator.of(ctx).pop(false),
                              child: Text(cancelText, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: FilledButton(
                              style: FilledButton.styleFrom(
                                backgroundColor: confirmColor,
                                foregroundColor: Colors.white,
                                padding: const EdgeInsets.symmetric(vertical: 14),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                                elevation: 0,
                              ),
                              onPressed: () {
                                onConfirm();
                                Navigator.of(ctx).pop(true);
                              },
                              child: Text(confirmText, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
                            ),
                          ),
                        ],
                      ).animate().slideY(begin: 0.2, end: 0),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      );
    },
  );
}

import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:zenhome_app/core/utils/haptic_helper.dart';

void showFloatingToast(BuildContext context, String title, String message, {bool isError = false}) {
  if (isError) {
    HapticHelper.errorVibrate();
  } else {
    HapticHelper.medium();
  }

  bool isDark = Theme.of(context).brightness == Brightness.dark;

  ScaffoldMessenger.of(context).hideCurrentSnackBar();
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(
      backgroundColor: Colors.transparent,
      elevation: 0,
      behavior: SnackBarBehavior.floating,
      margin: const EdgeInsets.only(bottom: 20, left: 16, right: 16),
      duration: const Duration(seconds: 3),
      content: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF121827) : Colors.white,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.15),
              blurRadius: 20,
              offset: const Offset(0, 10),
            )
          ],
          border: Border.all(
            color: isError ? Colors.red.withOpacity(0.3) : const Color(0xFF2A3A7C).withOpacity(0.3),
            width: 1.5,
          ),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: const BoxDecoration(
                color: Colors.transparent,
                shape: BoxShape.circle,
              ),
              child: Icon(
                isError ? Icons.close_rounded : Icons.check_rounded,
                color: isError ? Colors.red : Colors.green,
                size: 28,
              ),
            ).animate().scale(duration: 400.ms, curve: Curves.easeOutBack).rotate(begin: -0.5, end: 0, duration: 400.ms, curve: Curves.easeOutBack),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                      color: isError 
                          ? (isDark ? Colors.red.shade300 : Colors.red.shade800) 
                          : (isDark ? Colors.white : const Color(0xFF2A3A7C)),
                    ),
                  ),
                  if (message.isNotEmpty) const SizedBox(height: 4),
                  if (message.isNotEmpty)
                    Text(
                      message,
                      style: TextStyle(
                        fontSize: 14,
                        color: isDark ? Colors.white70 : Colors.grey.shade700,
                        height: 1.3,
                      ),
                    ),
                ],
              ),
            ),
          ],
        ),
      ).animate().slideY(begin: 1, end: 0, duration: 300.ms, curve: Curves.easeOutQuart),
    ),
  );
}
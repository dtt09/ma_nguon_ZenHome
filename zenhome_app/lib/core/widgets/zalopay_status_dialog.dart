import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:zenhome_app/core/theme/app_theme.dart';
import 'package:zenhome_app/core/utils/haptic_helper.dart';

enum ZaloPayStatusType {
  success,
  error,
  warning,
  caution,
}

class ZaloPayStatusDialog extends StatelessWidget {
  final ZaloPayStatusType type;
  final String title;
  final String message;
  final Map<String, String>? details;
  final String? primaryButtonText;
  final String? secondaryButtonText;
  final VoidCallback? onPrimaryPressed;
  final VoidCallback? onSecondaryPressed;

  const ZaloPayStatusDialog({
    super.key,
    required this.type,
    required this.title,
    required this.message,
    this.details,
    this.primaryButtonText,
    this.secondaryButtonText,
    this.onPrimaryPressed,
    this.onSecondaryPressed,
  });

  Color _getMainColor() {
    switch (type) {
      case ZaloPayStatusType.success:
        return const Color(0xFF10B981);
      case ZaloPayStatusType.error:
        return const Color(0xFFEF4444);
      case ZaloPayStatusType.warning:
        return const Color(0xFFF59E0B);
      case ZaloPayStatusType.caution:
        return const Color(0xFFEA580C);
    }
  }

  LinearGradient _getGradient() {
    switch (type) {
      case ZaloPayStatusType.success:
        return const LinearGradient(
          colors: [Color(0xFF059669), Color(0xFF10B981), Color(0xFF34D399)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        );
      case ZaloPayStatusType.error:
        return const LinearGradient(
          colors: [Color(0xFFDC2626), Color(0xFFEF4444), Color(0xFFF87171)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        );
      case ZaloPayStatusType.warning:
      case ZaloPayStatusType.caution:
        return const LinearGradient(
          colors: [Color(0xFFD97706), Color(0xFFF59E0B), Color(0xFFFBBF24)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        );
    }
  }

  IconData _getIcon() {
    switch (type) {
      case ZaloPayStatusType.success:
        return Icons.check_rounded;
      case ZaloPayStatusType.error:
        return Icons.close_rounded;
      case ZaloPayStatusType.warning:
        return Icons.priority_high_rounded;
      case ZaloPayStatusType.caution:
        return Icons.warning_amber_rounded;
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final mainColor = _getMainColor();
    final gradient = _getGradient();

    return BackdropFilter(
      filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
      child: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
          child: Material(
            color: Colors.transparent,
            child: Container(
              constraints: const BoxConstraints(maxWidth: 400),
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF0F172A) : Colors.white,
                borderRadius: BorderRadius.circular(28),
                border: Border.all(
                  color: isDark ? mainColor.withOpacity(0.3) : mainColor.withOpacity(0.2),
                  width: 1.5,
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(isDark ? 0.5 : 0.12),
                    blurRadius: 36,
                    offset: const Offset(0, 14),
                  ),
                  BoxShadow(
                    color: mainColor.withOpacity(isDark ? 0.2 : 0.08),
                    blurRadius: 24,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(28),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Top Accent Glow Bar
                    Container(
                      height: 5,
                      width: double.infinity,
                      decoration: BoxDecoration(gradient: gradient),
                    ),

                    Padding(
                      padding: const EdgeInsets.fromLTRB(24, 28, 24, 24),
                      child: Column(
                        children: [
                          // Animated Concentric Hero Badge (ZaloPay style)
                          Stack(
                            alignment: Alignment.center,
                            children: [
                              // Outer ripple circle 1
                              Container(
                                width: 92,
                                height: 92,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  color: mainColor.withOpacity(0.12),
                                ),
                              )
                                  .animate(onPlay: (c) => c.repeat(reverse: true))
                                  .scale(begin: const Offset(0.9, 0.9), end: const Offset(1.15, 1.15), duration: 1800.ms, curve: Curves.easeInOut),

                              // Outer circle 2
                              Container(
                                width: 76,
                                height: 76,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  color: mainColor.withOpacity(0.22),
                                ),
                              ),

                              // Inner solid core with icon
                              Container(
                                width: 58,
                                height: 58,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  gradient: gradient,
                                  boxShadow: [
                                    BoxShadow(
                                      color: mainColor.withOpacity(0.45),
                                      blurRadius: 16,
                                      offset: const Offset(0, 6),
                                    ),
                                  ],
                                ),
                                child: Icon(
                                  _getIcon(),
                                  size: 34,
                                  color: Colors.white,
                                ),
                              )
                                  .animate()
                                  .scale(duration: 500.ms, curve: Curves.elasticOut)
                                  .rotate(begin: -0.2, end: 0, duration: 500.ms, curve: Curves.elasticOut),
                            ],
                          ),

                          const SizedBox(height: 22),

                          // Title
                          Text(
                            title,
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontSize: 21,
                              fontWeight: FontWeight.w800,
                              letterSpacing: -0.4,
                              color: isDark ? Colors.white : const Color(0xFF0F172A),
                            ),
                          ).animate().fadeIn(duration: 300.ms).slideY(begin: 0.1, end: 0),

                          const SizedBox(height: 10),

                          // Message description
                          Text(
                            message,
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontSize: 14,
                              height: 1.45,
                              color: isDark ? Colors.grey.shade300 : const Color(0xFF475569),
                            ),
                          ).animate().fadeIn(delay: 100.ms, duration: 300.ms),

                          // Details receipt card (if present)
                          if (details != null && details!.isNotEmpty) ...[
                            const SizedBox(height: 20),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                              decoration: BoxDecoration(
                                color: isDark ? const Color(0xFF1E293B).withOpacity(0.7) : const Color(0xFFF8FAFC),
                                borderRadius: BorderRadius.circular(16),
                                border: Border.all(
                                  color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0),
                                ),
                              ),
                              child: Column(
                                children: details!.entries.map((entry) {
                                  return Padding(
                                    padding: const EdgeInsets.symmetric(vertical: 6),
                                    child: Row(
                                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        ConstrainedBox(
                                          constraints: const BoxConstraints(maxWidth: 130),
                                          child: Text(
                                            entry.key,
                                            style: TextStyle(
                                              fontSize: 12.5,
                                              fontWeight: FontWeight.w500,
                                              color: isDark ? Colors.grey.shade400 : Colors.grey.shade600,
                                            ),
                                          ),
                                        ),
                                        const SizedBox(width: 12),
                                        Expanded(
                                          child: Text(
                                            entry.value,
                                            textAlign: TextAlign.right,
                                            style: TextStyle(
                                              fontSize: 12.5,
                                              fontWeight: FontWeight.bold,
                                              fontFamily: entry.value.contains(':') && entry.value.contains('-') ? 'monospace' : null,
                                              color: isDark ? Colors.white : const Color(0xFF0F172A),
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  );
                                }).toList(),
                              ),
                            ).animate().fadeIn(delay: 200.ms, duration: 300.ms).scale(begin: const Offset(0.95, 0.95), end: const Offset(1, 1)),
                          ],

                          const SizedBox(height: 26),

                          // Primary Action Button
                          SizedBox(
                            width: double.infinity,
                            height: 50,
                            child: ElevatedButton(
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.transparent,
                                shadowColor: Colors.transparent,
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                                padding: EdgeInsets.zero,
                              ),
                              onPressed: () {
                                HapticHelper.light();
                                Navigator.of(context, rootNavigator: true).pop();
                                onPrimaryPressed?.call();
                              },
                              child: Ink(
                                decoration: BoxDecoration(
                                  gradient: gradient,
                                  borderRadius: BorderRadius.circular(16),
                                  boxShadow: [
                                    BoxShadow(
                                      color: mainColor.withOpacity(0.38),
                                      blurRadius: 14,
                                      offset: const Offset(0, 4),
                                    ),
                                  ],
                                ),
                                child: Container(
                                  alignment: Alignment.center,
                                  child: Text(
                                    primaryButtonText ?? 'Đã hiểu',
                                    style: const TextStyle(
                                      fontSize: 15.5,
                                      fontWeight: FontWeight.bold,
                                      color: Colors.white,
                                      letterSpacing: 0.2,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ),

                          // Optional Secondary Button
                          if (secondaryButtonText != null) ...[
                            const SizedBox(height: 10),
                            SizedBox(
                              width: double.infinity,
                              height: 44,
                              child: TextButton(
                                onPressed: () {
                                  HapticHelper.light();
                                  Navigator.of(context, rootNavigator: true).pop();
                                  onSecondaryPressed?.call();
                                },
                                child: Text(
                                  secondaryButtonText!,
                                  style: TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w600,
                                    color: isDark ? Colors.grey.shade400 : Colors.grey.shade600,
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Helper functions to show rich ZaloPay-style notifications anywhere in the app
Future<void> showZaloPaySuccessDialog(
  BuildContext context, {
  required String title,
  required String message,
  Map<String, String>? details,
  String? buttonText,
  VoidCallback? onDismiss,
}) {
  HapticHelper.heavy();
  return showDialog<void>(
    context: context,
    barrierDismissible: true,
    builder: (ctx) => ZaloPayStatusDialog(
      type: ZaloPayStatusType.success,
      title: title,
      message: message,
      details: details,
      primaryButtonText: buttonText,
      onPrimaryPressed: onDismiss,
    ),
  );
}

Future<void> showZaloPayErrorDialog(
  BuildContext context, {
  required String title,
  required String message,
  Map<String, String>? details,
  String? buttonText,
  VoidCallback? onDismiss,
}) {
  HapticHelper.errorVibrate();
  return showDialog<void>(
    context: context,
    barrierDismissible: true,
    builder: (ctx) => ZaloPayStatusDialog(
      type: ZaloPayStatusType.error,
      title: title,
      message: message,
      details: details,
      primaryButtonText: buttonText ?? 'Đóng',
      onPrimaryPressed: onDismiss,
    ),
  );
}

Future<void> showZaloPayWarningDialog(
  BuildContext context, {
  required String title,
  required String message,
  Map<String, String>? details,
  String? buttonText,
  VoidCallback? onDismiss,
}) {
  HapticHelper.warning();
  return showDialog<void>(
    context: context,
    barrierDismissible: true,
    builder: (ctx) => ZaloPayStatusDialog(
      type: ZaloPayStatusType.warning,
      title: title,
      message: message,
      details: details,
      primaryButtonText: buttonText ?? 'Đã hiểu',
      onPrimaryPressed: onDismiss,
    ),
  );
}

/// Bảng thông báo thận trọng (Caution / Danger Confirmation Modal)
Future<bool> showCautionConfirmDialog(
  BuildContext context, {
  required String title,
  required String warningText,
  String? cautionDetails,
  String confirmText = 'Xác nhận thực hiện',
  String cancelText = 'Hủy bỏ',
  bool isDanger = true,
}) async {
  HapticHelper.warning();
  final isDark = Theme.of(context).brightness == Brightness.dark;
  final accentColor = isDanger ? const Color(0xFFEF4444) : const Color(0xFFF59E0B);

  final result = await showDialog<bool>(
    context: context,
    barrierDismissible: false,
    builder: (ctx) => BackdropFilter(
      filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
      child: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
          child: Material(
            color: Colors.transparent,
            child: Container(
              constraints: const BoxConstraints(maxWidth: 400),
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF0F172A) : Colors.white,
                borderRadius: BorderRadius.circular(26),
                border: Border.all(
                  color: accentColor.withOpacity(0.35),
                  width: 1.5,
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(isDark ? 0.5 : 0.15),
                    blurRadius: 30,
                    offset: const Offset(0, 12),
                  ),
                ],
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(26),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(height: 4, color: accentColor),
                    Padding(
                      padding: const EdgeInsets.fromLTRB(22, 24, 22, 20),
                      child: Column(
                        children: [
                          Container(
                            width: 64,
                            height: 64,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: accentColor.withOpacity(0.12),
                              border: Border.all(color: accentColor.withOpacity(0.3), width: 1.5),
                            ),
                            child: Icon(
                              isDanger ? Icons.warning_amber_rounded : Icons.info_outline_rounded,
                              size: 36,
                              color: accentColor,
                            ),
                          ).animate().scale(duration: 400.ms, curve: Curves.elasticOut),

                          const SizedBox(height: 18),

                          Text(
                            title,
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontSize: 19,
                              fontWeight: FontWeight.w800,
                              color: isDark ? Colors.white : const Color(0xFF0F172A),
                            ),
                          ),

                          const SizedBox(height: 12),

                          Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: accentColor.withOpacity(0.08),
                              borderRadius: BorderRadius.circular(14),
                              border: Border.all(color: accentColor.withOpacity(0.2)),
                            ),
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Icon(Icons.shield_outlined, size: 18, color: accentColor),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    warningText,
                                    style: TextStyle(
                                      fontSize: 13,
                                      height: 1.45,
                                      color: isDark ? Colors.grey.shade200 : const Color(0xFF1E293B),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),

                          if (cautionDetails != null) ...[
                            const SizedBox(height: 12),
                            Text(
                              cautionDetails,
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                fontSize: 12.5,
                                color: isDark ? Colors.grey.shade400 : Colors.grey.shade600,
                                height: 1.4,
                              ),
                            ),
                          ],

                          const SizedBox(height: 24),

                          Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              SizedBox(
                                width: double.infinity,
                                height: 48,
                                child: ElevatedButton(
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: accentColor,
                                    foregroundColor: Colors.white,
                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                                    elevation: 2,
                                  ),
                                  onPressed: () {
                                    HapticHelper.medium();
                                    Navigator.pop(ctx, true);
                                  },
                                  child: Text(
                                    confirmText,
                                    textAlign: TextAlign.center,
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(fontWeight: FontWeight.bold),
                                  ),
                                ),
                              ),
                              const SizedBox(height: 10),
                              SizedBox(
                                width: double.infinity,
                                height: 44,
                                child: OutlinedButton(
                                  style: OutlinedButton.styleFrom(
                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                                    side: BorderSide(
                                      color: isDark ? Colors.grey.shade700 : Colors.grey.shade300,
                                    ),
                                  ),
                                  onPressed: () {
                                    HapticHelper.light();
                                    Navigator.pop(ctx, false);
                                  },
                                  child: Text(
                                    cancelText,
                                    textAlign: TextAlign.center,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: TextStyle(
                                      fontWeight: FontWeight.w600,
                                      color: isDark ? Colors.grey.shade300 : Colors.grey.shade700,
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    ),
  );

  return result == true;
}

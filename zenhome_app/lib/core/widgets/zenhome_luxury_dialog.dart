import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:zenhome_app/core/theme/app_theme.dart';
import 'package:zenhome_app/core/utils/haptic_helper.dart';
import 'package:zenhome_app/core/widgets/zen_liquid_glass.dart';

/// Các phân loại thông báo trạng thái của ZenHome
enum ZenHomeStatusType {
  success,
  error,
  warning,
  caution,
}

/// Bảng thông báo trạng thái Liquid Glass 2.0 chuẩn ZenHome
class ZenHomeLuxuryDialog extends StatelessWidget {
  final ZenHomeStatusType type;
  final String title;
  final String message;
  final Map<String, String>? details;
  final String? primaryButtonText;
  final String? secondaryButtonText;
  final VoidCallback? onPrimaryPressed;
  final VoidCallback? onSecondaryPressed;

  const ZenHomeLuxuryDialog({
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

  Color _getPrimaryColor() {
    switch (type) {
      case ZenHomeStatusType.success:
        return const Color(0xFF10B981);
      case ZenHomeStatusType.error:
        return const Color(0xFFF43F5E);
      case ZenHomeStatusType.warning:
        return const Color(0xFFF59E0B);
      case ZenHomeStatusType.caution:
        return const Color(0xFFFF7A00);
    }
  }

  LinearGradient _getAccentGradient() {
    switch (type) {
      case ZenHomeStatusType.success:
        return const LinearGradient(
          colors: [Color(0xFF059669), Color(0xFF10B981), Color(0xFF34D399)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        );
      case ZenHomeStatusType.error:
        return const LinearGradient(
          colors: [Color(0xFFE11D48), Color(0xFFF43F5E), Color(0xFFFB7185)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        );
      case ZenHomeStatusType.warning:
      case ZenHomeStatusType.caution:
        return const LinearGradient(
          colors: [Color(0xFFD97706), Color(0xFFF59E0B), Color(0xFFFCD34D)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        );
    }
  }

  IconData _getIconData() {
    switch (type) {
      case ZenHomeStatusType.success:
        return Icons.check_circle_outline_rounded;
      case ZenHomeStatusType.error:
        return Icons.highlight_off_rounded;
      case ZenHomeStatusType.warning:
        return Icons.warning_amber_rounded;
      case ZenHomeStatusType.caution:
        return Icons.shield_outlined;
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final primaryColor = _getPrimaryColor();
    final gradient = _getAccentGradient();

    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
        child: Material(
          color: Colors.transparent,
          child: ZenGlassDialogSurface(
            accentColor: primaryColor,
            maxWidth: 390,
            padding: EdgeInsets.zero,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Thanh ánh sáng đỉnh đầu (Accent Horizon Bar)
                Container(
                  height: 4,
                  width: double.infinity,
                  decoration: BoxDecoration(gradient: gradient),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(24, 26, 24, 24),
                  child: Column(
                    children: [
                      Stack(
                        alignment: Alignment.center,
                        children: [
                          Container(
                            width: 82,
                            height: 82,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: primaryColor.withOpacity(isDark ? 0.16 : 0.12),
                            ),
                          )
                              .animate(onPlay: (c) => c.repeat(reverse: true))
                              .scale(
                                begin: const Offset(0.92, 0.92),
                                end: const Offset(1.12, 1.12),
                                duration: 2000.ms,
                                curve: Curves.easeInOut,
                              ),
                          Container(
                            width: 62,
                            height: 62,
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(20),
                              gradient: gradient,
                              boxShadow: [
                                BoxShadow(
                                  color: primaryColor.withOpacity(0.42),
                                  blurRadius: 18,
                                  offset: const Offset(0, 6),
                                ),
                              ],
                            ),
                            child: Icon(
                              _getIconData(),
                              size: 34,
                              color: Colors.white,
                            ),
                          ).animate().scale(duration: 450.ms, curve: Curves.easeOutBack),
                        ],
                      ),
                      const SizedBox(height: 20),
                      Text(
                        title,
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.w800,
                          letterSpacing: -0.3,
                          color: isDark ? AppColors.darkText : AppColors.lightText,
                        ),
                      ).animate().fadeIn(duration: 250.ms).slideY(begin: 0.1, end: 0),
                      const SizedBox(height: 10),
                      Text(
                        message,
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 13.8,
                          height: 1.48,
                          color: isDark ? const Color(0xFFCBD5E1) : const Color(0xFF334155),
                        ),
                      ).animate().fadeIn(delay: 80.ms, duration: 250.ms),
                      if (details != null && details!.isNotEmpty) ...[
                        const SizedBox(height: 18),
                        ZenLiquidGlass(
                          blurSigma: 0,
                          borderRadius: 16,
                          padding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 12,
                          ),
                          surfaceColor: isDark
                              ? Colors.white.withOpacity(0.06)
                              : Colors.white.withOpacity(0.65),
                          child: Column(
                            children: details!.entries.map((entry) {
                              return Padding(
                                padding: const EdgeInsets.symmetric(vertical: 5),
                                child: Row(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    SizedBox(
                                      width: 105,
                                      child: Text(
                                        entry.key,
                                        style: TextStyle(
                                          fontSize: 12,
                                          fontWeight: FontWeight.w500,
                                          color: isDark
                                              ? AppColors.darkTextMuted
                                              : AppColors.lightTextMuted,
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    Expanded(
                                      child: Text(
                                        entry.value,
                                        textAlign: TextAlign.right,
                                        softWrap: true,
                                        style: TextStyle(
                                          fontSize: 12,
                                          fontWeight: FontWeight.w700,
                                          fontFamily: (entry.value.contains(':') &&
                                                      entry.value.contains('-')) ||
                                                  entry.value.length > 18
                                              ? 'monospace'
                                              : null,
                                          color: isDark
                                              ? AppColors.darkText
                                              : AppColors.lightText,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              );
                            }).toList(),
                          ),
                        ).animate().fadeIn(delay: 150.ms, duration: 250.ms),
                      ],
                      const SizedBox(height: 24),
                      SizedBox(
                        width: double.infinity,
                        child: ZenGlassButton(
                          label: primaryButtonText ??
                              (type == ZenHomeStatusType.error ? 'Đóng' : 'Đồng ý'),
                          accentColor: primaryColor,
                          onPressed: () {
                            HapticHelper.light();
                            Navigator.of(context, rootNavigator: true).pop();
                            onPrimaryPressed?.call();
                          },
                        ),
                      ),
                      if (secondaryButtonText != null) ...[
                        const SizedBox(height: 10),
                        SizedBox(
                          width: double.infinity,
                          child: ZenGlassButton(
                            label: secondaryButtonText!,
                            isPrimary: false,
                            onPressed: () {
                              HapticHelper.light();
                              Navigator.of(context, rootNavigator: true).pop();
                              onSecondaryPressed?.call();
                            },
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
    );
  }
}

Future<void> showZenHomeSuccessDialog(
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
    barrierColor: Colors.black.withOpacity(0.56),
    builder: (ctx) => ZenHomeLuxuryDialog(
      type: ZenHomeStatusType.success,
      title: title,
      message: message,
      details: details,
      primaryButtonText: buttonText,
      onPrimaryPressed: onDismiss,
    ),
  );
}

Future<void> showZenHomeErrorDialog(
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
    barrierColor: Colors.black.withOpacity(0.56),
    builder: (ctx) => ZenHomeLuxuryDialog(
      type: ZenHomeStatusType.error,
      title: title,
      message: message,
      details: details,
      primaryButtonText: buttonText ?? 'Đóng',
      onPrimaryPressed: onDismiss,
    ),
  );
}

Future<void> showZenHomeWarningDialog(
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
    barrierColor: Colors.black.withOpacity(0.56),
    builder: (ctx) => ZenHomeLuxuryDialog(
      type: ZenHomeStatusType.warning,
      title: title,
      message: message,
      details: details,
      primaryButtonText: buttonText ?? 'Đã hiểu',
      onPrimaryPressed: onDismiss,
    ),
  );
}

/// Hộp thoại xác nhận thận trọng / cảnh báo nguy hiểm (Liquid Glass Caution Modal)
Future<bool> showZenHomeCautionDialog(
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
  final zen = context.zenColors;
  final accentColor = isDanger ? zen.danger : zen.warning;
  final gradient = isDanger ? zen.dangerGradient : zen.warningGradient;

  final result = await showZenGlassDialog<bool>(
    context: context,
    barrierDismissible: false,
    accentColor: accentColor,
    maxWidth: 390,
    padding: EdgeInsets.zero,
    builder: (ctx) => Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          height: 4,
          width: double.infinity,
          decoration: BoxDecoration(gradient: gradient),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(22, 24, 22, 22),
          child: Column(
            children: [
              Container(
                width: 62,
                height: 62,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(20),
                  color: accentColor.withOpacity(0.14),
                  border: Border.all(
                    color: accentColor.withOpacity(0.38),
                    width: 1.5,
                  ),
                ),
                child: Icon(
                  isDanger ? Icons.warning_amber_rounded : Icons.shield_outlined,
                  size: 34,
                  color: accentColor,
                ),
              ).animate().scale(duration: 400.ms, curve: Curves.easeOutBack),
              const SizedBox(height: 18),
              Text(
                title,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 19,
                  fontWeight: FontWeight.w800,
                  color: isDark ? AppColors.darkText : AppColors.lightText,
                ),
              ),
              const SizedBox(height: 12),
              ZenLiquidGlass(
                blurSigma: 0,
                borderRadius: 14,
                glowColor: accentColor,
                padding: const EdgeInsets.all(12),
                surfaceColor: accentColor.withOpacity(isDark ? 0.12 : 0.08),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(Icons.info_outline_rounded, size: 18, color: accentColor),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        warningText,
                        style: TextStyle(
                          fontSize: 13,
                          height: 1.45,
                          color: isDark
                              ? const Color(0xFFCBD5E1)
                              : const Color(0xFF1E293B),
                          fontWeight: FontWeight.w500,
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
                    color: isDark ? AppColors.darkTextMuted : AppColors.lightTextMuted,
                    height: 1.4,
                  ),
                ),
              ],
              const SizedBox(height: 22),
              SizedBox(
                width: double.infinity,
                child: ZenGlassButton(
                  label: confirmText,
                  isDanger: isDanger,
                  accentColor: accentColor,
                  onPressed: () {
                    HapticHelper.medium();
                    Navigator.pop(ctx, true);
                  },
                ),
              ),
              const SizedBox(height: 10),
              SizedBox(
                width: double.infinity,
                child: ZenGlassButton(
                  label: cancelText,
                  isPrimary: false,
                  onPressed: () {
                    HapticHelper.light();
                    Navigator.pop(ctx, false);
                  },
                ),
              ),
            ],
          ),
        ),
      ],
    ),
  );

  return result == true;
}

// ==============================================================================
// CÁC HÀM VÀ LỚP BẢO LƯU TƯƠNG THÍCH (BACKWARD COMPATIBILITY ALIASES)
// ==============================================================================
typedef ZaloPayStatusType = ZenHomeStatusType;
typedef ZaloPayStatusDialog = ZenHomeLuxuryDialog;

Future<void> showZaloPaySuccessDialog(
  BuildContext context, {
  required String title,
  required String message,
  Map<String, String>? details,
  String? buttonText,
  VoidCallback? onDismiss,
}) =>
    showZenHomeSuccessDialog(
      context,
      title: title,
      message: message,
      details: details,
      buttonText: buttonText,
      onDismiss: onDismiss,
    );

Future<void> showZaloPayErrorDialog(
  BuildContext context, {
  required String title,
  required String message,
  Map<String, String>? details,
  String? buttonText,
  VoidCallback? onDismiss,
}) =>
    showZenHomeErrorDialog(
      context,
      title: title,
      message: message,
      details: details,
      buttonText: buttonText,
      onDismiss: onDismiss,
    );

Future<void> showZaloPayWarningDialog(
  BuildContext context, {
  required String title,
  required String message,
  Map<String, String>? details,
  String? buttonText,
  VoidCallback? onDismiss,
}) =>
    showZenHomeWarningDialog(
      context,
      title: title,
      message: message,
      details: details,
      buttonText: buttonText,
      onDismiss: onDismiss,
    );

Future<bool> showCautionConfirmDialog(
  BuildContext context, {
  required String title,
  required String warningText,
  String? cautionDetails,
  String confirmText = 'Xác nhận thực hiện',
  String cancelText = 'Hủy bỏ',
  bool isDanger = true,
}) =>
    showZenHomeCautionDialog(
      context,
      title: title,
      warningText: warningText,
      cautionDetails: cautionDetails,
      confirmText: confirmText,
      cancelText: cancelText,
      isDanger: isDanger,
    );

import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:zenhome_app/core/theme/app_theme.dart';
import 'package:zenhome_app/core/utils/haptic_helper.dart';

/// Các phân loại thông báo trạng thái của ZenHome
enum ZenHomeStatusType {
  success,
  error,
  warning,
  caution,
}

/// Bảng thông báo trạng thái Luxury chuẩn ZenHome (Thay thế hoàn toàn phong cách cũ)
/// Thiết kế kính mờ cao cấp Glassmorphism với viền bo góc đồng bộ, chống tràn chữ và tương phản cao.
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
        return const Color(0xFF10B981); // Emerald
      case ZenHomeStatusType.error:
        return const Color(0xFFF43F5E); // Crimson Ruby
      case ZenHomeStatusType.warning:
        return const Color(0xFFF59E0B); // Imperial Gold / Amber
      case ZenHomeStatusType.caution:
        return const Color(0xFFFF7A00); // Solar Orange
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
          child: Container(
            constraints: const BoxConstraints(maxWidth: 390),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(28),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(isDark ? 0.65 : 0.18),
                  blurRadius: 36,
                  offset: const Offset(0, 16),
                ),
                BoxShadow(
                  color: primaryColor.withOpacity(isDark ? 0.22 : 0.12),
                  blurRadius: 28,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            // Kẹp ClipRRect bên ngoài BackdropFilter: KHÔNG BAO GIỜ BỊ TRÀN VIỀN MỜ
            child: ClipRRect(
              borderRadius: BorderRadius.circular(28),
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
                child: Container(
                  decoration: BoxDecoration(
                    color: isDark ? const Color(0xFF0F172A).withOpacity(0.92) : Colors.white.withOpacity(0.95),
                    borderRadius: BorderRadius.circular(28),
                    border: Border.all(
                      color: isDark ? primaryColor.withOpacity(0.35) : primaryColor.withOpacity(0.25),
                      width: 1.5,
                    ),
                  ),
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
                            // Hero Squircle Icon với hào quang Breathing Aura
                            Stack(
                              alignment: Alignment.center,
                              children: [
                                // Lớp quầng sáng nhịp điệu (Aura Ring)
                                Container(
                                  width: 82,
                                  height: 82,
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    color: primaryColor.withOpacity(isDark ? 0.15 : 0.1),
                                  ),
                                )
                                    .animate(onPlay: (c) => c.repeat(reverse: true))
                                    .scale(begin: const Offset(0.92, 0.92), end: const Offset(1.12, 1.12), duration: 2000.ms, curve: Curves.easeInOut),

                                // Khối Squircle biểu tượng chính
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
                                )
                                    .animate()
                                    .scale(duration: 450.ms, curve: Curves.easeOutBack),
                              ],
                            ),

                            const SizedBox(height: 20),

                            // Tiêu đề thông báo sắc nét, tương phản cao
                            Text(
                              title,
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                fontSize: 20,
                                fontWeight: FontWeight.w800,
                                letterSpacing: -0.3,
                                color: isDark ? Colors.white : const Color(0xFF0F172A),
                              ),
                            ).animate().fadeIn(duration: 250.ms).slideY(begin: 0.1, end: 0),

                            const SizedBox(height: 10),

                            // Mô tả chi tiết chống chìm màu
                            Text(
                              message,
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                fontSize: 13.5,
                                height: 1.48,
                                color: isDark ? const Color(0xFFCBD5E1) : const Color(0xFF334155),
                                fontWeight: FontWeight.w400,
                              ),
                            ).animate().fadeIn(delay: 80.ms, duration: 250.ms),

                            // Khung hiển thị chi tiết (Chống tràn chữ 100%)
                            if (details != null && details!.isNotEmpty) ...[
                              const SizedBox(height: 18),
                              Container(
                                width: double.infinity,
                                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                                decoration: BoxDecoration(
                                  color: isDark ? const Color(0xFF1E293B).withOpacity(0.7) : const Color(0xFFF1F5F9),
                                  borderRadius: BorderRadius.circular(16),
                                  border: Border.all(
                                    color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0),
                                    width: 1,
                                  ),
                                ),
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
                                                color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
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
                                                fontFamily: (entry.value.contains(':') && entry.value.contains('-')) || entry.value.length > 18 ? 'monospace' : null,
                                                color: isDark ? Colors.white : const Color(0xFF0F172A),
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

                            // Nút hành động chính (Luxury Gradient Button)
                            SizedBox(
                              width: double.infinity,
                              height: 48,
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
                                        color: primaryColor.withOpacity(0.35),
                                        blurRadius: 14,
                                        offset: const Offset(0, 4),
                                      ),
                                    ],
                                  ),
                                  child: Container(
                                    alignment: Alignment.center,
                                    child: Text(
                                      primaryButtonText ?? (type == ZenHomeStatusType.error ? 'Đóng' : 'Đồng ý'),
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontSize: 15,
                                        fontWeight: FontWeight.w700,
                                        letterSpacing: -0.2,
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            ),

                            // Nút hành động phụ (nếu có)
                            if (secondaryButtonText != null) ...[
                              const SizedBox(height: 10),
                              SizedBox(
                                width: double.infinity,
                                height: 44,
                                child: OutlinedButton(
                                  style: OutlinedButton.styleFrom(
                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                                    side: BorderSide(
                                      color: isDark ? const Color(0xFF475569) : const Color(0xFFCBD5E1),
                                    ),
                                  ),
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
                                      color: isDark ? const Color(0xFFCBD5E1) : const Color(0xFF475569),
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
      ),
    );
  }
}

// ==============================================================================
// CÁC HÀM TIỆN ÍCH HIỂN THỊ THÔNG BÁO CHUẨN ZENHOME (TOÀN ỨNG DỤNG)
// ==============================================================================

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

/// Hộp thoại xác nhận thận trọng / cảnh báo nguy hiểm (Caution Confirmation Modal)
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
  final accentColor = isDanger ? const Color(0xFFF43F5E) : const Color(0xFFF59E0B);
  final gradient = isDanger
      ? const LinearGradient(colors: [Color(0xFFE11D48), Color(0xFFF43F5E)])
      : const LinearGradient(colors: [Color(0xFFD97706), Color(0xFFF59E0B)]);

  final result = await showDialog<bool>(
    context: context,
    barrierDismissible: false,
    builder: (ctx) => Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
        child: Material(
          color: Colors.transparent,
          child: Container(
            constraints: const BoxConstraints(maxWidth: 390),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(28),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(isDark ? 0.65 : 0.18),
                  blurRadius: 36,
                  offset: const Offset(0, 16),
                ),
              ],
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(28),
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
                child: Container(
                  decoration: BoxDecoration(
                    color: isDark ? const Color(0xFF0F172A).withOpacity(0.92) : Colors.white.withOpacity(0.95),
                    borderRadius: BorderRadius.circular(28),
                    border: Border.all(
                      color: accentColor.withOpacity(0.35),
                      width: 1.5,
                    ),
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(height: 4, width: double.infinity, decoration: BoxDecoration(gradient: gradient)),
                      Padding(
                        padding: const EdgeInsets.fromLTRB(22, 24, 22, 22),
                        child: Column(
                          children: [
                            Container(
                              width: 62,
                              height: 62,
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(20),
                                color: accentColor.withOpacity(0.12),
                                border: Border.all(color: accentColor.withOpacity(0.3), width: 1.5),
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
                                  Icon(Icons.info_outline_rounded, size: 18, color: accentColor),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Text(
                                      warningText,
                                      style: TextStyle(
                                        fontSize: 13,
                                        height: 1.45,
                                        color: isDark ? const Color(0xFFCBD5E1) : const Color(0xFF1E293B),
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
                                  color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                                  height: 1.4,
                                ),
                              ),
                            ],

                            const SizedBox(height: 22),

                            SizedBox(
                              width: double.infinity,
                              height: 48,
                              child: ElevatedButton(
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: accentColor,
                                  foregroundColor: Colors.white,
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                                  elevation: 2,
                                ),
                                onPressed: () {
                                  HapticHelper.medium();
                                  Navigator.pop(ctx, true);
                                },
                                child: Text(
                                  confirmText,
                                  textAlign: TextAlign.center,
                                  style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15),
                                ),
                              ),
                            ),
                            const SizedBox(height: 10),
                            SizedBox(
                              width: double.infinity,
                              height: 44,
                              child: OutlinedButton(
                                style: OutlinedButton.styleFrom(
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                                  side: BorderSide(
                                    color: isDark ? const Color(0xFF475569) : const Color(0xFFCBD5E1),
                                  ),
                                ),
                                onPressed: () {
                                  HapticHelper.light();
                                  Navigator.pop(ctx, false);
                                },
                                child: Text(
                                  cancelText,
                                  style: TextStyle(
                                    fontWeight: FontWeight.w600,
                                    color: isDark ? const Color(0xFFCBD5E1) : const Color(0xFF475569),
                                  ),
                                ),
                              ),
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
    ),
  );

  return result == true;
}

// ==============================================================================
// CÁC HÀM VÀ LỚP BẢO LƯU TƯƠNG THÍCH (BACKWARD COMPATIBILITY ALIASES)
// Giúp toàn bộ mã nguồn cũ chuyển tiếp mượt mà mà không làm vỡ code bất kỳ đâu!
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
}) => showZenHomeSuccessDialog(
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
}) => showZenHomeErrorDialog(
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
}) => showZenHomeWarningDialog(
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
}) => showZenHomeCautionDialog(
  context,
  title: title,
  warningText: warningText,
  cautionDetails: cautionDetails,
  confirmText: confirmText,
  cancelText: cancelText,
  isDanger: isDanger,
);

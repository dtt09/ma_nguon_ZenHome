import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:zenhome_app/core/utils/haptic_helper.dart';
import 'package:zenhome_app/core/utils/localization_extension.dart';

/// Hộp thoại xác thực Mật khẩu Quản trị (Admin Password) dành cho các thao tác bảo mật cao
/// như Hủy liên kết Hub ESP32, Cấu hình lại chân GPIO, Factory Reset.
Future<bool> showAdminPasswordDialog(
  BuildContext context, {
  required String currentAdminPassword,
  String? title,
  String? description,
}) async {
  HapticHelper.warning();
  final isDark = Theme.of(context).brightness == Brightness.dark;

  final result = await showModalBottomSheet<bool>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    barrierColor: Colors.black.withOpacity(0.6),
    builder: (ctx) {
      return _AdminPasswordModalContent(
        isDark: isDark,
        currentAdminPassword: currentAdminPassword,
        title: title ?? context.tr('admin_verify_title'),
        description: description ??
            'Vui lòng nhập mật khẩu quản trị của Hub ESP32 để ủy quyền thao tác hủy liên kết và xóa sạch cấu hình từ xa.',
      );
    },
  );

  return result == true;
}

class _AdminPasswordModalContent extends StatefulWidget {
  final bool isDark;
  final String currentAdminPassword;
  final String title;
  final String description;

  const _AdminPasswordModalContent({
    required this.isDark,
    required this.currentAdminPassword,
    required this.title,
    required this.description,
  });

  @override
  State<_AdminPasswordModalContent> createState() => _AdminPasswordModalContentState();
}

class _AdminPasswordModalContentState extends State<_AdminPasswordModalContent> {
  final TextEditingController _controller = TextEditingController();
  bool _obscure = true;
  String? _errorMessage;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _verify() {
    final entered = _controller.text.trim();
    if (entered.isEmpty) {
      HapticHelper.warning();
      setState(() {
        _errorMessage = context.tr('err_empty_admin_pass');
      });
      return;
    }

    // So khớp với mật khẩu quản trị của Hub (mặc định nếu chưa đặt là 'admin')
    final expected = widget.currentAdminPassword.isNotEmpty ? widget.currentAdminPassword : 'admin';
    if (entered == expected) {
      HapticHelper.medium();
      Navigator.pop(context, true);
    } else {
      HapticHelper.errorVibrate();
      setState(() {
        _errorMessage = context.tr('admin_pass_incorrect');
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;
    final primaryColor = const Color(0xFF0F766E);

    return BackdropFilter(
      filter: ImageFilter.blur(sigmaX: 8, sigmaY: 8),
      child: Container(
        decoration: BoxDecoration(
          color: widget.isDark ? const Color(0xFF101625) : Colors.white,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(30)),
          border: Border.all(
            color: widget.isDark ? Colors.white.withOpacity(0.08) : const Color(0xFFE2E8F0),
            width: 1.5,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.35),
              blurRadius: 30,
              offset: const Offset(0, -8),
            ),
          ],
        ),
        child: SafeArea(
          top: false,
          child: SingleChildScrollView(
            physics: const ClampingScrollPhysics(),
            padding: EdgeInsets.fromLTRB(24, 16, 24, bottomInset > 0 ? bottomInset + 16 : 28),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                // Drag handle pill
                Center(
                  child: Container(
                    width: 44,
                    height: 5,
                    decoration: BoxDecoration(
                      color: (widget.isDark ? Colors.white : Colors.black).withOpacity(0.2),
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                ),
                const SizedBox(height: 20),

                // Hero Badge Icon
                Container(
                  width: 68,
                  height: 68,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: const LinearGradient(
                      colors: [Color(0xFF0F766E), Color(0xFF0D9488), Color(0xFF14B8A6)],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: primaryColor.withOpacity(0.35),
                        blurRadius: 16,
                        offset: const Offset(0, 6),
                      ),
                    ],
                  ),
                  child: const Icon(Icons.admin_panel_settings_rounded, color: Colors.white, size: 36),
                ).animate().scale(duration: 400.ms, curve: Curves.elasticOut),

                const SizedBox(height: 18),

                // Title
                Text(
                  widget.title,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w800,
                    letterSpacing: -0.3,
                    color: widget.isDark ? Colors.white : const Color(0xFF0F172A),
                  ),
                ),

                const SizedBox(height: 8),

                // Description
                Text(
                  widget.description,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 13.5,
                    height: 1.45,
                    color: widget.isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                  ),
                ),

                const SizedBox(height: 22),

                // Password Input Field
                TextField(
                  controller: _controller,
                  obscureText: _obscure,
                  autofocus: true,
                  textInputAction: TextInputAction.done,
                  onSubmitted: (_) => _verify(),
                  onChanged: (_) {
                    if (_errorMessage != null) {
                      setState(() => _errorMessage = null);
                    }
                  },
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: widget.isDark ? Colors.white : const Color(0xFF0F172A),
                  ),
                  decoration: InputDecoration(
                    labelText: context.tr('wifi_admin_pass_hint'),
                    hintText: 'Nhập mật khẩu quản trị (Mặc định: admin)',
                    hintStyle: TextStyle(
                      fontSize: 13,
                      color: widget.isDark ? Colors.grey.shade600 : Colors.grey.shade400,
                    ),
                    errorText: _errorMessage,
                    errorMaxLines: 2,
                    prefixIcon: const Icon(Icons.lock_outline_rounded, color: Color(0xFF0F766E)),
                    suffixIcon: IconButton(
                      icon: Icon(
                        _obscure ? Icons.visibility_off_rounded : Icons.visibility_rounded,
                        color: widget.isDark ? Colors.grey.shade400 : Colors.grey.shade600,
                      ),
                      onPressed: () => setState(() => _obscure = !_obscure),
                    ),
                    filled: true,
                    fillColor: widget.isDark ? const Color(0xFF090D16) : const Color(0xFFF8FAFC),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(16),
                      borderSide: BorderSide(
                        color: widget.isDark ? Colors.white.withOpacity(0.12) : const Color(0xFFE2E8F0),
                      ),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(16),
                      borderSide: BorderSide(
                        color: widget.isDark ? Colors.white.withOpacity(0.12) : const Color(0xFFE2E8F0),
                      ),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(16),
                      borderSide: const BorderSide(color: Color(0xFF0F766E), width: 1.8),
                    ),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 15),
                  ),
                ),

                const SizedBox(height: 22),

                // Confirm Button (Full Width, never overflows)
                SizedBox(
                  width: double.infinity,
                  height: 50,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: primaryColor,
                      foregroundColor: Colors.white,
                      elevation: 2,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                    ),
                    onPressed: _verify,
                    child: Text(
                      context.tr('btn_confirm'),
                      style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
                    ),
                  ),
                ),

                const SizedBox(height: 10),

                // Cancel Button
                SizedBox(
                  width: double.infinity,
                  height: 44,
                  child: TextButton(
                    onPressed: () {
                      HapticHelper.light();
                      Navigator.pop(context, false);
                    },
                    child: Text(
                      context.tr('btn_cancel'),
                      style: TextStyle(
                        fontSize: 14.5,
                        fontWeight: FontWeight.w600,
                        color: widget.isDark ? Colors.grey.shade400 : Colors.grey.shade600,
                      ),
                    ),
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

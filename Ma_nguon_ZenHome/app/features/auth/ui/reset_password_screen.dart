import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:firebase_auth/firebase_auth.dart';

import 'package:zenhome_app/core/utils/localization_extension.dart';
import 'package:zenhome_app/core/utils/toast_helper.dart';
import 'package:zenhome_app/core/widgets/animations/dual_layer_screen_wrapper.dart';
import 'package:zenhome_app/core/widgets/loading_overlay.dart';
import 'package:zenhome_app/features/auth/ui/login_screen.dart';

class ResetPasswordScreen extends ConsumerStatefulWidget {
  final String phoneNumber;
  final String uid;

  const ResetPasswordScreen({
    super.key,
    required this.phoneNumber,
    required this.uid,
  });

  @override
  ConsumerState<ResetPasswordScreen> createState() => _ResetPasswordScreenState();
}

class _ResetPasswordScreenState extends ConsumerState<ResetPasswordScreen> {
  final TextEditingController _passwordController = TextEditingController();
  final TextEditingController _confirmPasswordController = TextEditingController();
  final FocusNode _passwordFocus = FocusNode();
  final FocusNode _confirmPasswordFocus = FocusNode();
  
  bool _obscurePassword = true;
  bool _obscureConfirmPassword = true;

  bool _hasMinLength = false;
  bool _hasUppercase = false;
  bool _hasLowercase = false;
  bool _hasNumber = false;
  bool _hasSpecialChar = false;

  void _checkPasswordStrength(String password) {
    setState(() {
      _hasMinLength = password.length >= 8;
      _hasUppercase = password.contains(RegExp(r'[A-Z]'));
      _hasLowercase = password.contains(RegExp(r'[a-z]'));
      _hasNumber = password.contains(RegExp(r'[0-9]'));
      _hasSpecialChar = password.contains(RegExp(r'[!@#\$%^&*(),.?":{}|<>]'));
    });
  }

  Widget _buildRequirement(String text, bool isMet, Color baseColor, bool isTopLayer) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        children: [
          Icon(
            isMet ? Icons.check_circle : Icons.cancel,
            color: isMet ? Colors.green : (isTopLayer ? Colors.white54 : baseColor.withOpacity(0.5)),
            size: 16,
          ),
          const SizedBox(width: 8),
          Text(
            text,
            style: TextStyle(
              color: isMet ? Colors.green : (isTopLayer ? Colors.white70 : baseColor.withOpacity(0.8)),
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }

  @override
  void initState() {
    super.initState();
    _passwordFocus.addListener(() { if (mounted) setState(() {}); });
    _confirmPasswordFocus.addListener(() { if (mounted) setState(() {}); });
  }

  @override
  void dispose() {
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    _passwordFocus.dispose();
    _confirmPasswordFocus.dispose();
    super.dispose();
  }

  void _handleResetPassword() async {
    final String password = _passwordController.text;
    final String confirmPassword = _confirmPasswordController.text;

    if (password.isEmpty || confirmPassword.isEmpty) {
      showFloatingToast(context, context.tr('error') ?? 'Lỗi', context.tr('err_empty_field') ?? 'Vui lòng nhập đầy đủ thông tin!', isError: true);
      return;
    }

    if (password != confirmPassword) {
      showFloatingToast(context, context.tr('error') ?? 'Lỗi', context.tr('err_pass_mismatch') ?? 'Mật khẩu xác nhận không khớp!', isError: true);
      return;
    }
    if (!_hasMinLength || !_hasUppercase || !_hasLowercase || !_hasNumber || !_hasSpecialChar) {
      showFloatingToast(context, context.tr('error') ?? 'Lỗi', context.tr('err_firebase_weak_password') ?? 'Mật khẩu chưa đạt đủ các yêu cầu bảo mật!', isError: true);
      return;
    }

    LoadingOverlay.show(context);
    try {
      final currentUser = FirebaseAuth.instance.currentUser;
      if (currentUser != null && currentUser.uid == widget.uid) {
         // Người dùng đã đăng nhập bằng Phone Provider qua OTP
         await currentUser.updatePassword(password);
         
         // Liên kết với Email Provider (nếu chưa có)
         final String dummyEmail = '${widget.phoneNumber.replaceAll('+', '')}@zenhome.local';
         try {
             final cred = EmailAuthProvider.credential(email: dummyEmail, password: password);
             await currentUser.linkWithCredential(cred);
         } catch (e) {
             // Bỏ qua nếu đã liên kết từ trước
         }
      }

      LoadingOverlay.hide();
      if (mounted) {
        showFloatingToast(context, context.tr('toast_success') ?? 'Thành công', context.tr('password_updated_success') ?? 'Đổi mật khẩu thành công! Hãy đăng nhập lại.');
        FirebaseAuth.instance.signOut();
        Navigator.pushAndRemoveUntil(context, MaterialPageRoute(builder: (context) => const LoginScreen()), (r) => false);
      }
    } catch (e) {
      LoadingOverlay.hide();
      showFloatingToast(context, context.tr('error') ?? 'Lỗi', '${context.tr('err_generic') ?? "Đã xảy ra lỗi"}: $e', isError: true);
    }
  }

  Widget _buildContent(BuildContext context, bool isTopLayer, ScrollController controller) {
    bool isDark = Theme.of(context).brightness == Brightness.dark;
    Color color = isTopLayer ? Colors.white : (isDark ? const Color(0xFF5C8CFF) : const Color(0xFF2A3A7C));

    int strengthScore = (_hasMinLength ? 1 : 0) +
        (_hasUppercase ? 1 : 0) +
        (_hasLowercase ? 1 : 0) +
        (_hasNumber ? 1 : 0) +
        (_hasSpecialChar ? 1 : 0);
    double strengthPercent = strengthScore / 5;
    Color strengthColor = strengthPercent <= 0.4 ? Colors.red : (strengthPercent <= 0.8 ? Colors.orange : Colors.green);

    return SafeArea(
      bottom: false,
      child: Column(
        children: [
          const SizedBox(height: 20),
          Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Image.asset('public/zenhome_logo_transparent.png', width: 60, height: 60, fit: BoxFit.contain, color: color),
              const SizedBox(height: 10),
              Text('ZenHome', style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, letterSpacing: 1.5, color: color)),
              const SizedBox(height: 5),
              Text(context.tr('reset_password_desc') ?? 'Đặt lại mật khẩu mới', style: TextStyle(color: color.withOpacity(0.8), fontStyle: FontStyle.italic)),
            ],
          ),

          Expanded(
            child: LayoutBuilder(
              builder: (context, constraints) {
                return SingleChildScrollView(
                  controller: controller,
                  padding: const EdgeInsets.symmetric(horizontal: 30),
                  child: ConstrainedBox(
                    constraints: BoxConstraints(minHeight: constraints.maxHeight),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                    Builder(
                      builder: (context) {
                        Widget field = TextField(
                          controller: _passwordController,
                          focusNode: isTopLayer ? null : _passwordFocus,
                          obscureText: _obscurePassword,
                          onChanged: (value) {
                             if (true) {
                                _checkPasswordStrength(value);
                             }
                          },
                          decoration: InputDecoration(
                            filled: true,
                            fillColor: isTopLayer ? Colors.white.withOpacity(0.1) : (isDark ? const Color(0xFF121827) : Colors.white),
                            labelText: context.tr('new_password') ?? 'Mật khẩu mới',
                            labelStyle: TextStyle(color: isTopLayer ? Colors.white70 : null),
                            prefixIcon: Icon(Icons.lock, color: color),
                            suffixIcon: IconButton(
                              icon: Icon(_obscurePassword ? Icons.visibility_off : Icons.visibility, color: color),
                              onPressed: () { if (true) { setState(() => _obscurePassword = !_obscurePassword); } },
                            ),
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(15)),
                            enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(15), borderSide: BorderSide(color: (isTopLayer && _passwordFocus.hasFocus) ? color : color.withOpacity(0.3))),
                            focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(15), borderSide: BorderSide(color: color)),
                          ),
                          style: TextStyle(color: isTopLayer ? Colors.white : (isDark ? Colors.white : Colors.black)),
                        );
                        if (isTopLayer) {
                        }
                        return field;
                      }
                    ),
                    const SizedBox(height: 10),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        ClipRRect(
                          borderRadius: BorderRadius.circular(5),
                          child: LinearProgressIndicator(
                            value: strengthPercent,
                            backgroundColor: isTopLayer ? Colors.white24 : color.withOpacity(0.2),
                            color: strengthColor,
                            minHeight: 6,
                          ),
                        ),
                        const SizedBox(height: 8),
                        _buildRequirement(context.tr('req_min_length') ?? 'Ít nhất 8 ký tự', _hasMinLength, color, isTopLayer),
                        _buildRequirement(context.tr('req_uppercase') ?? 'Chữ hoa', _hasUppercase, color, isTopLayer),
                        _buildRequirement(context.tr('req_lowercase') ?? 'Chữ thường', _hasLowercase, color, isTopLayer),
                        _buildRequirement(context.tr('req_number') ?? 'Chữ số', _hasNumber, color, isTopLayer),
                        _buildRequirement(context.tr('req_special_char') ?? 'Ký tự đặc biệt (!@#\$%^&*)', _hasSpecialChar, color, isTopLayer),
                      ],
                    ),
                    const SizedBox(height: 15),
                    Builder(
                      builder: (context) {
                        Widget field = TextField(
                          controller: _confirmPasswordController,
                          focusNode: isTopLayer ? null : _confirmPasswordFocus,
                          obscureText: _obscureConfirmPassword,
                          decoration: InputDecoration(
                            filled: true,
                            fillColor: isTopLayer ? Colors.white.withOpacity(0.1) : (isDark ? const Color(0xFF121827) : Colors.white),
                            labelText: context.tr('confirm_new_password') ?? 'Xác nhận mật khẩu mới',
                            labelStyle: TextStyle(color: isTopLayer ? Colors.white70 : null),
                            prefixIcon: Icon(Icons.lock_outline, color: color),
                            suffixIcon: IconButton(
                              icon: Icon(_obscureConfirmPassword ? Icons.visibility_off : Icons.visibility, color: color),
                              onPressed: () { if (true) { setState(() => _obscureConfirmPassword = !_obscureConfirmPassword); } },
                            ),
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(15)),
                            enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(15), borderSide: BorderSide(color: (isTopLayer && _confirmPasswordFocus.hasFocus) ? color : color.withOpacity(0.3))),
                            focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(15), borderSide: BorderSide(color: color)),
                          ),
                          style: TextStyle(color: isTopLayer ? Colors.white : (isDark ? Colors.white : Colors.black)),
                        );
                        if (isTopLayer) {
                        }
                        return field;
                      }
                    ),
                    const SizedBox(height: 30),

                    SizedBox(
                      width: double.infinity,
                      height: 55,
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: isTopLayer ? Colors.white : const Color(0xFF2A3A7C),
                          foregroundColor: isTopLayer ? const Color(0xFF2A3A7C) : Colors.white,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
                        ),
                        onPressed: _handleResetPassword,
                        child: Text(context.tr('update_password') ?? 'Cập nhật Mật khẩu', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                      ),
                    ),
                  ],
                ),
              ),
            );
          }),
        ),
      ],
    ),
  );
  }

  @override
  Widget build(BuildContext context) {
    bool isDark = Theme.of(context).brightness == Brightness.dark;
    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF090C15) : const Color(0xFFF5F7FA),
      body: DualLayerScreenWrapper(
        waveHeightPercent: 0.45,
        builder: _buildContent,
      ),
    );
  }
}

import 'dart:io';
import 'package:flutter_windowmanager_plus/flutter_windowmanager_plus.dart';
import 'dart:io';
import 'package:flutter_windowmanager_plus/flutter_windowmanager_plus.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:zenhome_app/core/utils/localization_extension.dart';
import 'package:zenhome_app/core/utils/toast_helper.dart';
import 'package:zenhome_app/features/auth/ui/forgot_password_screen.dart';
import 'package:zenhome_app/core/widgets/loading_overlay.dart';

class ChangePasswordScreen extends ConsumerStatefulWidget {
  const ChangePasswordScreen({super.key});

  @override
  ConsumerState<ChangePasswordScreen> createState() => _ChangePasswordScreenState();
}

class _ChangePasswordScreenState extends ConsumerState<ChangePasswordScreen> {
  final User? user = FirebaseAuth.instance.currentUser;
  final TextEditingController _oldPassController = TextEditingController();
  final TextEditingController _newPassController = TextEditingController();
  final TextEditingController _confirmPassController = TextEditingController();
  
  bool _isLoading = false;
  bool _obscureOldPass = true;
  bool _obscureNewPass = true;
  bool _obscureConfirmPass = true;

  bool _hasMinLength = false;
  bool _hasUppercase = false;
  bool _hasLowercase = false;
  bool _hasNumber = false;
  bool _hasSpecialChar = false;

  bool _hasPasswordProvider = false;

  @override
  void initState() {
    super.initState();
    _hasPasswordProvider = user?.providerData.any((p) => p.providerId == 'password') ?? false;
    if (Platform.isAndroid) {
      FlutterWindowManagerPlus.addFlags(FlutterWindowManagerPlus.FLAG_SECURE);
    }
  }

  @override
  void dispose() {
    if (Platform.isAndroid) {
      FlutterWindowManagerPlus.clearFlags(FlutterWindowManagerPlus.FLAG_SECURE);
    }
    _oldPassController.dispose();
    _newPassController.dispose();
    _confirmPassController.dispose();
    super.dispose();
  }

  void _checkPasswordStrength(String password) {
    setState(() {
      _hasMinLength = password.length >= 8;
      _hasUppercase = password.contains(RegExp(r'[A-Z]'));
      _hasLowercase = password.contains(RegExp(r'[a-z]'));
      _hasNumber = password.contains(RegExp(r'[0-9]'));
      _hasSpecialChar = password.contains(RegExp(r'[!@#\$%^&*(),.?":{}|<>]'));
    });
  }

  Widget _buildRequirement(String text, bool isMet, Color baseColor) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        children: [
          Icon(
            isMet ? Icons.check_circle : Icons.cancel,
            color: isMet ? Colors.green : baseColor.withOpacity(0.5),
            size: 16,
          ),
          const SizedBox(width: 8),
          Text(
            text,
            style: TextStyle(
              color: isMet ? Colors.green : baseColor.withOpacity(0.8),
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }

  void _updatePassword() async {
    if (_hasPasswordProvider && _oldPassController.text.isEmpty) {
      showFloatingToast(context, context.tr('error') ?? 'Lỗi', context.tr('err_empty_old_pass') ?? 'Vui lòng nhập mật khẩu cũ', isError: true);
      return;
    }
    
    if (!_hasMinLength || !_hasUppercase || !_hasLowercase || !_hasNumber || !_hasSpecialChar) {
      showFloatingToast(context, context.tr('error') ?? 'Lỗi', context.tr('err_firebase_weak_password') ?? 'Mật khẩu chưa đạt đủ các yêu cầu bảo mật!', isError: true);
      return;
    }

    if (_newPassController.text != _confirmPassController.text) {
      showFloatingToast(context, context.tr('error') ?? 'Lỗi', context.tr('err_pass_mismatch') ?? 'Mật khẩu không khớp', isError: true);
      return;
    }

    setState(() => _isLoading = true);
    try {
      if (_hasPasswordProvider) {
        AuthCredential credential = EmailAuthProvider.credential(
          email: user!.email!,
          password: _oldPassController.text.trim(),
        );
        await user!.reauthenticateWithCredential(credential);
      }
      
      await user!.updatePassword(_newPassController.text.trim());
      await user!.reload();
      
      showFloatingToast(context, context.tr('toast_success') ?? 'Thành công', context.tr('password_updated_success') ?? 'Mật khẩu đã được cập nhật');
      if (mounted) Navigator.pop(context);
      
    } on FirebaseAuthException catch (e) {
      if (e.code == 'wrong-password' || e.code == 'invalid-credential') {
        showFloatingToast(context, context.tr('error') ?? 'Lỗi', context.tr('err_wrong_old_pass') ?? 'Mật khẩu cũ không đúng', isError: true);
      } else {
        showFloatingToast(context, context.tr('error') ?? 'Lỗi', e.message ?? context.tr('error') ?? 'Lỗi', isError: true);
      }
    } catch (e) {
      showFloatingToast(context, context.tr('error') ?? 'Lỗi', context.tr('error') ?? 'Lỗi', isError: true);
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    bool isDark = Theme.of(context).brightness == Brightness.dark;
    Color color = isDark ? const Color(0xFF14B8A6) : const Color(0xFF0F766E);
    
    int strengthScore = (_hasMinLength ? 1 : 0) +
        (_hasUppercase ? 1 : 0) +
        (_hasLowercase ? 1 : 0) +
        (_hasNumber ? 1 : 0) +
        (_hasSpecialChar ? 1 : 0);
    double strengthPercent = strengthScore / 5;
    Color strengthColor = strengthPercent <= 0.4 ? Colors.red : (strengthPercent <= 0.8 ? Colors.orange : Colors.green);

    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF090C15) : const Color(0xFFF5F7FA),
      appBar: AppBar(
        title: Text(context.tr('menu_change_password') ?? 'Đổi mật khẩu', style: const TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: Colors.transparent,
        elevation: 0,
        iconTheme: IconThemeData(color: isDark ? Colors.white : Colors.black),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(25.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(context.tr('change_password') ?? 'Đổi mật khẩu', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
            const SizedBox(height: 15),
            
            if (_hasPasswordProvider) ...[
              TextField(
                controller: _oldPassController,
                obscureText: _obscureOldPass,
                decoration: InputDecoration(
                  labelText: context.tr('old_password') ?? 'Mật khẩu hiện tại',
                  prefixIcon: const Icon(Icons.lock_clock),
                  suffixIcon: IconButton(
                    icon: Icon(_obscureOldPass ? Icons.visibility_off : Icons.visibility),
                    onPressed: () => setState(() => _obscureOldPass = !_obscureOldPass),
                  ),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(15)),
                ),
              ),
              Align(
                alignment: Alignment.centerRight,
                child: TextButton(
                  onPressed: () {
                    Navigator.push(context, MaterialPageRoute(builder: (context) => const ForgotPasswordScreen()));
                  },
                  child: Text(context.tr('forgot_password') ?? 'Quên mật khẩu?', style: const TextStyle(color: Colors.blue)),
                ),
              ),
              const SizedBox(height: 5),
            ],
            
            TextField(
              controller: _newPassController,
              obscureText: _obscureNewPass,
              onChanged: _checkPasswordStrength,
              decoration: InputDecoration(
                labelText: context.tr('new_password') ?? 'Mật khẩu mới',
                prefixIcon: const Icon(Icons.lock_reset),
                suffixIcon: IconButton(
                  icon: Icon(_obscureNewPass ? Icons.visibility_off : Icons.visibility),
                  onPressed: () => setState(() => _obscureNewPass = !_obscureNewPass),
                ),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(15)),
              ),
            ),
            const SizedBox(height: 10),
            
            ClipRRect(
              borderRadius: BorderRadius.circular(5),
              child: LinearProgressIndicator(
                value: strengthPercent,
                backgroundColor: color.withOpacity(0.2),
                color: strengthColor,
                minHeight: 6,
              ),
            ),
            const SizedBox(height: 8),
            _buildRequirement(context.tr('req_min_length') ?? 'Ít nhất 8 ký tự', _hasMinLength, color),
            _buildRequirement(context.tr('req_uppercase') ?? 'Chữ hoa', _hasUppercase, color),
            _buildRequirement(context.tr('req_lowercase') ?? 'Chữ thường', _hasLowercase, color),
            _buildRequirement(context.tr('req_number') ?? 'Chữ số', _hasNumber, color),
            _buildRequirement(context.tr('req_special_char') ?? 'Ký tự đặc biệt (!@#\$%^&*)', _hasSpecialChar, color),
            
            const SizedBox(height: 15),
            
            TextField(
              controller: _confirmPassController,
              obscureText: _obscureConfirmPass,
              decoration: InputDecoration(
                labelText: context.tr('confirm_new_password') ?? 'Xác nhận mật khẩu mới',
                prefixIcon: const Icon(Icons.lock_outline),
                suffixIcon: IconButton(
                  icon: Icon(_obscureConfirmPass ? Icons.visibility_off : Icons.visibility),
                  onPressed: () => setState(() => _obscureConfirmPass = !_obscureConfirmPass),
                ),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(15)),
              ),
            ),
            const SizedBox(height: 40),
            SizedBox(
              width: double.infinity, height: 55,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF0F766E),
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15))
                ),
                onPressed: _isLoading ? null : _updatePassword,
                child: _isLoading 
                     ? LogoLoadingIndicator(color: Colors.white, size: 24) 
                     : Text(context.tr('update_password') ?? 'Cập nhật Mật khẩu', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              ),
            )
          ],
        ),
      ),
    );
  }
}



import 'dart:io';
import 'package:flutter_windowmanager_plus/flutter_windowmanager_plus.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:zenhome_app/core/theme/app_theme.dart';
import 'package:zenhome_app/core/utils/localization_extension.dart';
import 'package:zenhome_app/core/utils/toast_helper.dart';
import 'package:zenhome_app/core/widgets/zen_liquid_glass.dart';
import 'package:zenhome_app/features/auth/ui/forgot_password_screen.dart';

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

  Widget _buildRequirement(String text, bool isMet, Color mutedColor) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        children: [
          Icon(
            isMet ? Icons.check_circle_rounded : Icons.radio_button_unchecked_rounded,
            color: isMet ? AppColors.emeraldGlow : mutedColor.withOpacity(0.6),
            size: 16,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              text,
              style: TextStyle(
                color: isMet ? AppColors.emeraldGlow : mutedColor,
                fontSize: 12.5,
                fontWeight: isMet ? FontWeight.w700 : FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _updatePassword() async {
    if (_hasPasswordProvider && _oldPassController.text.isEmpty) {
      showFloatingToast(
        context,
        context.tr('error'),
        context.tr('err_empty_old_pass'),
        isError: true,
      );
      return;
    }

    if (!_hasMinLength || !_hasUppercase || !_hasLowercase || !_hasNumber || !_hasSpecialChar) {
      showFloatingToast(
        context,
        context.tr('error'),
        context.tr('err_firebase_weak_password'),
        isError: true,
      );
      return;
    }

    if (_newPassController.text != _confirmPassController.text) {
      showFloatingToast(
        context,
        context.tr('error'),
        context.tr('err_pass_mismatch'),
        isError: true,
      );
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

      if (!mounted) return;
      showFloatingToast(
        context,
        context.tr('toast_success'),
        context.tr('password_updated_success'),
      );
      Navigator.pop(context);
    } on FirebaseAuthException catch (e) {
      if (!mounted) return;
      if (e.code == 'wrong-password' || e.code == 'invalid-credential') {
        showFloatingToast(
          context,
          context.tr('error'),
          context.tr('err_wrong_old_pass'),
          isError: true,
        );
      } else {
        showFloatingToast(
          context,
          context.tr('error'),
          e.message ?? context.tr('error'),
          isError: true,
        );
      }
    } catch (e) {
      if (!mounted) return;
      showFloatingToast(
        context,
        context.tr('error'),
        context.tr('error'),
        isError: true,
      );
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final bool isDark = Theme.of(context).brightness == Brightness.dark;
    final zen = context.zenColors;
    final textColor = isDark ? AppColors.darkText : AppColors.lightText;
    final mutedColor = isDark ? AppColors.darkTextMuted : AppColors.lightTextMuted;

    int strengthScore = (_hasMinLength ? 1 : 0) +
        (_hasUppercase ? 1 : 0) +
        (_hasLowercase ? 1 : 0) +
        (_hasNumber ? 1 : 0) +
        (_hasSpecialChar ? 1 : 0);
    double strengthPercent = strengthScore / 5;
    Color strengthColor = strengthPercent <= 0.4
        ? AppColors.roseGlow
        : (strengthPercent <= 0.8 ? AppColors.amberGlow : AppColors.emeraldGlow);

    return ZenGlassScaffold(
      appBar: ZenGlassAppBar(
        titleText: context.tr('menu_change_password'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 18, 20, 36),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Password Form & Strength Card
            ZenGlassCard(
              blurSigma: 18,
              isActive: true,
              padding: const EdgeInsets.all(22),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(11),
                        decoration: BoxDecoration(
                          gradient: zen.brandHero,
                          borderRadius: BorderRadius.circular(14),
                          boxShadow: [
                            BoxShadow(
                              color: zen.primary.withOpacity(0.28),
                              blurRadius: 12,
                              offset: const Offset(0, 4),
                            ),
                          ],
                        ),
                        child: const Icon(Icons.lock_reset_rounded, color: Colors.white, size: 22),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          context.tr('change_password'),
                          style: TextStyle(
                            fontWeight: FontWeight.w800,
                            fontSize: 17,
                            color: textColor,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),

                  if (_hasPasswordProvider) ...[
                    TextField(
                      controller: _oldPassController,
                      obscureText: _obscureOldPass,
                      style: TextStyle(color: textColor, fontWeight: FontWeight.w600),
                      decoration: zenGlassInputDecoration(
                        context,
                        labelText: context.tr('old_password'),
                        prefixIcon: Icons.lock_clock_outlined,
                        suffixIcon: IconButton(
                          icon: Icon(
                            _obscureOldPass ? Icons.visibility_off_outlined : Icons.visibility_outlined,
                            color: mutedColor,
                          ),
                          onPressed: () => setState(() => _obscureOldPass = !_obscureOldPass),
                        ),
                      ),
                    ),
                    Align(
                      alignment: Alignment.centerRight,
                      child: TextButton(
                        onPressed: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(builder: (context) => const ForgotPasswordScreen()),
                          );
                        },
                        child: Text(
                          context.tr('forgot_password'),
                          style: TextStyle(
                            color: isDark ? zen.primaryAccent : zen.primary,
                            fontWeight: FontWeight.w700,
                            fontSize: 13,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 4),
                  ],

                  TextField(
                    controller: _newPassController,
                    obscureText: _obscureNewPass,
                    onChanged: _checkPasswordStrength,
                    style: TextStyle(color: textColor, fontWeight: FontWeight.w600),
                    decoration: zenGlassInputDecoration(
                      context,
                      labelText: context.tr('new_password'),
                      prefixIcon: Icons.lock_reset_rounded,
                      suffixIcon: IconButton(
                        icon: Icon(
                          _obscureNewPass ? Icons.visibility_off_outlined : Icons.visibility_outlined,
                          color: mutedColor,
                        ),
                        onPressed: () => setState(() => _obscureNewPass = !_obscureNewPass),
                      ),
                    ),
                  ),
                  const SizedBox(height: 14),

                  // Password Strength Indicator Glass Sub-panel (blurSigma: 0)
                  ZenLiquidGlass(
                    blurSigma: 0,
                    borderRadius: 16,
                    padding: const EdgeInsets.all(14),
                    surfaceColor: isDark
                        ? Colors.white.withOpacity(0.05)
                        : Colors.white.withOpacity(0.60),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        ClipRRect(
                          borderRadius: BorderRadius.circular(6),
                          child: LinearProgressIndicator(
                            value: strengthPercent,
                            backgroundColor: isDark
                                ? Colors.white.withOpacity(0.10)
                                : const Color(0xFFE2E8F0),
                            color: strengthColor,
                            minHeight: 7,
                          ),
                        ),
                        const SizedBox(height: 10),
                        _buildRequirement(context.tr('req_min_length'), _hasMinLength, mutedColor),
                        _buildRequirement(context.tr('req_uppercase'), _hasUppercase, mutedColor),
                        _buildRequirement(context.tr('req_lowercase'), _hasLowercase, mutedColor),
                        _buildRequirement(context.tr('req_number'), _hasNumber, mutedColor),
                        _buildRequirement(context.tr('req_special_char'), _hasSpecialChar, mutedColor),
                      ],
                    ),
                  ),

                  const SizedBox(height: 16),

                  TextField(
                    controller: _confirmPassController,
                    obscureText: _obscureConfirmPass,
                    style: TextStyle(color: textColor, fontWeight: FontWeight.w600),
                    decoration: zenGlassInputDecoration(
                      context,
                      labelText: context.tr('confirm_new_password'),
                      prefixIcon: Icons.lock_outline_rounded,
                      suffixIcon: IconButton(
                        icon: Icon(
                          _obscureConfirmPass ? Icons.visibility_off_outlined : Icons.visibility_outlined,
                          color: mutedColor,
                        ),
                        onPressed: () => setState(() => _obscureConfirmPass = !_obscureConfirmPass),
                      ),
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 24),

            ZenGlassButton(
              label: context.tr('update_password'),
              icon: Icons.verified_user_rounded,
              isLoading: _isLoading,
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
              onPressed: _isLoading ? null : _updatePassword,
            ),
          ],
        ),
      ),
    );
  }
}

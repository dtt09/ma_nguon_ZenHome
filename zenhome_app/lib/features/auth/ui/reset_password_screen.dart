import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:firebase_auth/firebase_auth.dart';

import 'package:zenhome_app/core/theme/app_theme.dart';
import 'package:zenhome_app/core/utils/localization_extension.dart';
import 'package:zenhome_app/core/utils/toast_helper.dart';
import 'package:zenhome_app/core/widgets/animations/dual_layer_screen_wrapper.dart';
import 'package:zenhome_app/core/widgets/loading_overlay.dart';
import 'package:zenhome_app/core/widgets/zen_liquid_glass.dart';
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
  ConsumerState<ResetPasswordScreen> createState() =>
      _ResetPasswordScreenState();
}

class _ResetPasswordScreenState extends ConsumerState<ResetPasswordScreen> {
  final TextEditingController _passwordController = TextEditingController();
  final TextEditingController _confirmPasswordController =
      TextEditingController();
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

  Widget _buildRequirement(String text, bool isMet, bool isDark) {
    final Color mutedColor =
        isDark ? AppColors.darkTextMuted : AppColors.lightTextMuted;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2.5),
      child: Row(
        children: [
          Icon(
            isMet
                ? Icons.check_circle_rounded
                : Icons.radio_button_unchecked_rounded,
            color: isMet ? AppColors.emeraldGlow : mutedColor.withOpacity(0.65),
            size: 16,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              text,
              style: TextStyle(
                color: isMet ? AppColors.emeraldGlow : mutedColor,
                fontSize: 12,
                fontWeight: isMet ? FontWeight.w600 : FontWeight.w400,
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  void initState() {
    super.initState();
    _passwordFocus.addListener(() {
      if (mounted) setState(() {});
    });
    _confirmPasswordFocus.addListener(() {
      if (mounted) setState(() {});
    });
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
      showFloatingToast(
        context,
        context.tr('error'),
        context.tr('err_empty_field'),
        isError: true,
      );
      return;
    }

    if (password != confirmPassword) {
      showFloatingToast(
        context,
        context.tr('error'),
        context.tr('err_pass_mismatch'),
        isError: true,
      );
      return;
    }
    if (!_hasMinLength ||
        !_hasUppercase ||
        !_hasLowercase ||
        !_hasNumber ||
        !_hasSpecialChar) {
      showFloatingToast(
        context,
        context.tr('error'),
        context.tr('err_firebase_weak_password'),
        isError: true,
      );
      return;
    }

    LoadingOverlay.show(context);
    try {
      final currentUser = FirebaseAuth.instance.currentUser;
      if (currentUser != null && currentUser.uid == widget.uid) {
        // Người dùng đã đăng nhập bằng Phone Provider qua OTP
        await currentUser.updatePassword(password);

        // Liên kết với Email Provider (nếu chưa có)
        final String dummyEmail =
            '${widget.phoneNumber.replaceAll('+', '')}@zenhome.local';
        try {
          final cred = EmailAuthProvider.credential(
            email: dummyEmail,
            password: password,
          );
          await currentUser.linkWithCredential(cred);
        } catch (_) {
          // Bỏ qua nếu đã liên kết từ trước
        }
      }

      LoadingOverlay.hide();
      if (mounted) {
        showFloatingToast(
          context,
          context.tr('toast_success'),
          context.tr('password_updated_success'),
        );
        FirebaseAuth.instance.signOut();
        Navigator.pushAndRemoveUntil(
          context,
          MaterialPageRoute(builder: (context) => const LoginScreen()),
          (r) => false,
        );
      }
    } catch (e) {
      LoadingOverlay.hide();
      if (mounted) {
        showFloatingToast(
          context,
          context.tr('error'),
          '${context.tr('err_generic')}: $e',
          isError: true,
        );
      }
    }
  }

  Widget _buildMainContent(
    BuildContext context, {
    required bool isOverWave,
    required ScrollController controller,
  }) {
    final bool isDark = Theme.of(context).brightness == Brightness.dark;
    final zen = context.zenColors;
    final Color primaryColor = isDark ? zen.primaryAccent : zen.primary;
    final Color textColor = isDark ? AppColors.darkText : AppColors.lightText;
    final Color mutedColor =
        isDark ? AppColors.darkTextMuted : AppColors.lightTextMuted;
    final bool canPop = ModalRoute.of(context)?.canPop ?? false;

    // Split-wave header colors
    final Color headerLogoColor = isOverWave ? Colors.white : primaryColor;
    final Color headerTitleColor =
        isOverWave ? Colors.white : (isDark ? AppColors.darkText : AppColors.lightText);
    final Color headerSubtitleColor = isOverWave
        ? Colors.white.withOpacity(0.86)
        : (isDark ? AppColors.darkTextMuted : AppColors.lightTextMuted);

    final int strengthScore = (_hasMinLength ? 1 : 0) +
        (_hasUppercase ? 1 : 0) +
        (_hasLowercase ? 1 : 0) +
        (_hasNumber ? 1 : 0) +
        (_hasSpecialChar ? 1 : 0);
    final double strengthPercent = strengthScore / 5;
    final Color strengthColor = strengthPercent <= 0.4
        ? AppColors.roseGlow
        : (strengthPercent <= 0.8 ? AppColors.amberGlow : AppColors.emeraldGlow);

    return SafeArea(
      bottom: false,
      child: Column(
        children: [
          if (canPop)
            Align(
              alignment: Alignment.centerLeft,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 10, 20, 0),
                child: ZenGlassIconButton(
                  icon: Icons.arrow_back_ios_new_rounded,
                  size: 40,
                  iconSize: 18,
                  borderRadius: 14,
                  blurSigma: isOverWave ? 0 : 14,
                  iconColor: isDark ? Colors.white : AppColors.lightText,
                  onTap: () => Navigator.maybePop(context),
                ),
              ),
            )
          else
            const SizedBox(height: 16),

          const SizedBox(height: 8),

          // --- Split-Wave Brand Header ---
          Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 72,
                height: 72,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(22),
                  color: isOverWave
                      ? Colors.white.withOpacity(0.18)
                      : primaryColor.withOpacity(0.12),
                  border: Border.all(
                    color: isOverWave
                        ? Colors.white.withOpacity(0.34)
                        : primaryColor.withOpacity(0.28),
                    width: 1.2,
                  ),
                ),
                child: Image.asset(
                  'public/zenhome_logo_transparent.png',
                  width: 46,
                  height: 46,
                  fit: BoxFit.contain,
                  color: headerLogoColor,
                ),
              ),
              const SizedBox(height: 10),
              Text(
                'ZenHome',
                style: TextStyle(
                  fontSize: 25,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 1.3,
                  color: headerTitleColor,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                context.tr('reset_password_desc'),
                style: TextStyle(
                  color: headerSubtitleColor,
                  fontStyle: FontStyle.italic,
                  fontSize: 14,
                ),
              ),
            ],
          ),

          const SizedBox(height: 16),

          Expanded(
            child: LayoutBuilder(
              builder: (context, constraints) {
                return SingleChildScrollView(
                  controller: controller,
                  physics: const BouncingScrollPhysics(),
                  padding: const EdgeInsets.fromLTRB(24, 6, 24, 28),
                  child: ConstrainedBox(
                    constraints: BoxConstraints(
                      minHeight: (constraints.maxHeight - 34).clamp(0.0, double.infinity),
                    ),
                    child: Center(
                      child: ZenLiquidGlass(
                        borderRadius: 28,
                        blurSigma: isOverWave ? 0 : 20,
                        rimWidth: 1.3,
                        glowColor: zen.primary,
                        padding: const EdgeInsets.all(24),
                        customShadows: isOverWave ? const [] : null,
                        customGradient: LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: isDark
                              ? [
                                  const Color(0xFF0F172A).withOpacity(0.70),
                                  const Color(0xFF0A1120).withOpacity(0.54),
                                ]
                              : [
                                  Colors.white.withOpacity(0.84),
                                  Colors.white.withOpacity(0.70),
                                ],
                        ),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            TextField(
                              controller: _passwordController,
                              focusNode: isOverWave ? null : _passwordFocus,
                              obscureText: _obscurePassword,
                              onChanged: _checkPasswordStrength,
                              decoration: zenGlassInputDecoration(
                                context,
                                labelText: context.tr('new_password'),
                                prefixIcon: Icons.lock_outline_rounded,
                                borderRadius: 16,
                                accentColor: primaryColor,
                                suffixIcon: IconButton(
                                  icon: Icon(
                                    _obscurePassword
                                        ? Icons.visibility_off_rounded
                                        : Icons.visibility_rounded,
                                    size: 20,
                                    color: _passwordFocus.hasFocus
                                        ? primaryColor
                                        : mutedColor,
                                  ),
                                  onPressed: () {
                                    setState(
                                      () =>
                                          _obscurePassword = !_obscurePassword,
                                    );
                                  },
                                ),
                              ),
                              style: TextStyle(color: textColor),
                            ),
                            const SizedBox(height: 12),

                            // Frosted Password Strength Checklist
                            Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: Colors.white
                                    .withOpacity(isDark ? 0.05 : 0.56),
                                borderRadius: BorderRadius.circular(14),
                                border: Border.all(
                                  color: isDark
                                      ? Colors.white.withOpacity(0.08)
                                      : const Color(0xFFE2E8F0),
                                ),
                              ),
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
                                      minHeight: 6,
                                    ),
                                  ),
                                  const SizedBox(height: 8),
                                  _buildRequirement(
                                    context.tr('req_min_length'),
                                    _hasMinLength,
                                    isDark,
                                  ),
                                  _buildRequirement(
                                    context.tr('req_uppercase'),
                                    _hasUppercase,
                                    isDark,
                                  ),
                                  _buildRequirement(
                                    context.tr('req_lowercase'),
                                    _hasLowercase,
                                    isDark,
                                  ),
                                  _buildRequirement(
                                    context.tr('req_number'),
                                    _hasNumber,
                                    isDark,
                                  ),
                                  _buildRequirement(
                                    context.tr('req_special_char'),
                                    _hasSpecialChar,
                                    isDark,
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(height: 14),

                            TextField(
                              controller: _confirmPasswordController,
                              focusNode:
                                  isOverWave ? null : _confirmPasswordFocus,
                              obscureText: _obscureConfirmPassword,
                              decoration: zenGlassInputDecoration(
                                context,
                                labelText: context.tr('confirm_new_password'),
                                prefixIcon: Icons.verified_user_outlined,
                                borderRadius: 16,
                                accentColor: primaryColor,
                                suffixIcon: IconButton(
                                  icon: Icon(
                                    _obscureConfirmPassword
                                        ? Icons.visibility_off_rounded
                                        : Icons.visibility_rounded,
                                    size: 20,
                                    color: _confirmPasswordFocus.hasFocus
                                        ? primaryColor
                                        : mutedColor,
                                  ),
                                  onPressed: () {
                                    setState(
                                      () => _obscureConfirmPassword =
                                          !_obscureConfirmPassword,
                                    );
                                  },
                                ),
                              ),
                              style: TextStyle(color: textColor),
                            ),
                            const SizedBox(height: 24),

                            SizedBox(
                              width: double.infinity,
                              height: 54,
                              child: ZenGlassButton(
                                label: context.tr('update_password'),
                                icon: Icons.check_circle_outline_rounded,
                                borderRadius: 16,
                                onPressed: () {
                                  HapticFeedback.lightImpact();
                                  _handleResetPassword();
                                },
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return ZenGlassScaffold(
      body: DualLayerScreenWrapper(
        waveHeightPercent: 0.45,
        builder: (context, isTopLayer, controller) => _buildMainContent(
          context,
          isOverWave: isTopLayer,
          controller: controller,
        ),
      ),
    );
  }
}

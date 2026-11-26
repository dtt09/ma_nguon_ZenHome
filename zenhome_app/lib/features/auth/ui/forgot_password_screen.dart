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
import 'package:zenhome_app/features/auth/ui/otp_verification_screen.dart';
import 'package:zenhome_app/features/auth/ui/reset_password_screen.dart';

class ForgotPasswordScreen extends ConsumerStatefulWidget {
  const ForgotPasswordScreen({super.key});

  @override
  ConsumerState<ForgotPasswordScreen> createState() =>
      _ForgotPasswordScreenState();
}

class _ForgotPasswordScreenState extends ConsumerState<ForgotPasswordScreen> {
  final TextEditingController _phoneController = TextEditingController();
  final FocusNode _phoneFocus = FocusNode();
  final bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _phoneFocus.addListener(() {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _phoneController.dispose();
    _phoneFocus.dispose();
    super.dispose();
  }

  void _handleSendOtp() async {
    final String input = _phoneController.text.trim();
    if (input.isEmpty) {
      showFloatingToast(
        context,
        context.tr('error'),
        context.tr('err_empty_phone_forgot'),
        isError: true,
      );
      return;
    }

    if (input.contains('@')) {
      _sendResetEmail(input);
      return;
    }
    final digits = input.replaceAll(RegExp(r'[ ()-]'), '');
    final phone = digits.startsWith('0') ? '+84${digits.substring(1)}'
        : digits.startsWith('+') ? digits : '+$digits';
    if (RegExp(r'^\+[1-9]\d{7,14}$').hasMatch(phone)) {
      _sendOtpToPhone(phone);
    } else {
      showFloatingToast(context, context.tr('error'), context.tr('phone_or_email'), isError: true);
    }
  }

  Future<void> _sendResetEmail(String email) async {
    LoadingOverlay.show(context);
    try {
      await FirebaseAuth.instance.sendPasswordResetEmail(email: email);
    } on FirebaseAuthException catch (error) {
      if (error.code != 'user-not-found') {
        LoadingOverlay.hide();
        if (mounted) showFloatingToast(context, context.tr('error'), error.message ?? error.code, isError: true);
        return;
      }
    }
    LoadingOverlay.hide();
    if (mounted) {
      final vi = Localizations.localeOf(context).languageCode == 'vi';
      showFloatingToast(context, context.tr('success'), vi ? 'Nếu email đã đăng ký, hãy kiểm tra hộp thư để đặt lại mật khẩu.'
          : 'If this email is registered, check your inbox for the password reset link.');
    }
  }

  void _sendOtpToPhone(String phoneNumber) async {
    LoadingOverlay.show(context);
    try {
      await FirebaseAuth.instance.verifyPhoneNumber(
        phoneNumber: phoneNumber,
        verificationCompleted: (PhoneAuthCredential credential) async {
          try {
            final userCred =
                await FirebaseAuth.instance.signInWithCredential(credential);
            final uid = userCred.user!.uid;
            LoadingOverlay.hide();
            if (mounted) {
              Navigator.pushReplacement(
                context,
                MaterialPageRoute(
                  builder: (context) =>
                      ResetPasswordScreen(phoneNumber: phoneNumber, uid: uid),
                ),
              );
            }
          } catch (e) {
            LoadingOverlay.hide();
          }
        },
        verificationFailed: (FirebaseAuthException e) {
          LoadingOverlay.hide();
          if (mounted) {
            showFloatingToast(
              context,
              context.tr('error'),
              e.message ?? 'Lỗi gửi OTP',
              isError: true,
            );
          }
        },
        codeSent: (String verificationId, int? resendToken) {
          LoadingOverlay.hide();
          if (mounted) {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => OtpVerificationScreen(
                  verificationId: verificationId,
                  phoneNumber: phoneNumber,
                  isForgotPassword: true,
                ),
              ),
            );
          }
        },
        codeAutoRetrievalTimeout: (String verificationId) {},
      );
    } catch (e) {
      LoadingOverlay.hide();
      if (mounted) {
        showFloatingToast(
          context,
          context.tr('error'),
          e.toString(),
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

    // Header colors switch cleanly along the wave curve
    final Color headerAccent = isOverWave ? Colors.white : primaryColor;
    final Color headerTitleColor =
        isOverWave ? Colors.white : (isDark ? AppColors.darkText : AppColors.lightText);
    final Color headerDescColor = isOverWave
        ? Colors.white.withOpacity(0.86)
        : (isDark ? AppColors.darkTextMuted : AppColors.lightTextMuted);

    return SafeArea(
      bottom: false,
      child: Column(
        children: [
          Align(
            alignment: Alignment.centerLeft,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 4),
              child: ZenGlassIconButton(
                icon: Icons.arrow_back_ios_new_rounded,
                size: 40,
                iconSize: 18,
                borderRadius: 14,
                blurSigma: isOverWave ? 0 : 14,
                iconColor: isDark ? Colors.white : AppColors.lightText,
                onTap: () => Navigator.pop(context),
              ),
            ),
          ),

          Expanded(
            child: Center(
              child: SingleChildScrollView(
                controller: controller,
                physics: const BouncingScrollPhysics(),
                padding: const EdgeInsets.fromLTRB(24, 10, 24, 32),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    // --- Split-Wave Header Hero ---
                    Container(
                      width: 84,
                      height: 84,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: isOverWave
                            ? Colors.white.withOpacity(0.16)
                            : primaryColor.withOpacity(0.12),
                        border: Border.all(
                          color: isOverWave
                              ? Colors.white.withOpacity(0.35)
                              : primaryColor.withOpacity(0.28),
                          width: 1.3,
                        ),
                      ),
                      child: Icon(
                        Icons.lock_reset_rounded,
                        size: 44,
                        color: headerAccent,
                      ),
                    ),
                    const SizedBox(height: 18),
                    Text(
                      context.tr('forgot_password'),
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 27,
                        fontWeight: FontWeight.w800,
                        letterSpacing: -0.2,
                        color: headerTitleColor,
                      ),
                    ),
                    const SizedBox(height: 10),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 10),
                      child: Text(
                        context.tr('forgot_password_desc'),
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: headerDescColor,
                          fontSize: 14,
                          height: 1.5,
                        ),
                      ),
                    ),

                    const SizedBox(height: 32),

                    // --- True Refractive Liquid Glass 2.0 Form Card ---
                    ZenLiquidGlass(
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
                            controller: _phoneController,
                            focusNode: isOverWave ? null : _phoneFocus,
                            keyboardType: TextInputType.emailAddress,
                            decoration: zenGlassInputDecoration(
                              context,
                              labelText: context.tr('phone_or_email'),
                              prefixIcon: Icons.person_search_rounded,
                              borderRadius: 16,
                              accentColor: primaryColor,
                            ),
                            style: TextStyle(
                              color: textColor,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          const SizedBox(height: 22),
                          SizedBox(
                            width: double.infinity,
                            height: 54,
                            child: ZenGlassButton(
                              label: context.tr('send_reset_link'),
                              icon: Icons.arrow_forward_rounded,
                              isLoading: _isLoading,
                              borderRadius: 16,
                              onPressed: _isLoading ? null : _handleSendOtp,
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
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return ZenGlassScaffold(
      body: DualLayerScreenWrapper(
        waveHeightPercent: 0.40,
        builder: (context, isTopLayer, controller) => _buildMainContent(
          context,
          isOverWave: isTopLayer,
          controller: controller,
        ),
      ),
    );
  }
}

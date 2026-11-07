import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

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

    LoadingOverlay.show(context);
    try {
      // 1. KIỂM TRA TỒN TẠI TÀI KHOẢN TOÀN DIỆN
      Map<String, dynamic>? userData;
      String? username;

      String normalizedInput = input;
      if (!input.contains('@')) {
        if (input.startsWith('0')) {
          normalizedInput = '+84${input.substring(1)}';
        } else if (RegExp(r'^\d+$').hasMatch(input)) {
          normalizedInput = '+$input';
        }
      }

      // Thử tìm theo Username
      final doc = await FirebaseFirestore.instance
          .collection('users')
          .doc(input)
          .get();
      if (doc.exists) {
        userData = doc.data();
        username = doc.id;
      } else {
        // Thử tìm theo SĐT qua bảng tra cứu phone_lookup trước
        try {
          final phoneDoc = await FirebaseFirestore.instance
              .collection('phone_lookup')
              .doc(normalizedInput)
              .get();
          if (phoneDoc.exists) {
            final String targetUsername =
                phoneDoc.data()?['username'] ?? '';
            if (targetUsername.isNotEmpty) {
              final userDoc = await FirebaseFirestore.instance
                  .collection('users')
                  .doc(targetUsername)
                  .get();
              if (userDoc.exists) {
                userData = userDoc.data();
                username = userDoc.id;
              }
            }
          }
        } catch (_) {}

        if (userData == null) {
          // Thử tìm theo SĐT qua query users (dự phòng)
          try {
            final phoneQuery = await FirebaseFirestore.instance
                .collection('users')
                .where('phoneNumber', isEqualTo: normalizedInput)
                .get();
            if (phoneQuery.docs.isNotEmpty) {
              userData = phoneQuery.docs.first.data();
              username = phoneQuery.docs.first.id;
            }
          } catch (_) {}
        }

        if (userData == null && input.contains('@')) {
          if (input.toLowerCase().endsWith('@gmail.com')) {
            // Thử tìm theo Email Google
            try {
              final emailQuery = await FirebaseFirestore.instance
                  .collection('users')
                  .where('email', isEqualTo: input)
                  .get();
              if (emailQuery.docs.isNotEmpty) {
                userData = emailQuery.docs.first.data();
                username = emailQuery.docs.first.id;
              }
            } catch (_) {}
          }
        }
      }

      if (userData == null) {
        LoadingOverlay.hide();
        if (!mounted) return;
        showFloatingToast(
          context,
          context.tr('error'),
          context.tr('err_user_not_found'),
          isError: true,
        );
        return;
      }

      LoadingOverlay.hide();

      // Hiển thị Dialog xác nhận bằng Zen Liquid Glass 2.0
      if (!mounted) return;
      _showAccountFoundDialog(userData, username!);
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

  void _showAccountFoundDialog(Map<String, dynamic> data, String username) {
    final String? phone = (data.containsKey('phoneNumber') &&
            data['phoneNumber'].toString().isNotEmpty)
        ? data['phoneNumber'].toString()
        : null;
    String? email =
        (data.containsKey('email') && data['email'].toString().isNotEmpty)
            ? data['email'].toString()
            : null;
    if (email != null &&
        (!email.toLowerCase().endsWith('@gmail.com') ||
            email.endsWith('@zenhome.local'))) {
      email = null;
    }
    final String displayName = data['displayName']?.toString() ?? username;

    final zen = context.zenColors;
    showZenGlassDialog(
      context: context,
      accentColor: zen.success,
      builder: (ctx) {
        final bool isDark = Theme.of(ctx).brightness == Brightness.dark;
        final Color textColor =
            isDark ? AppColors.darkText : AppColors.lightText;
        final Color mutedColor =
            isDark ? AppColors.darkTextMuted : AppColors.lightTextMuted;

        final String maskedPhone = phone != null && phone.length > 6
            ? phone.replaceRange(3, phone.length - 3, '***')
            : (phone ?? '');

        return Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: zen.success.withOpacity(isDark ? 0.18 : 0.12),
                shape: BoxShape.circle,
                border: Border.all(
                  color: zen.success.withOpacity(0.35),
                ),
              ),
              child: Icon(
                Icons.verified_user_rounded,
                color: zen.success,
                size: 38,
              ),
            ),
            const SizedBox(height: 14),
            Text(
              ctx.tr('account_found'),
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontWeight: FontWeight.w800,
                fontSize: 20,
                color: AppColors.emeraldGlow,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              'Xin chào, $displayName',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontWeight: FontWeight.w700,
                fontSize: 16.5,
                color: textColor,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              ctx.tr('choose_reset_method'),
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 13.5,
                height: 1.4,
                color: mutedColor,
              ),
            ),
            const SizedBox(height: 20),

            if (phone != null)
              Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: ZenGlassCard(
                  blurSigma: 0,
                  borderRadius: 18,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 12,
                  ),
                  isActive: true,
                  glowColor: AppColors.cyanGlow,
                  onTap: () {
                    HapticFeedback.lightImpact();
                    Navigator.pop(ctx);
                    _sendOtpToPhone(phone);
                  },
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: AppColors.cyanGlow.withOpacity(
                            isDark ? 0.22 : 0.14,
                          ),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Icon(
                          Icons.sms_rounded,
                          color: AppColors.cyanGlow,
                          size: 22,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              ctx.tr('send_sms'),
                              style: TextStyle(
                                fontWeight: FontWeight.w700,
                                fontSize: 14.5,
                                color: textColor,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              'Tới: $maskedPhone',
                              style: TextStyle(
                                fontSize: 12.5,
                                color: mutedColor,
                              ),
                            ),
                          ],
                        ),
                      ),
                      Icon(
                        Icons.chevron_right_rounded,
                        color: mutedColor,
                      ),
                    ],
                  ),
                ),
              ),

            if (email != null)
              Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: ZenGlassCard(
                  blurSigma: 0,
                  borderRadius: 18,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 12,
                  ),
                  isActive: true,
                  glowColor: zen.primary,
                  onTap: () {
                    HapticFeedback.lightImpact();
                    final String targetEmail = email!;
                    Navigator.pop(ctx);
                    _sendResetEmail(targetEmail);
                  },
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(
                            isDark ? 0.10 : 0.85,
                          ),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Image.asset(
                          'public/google_logo.png',
                          width: 22,
                          height: 22,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              ctx.tr('verify_via_google'),
                              style: TextStyle(
                                fontWeight: FontWeight.w700,
                                fontSize: 14.5,
                                color: textColor,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              'Qua: ${_maskEmail(email)}',
                              style: TextStyle(
                                fontSize: 12.5,
                                color: mutedColor,
                              ),
                            ),
                          ],
                        ),
                      ),
                      Icon(
                        Icons.chevron_right_rounded,
                        color: mutedColor,
                      ),
                    ],
                  ),
                ),
              ),

            if (phone == null && email == null)
              Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Text(
                  ctx.tr('err_no_recovery_method'),
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: zen.danger,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),

            const SizedBox(height: 6),
            SizedBox(
              width: double.infinity,
              child: ZenGlassButton(
                label: ctx.tr('cancel'),
                isPrimary: false,
                onPressed: () => Navigator.pop(ctx),
              ),
            ),
          ],
        );
      },
    );
  }

  String _maskEmail(String email) {
    final int atIndex = email.indexOf('@');
    if (atIndex <= 2) {
      return '${email.substring(0, 1)}***@${email.substring(atIndex + 1)}';
    }
    return '${email.substring(0, 2)}***${email.substring(atIndex - 1)}';
  }

  void _sendResetEmail(String email) async {
    LoadingOverlay.show(context);
    try {
      final String? clientId = dotenv.env['GOOGLE_CLIENT_ID'];
      final GoogleSignIn googleSignIn = GoogleSignIn(serverClientId: clientId);
      await googleSignIn.signOut(); // Force account selector

      final GoogleSignInAccount? googleUser = await googleSignIn.signIn();
      if (googleUser == null) {
        LoadingOverlay.hide();
        return;
      }

      if (googleUser.email != email) {
        await googleSignIn.signOut();
        LoadingOverlay.hide();
        if (mounted) {
          showFloatingToast(
            context,
            context.tr('error'),
            context.tr('err_reauth_select_google').replaceAll('{email}', email),
            isError: true,
          );
        }
        return;
      }

      // Xác thực thành công, lấy thông tin credential
      final GoogleSignInAuthentication googleAuth =
          await googleUser.authentication;
      final AuthCredential credential = GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken: googleAuth.idToken,
      );

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
                  ResetPasswordScreen(phoneNumber: email, uid: uid),
            ),
          );
        }
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
    } catch (e) {
      LoadingOverlay.hide();
      if (mounted) {
        showFloatingToast(
          context,
          context.tr('error'),
          context
              .tr('err_google_auth_failed')
              .replaceAll('{err}', e.toString()),
          isError: true,
        );
      }
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

import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:zenhome_app/core/theme/app_theme.dart';
import 'package:zenhome_app/core/utils/localization_extension.dart';
import 'package:zenhome_app/core/utils/toast_helper.dart';
import 'package:zenhome_app/core/widgets/loading_overlay.dart';
import 'package:zenhome_app/core/widgets/zen_liquid_glass.dart';

class ReauthHelper {
  /// Xác thực bằng Google một cách trực tiếp
  static Future<bool> reauthWithGoogleExplicit(
    BuildContext context, {
    required String reason,
  }) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return false;
    return await _reauthWithGoogle(context, user, reason);
  }

  /// Xác thực bằng SĐT (OTP) một cách trực tiếp
  static Future<bool> reauthWithPhoneExplicit(BuildContext context) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return false;
    return await _reauthWithPhone(context, user);
  }

  /// Xác thực lại người dùng dựa trên phương thức họ đã dùng để đăng nhập / liên kết.
  static Future<bool> reauthenticate(
    BuildContext context, {
    required String reason,
  }) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return false;

    bool isGoogle = user.providerData.any((p) => p.providerId == 'google.com');
    bool isPhone = user.phoneNumber != null && user.phoneNumber!.isNotEmpty;
    if (!isPhone &&
        user.email != null &&
        user.email!.endsWith('@zenhome.local')) {
      isPhone = true;
    }

    if (isGoogle) {
      return await _reauthWithGoogle(context, user, reason);
    } else if (isPhone) {
      return await _reauthWithPhone(context, user);
    } else {
      return await _reauthWithPassword(context, user, reason);
    }
  }

  /// Lớp bảo vệ 2: Bắt buộc xác thực bằng Mật khẩu (nếu tài khoản có mật khẩu)
  static Future<bool> verifyPasswordOnly(
    BuildContext context, {
    required String reason,
  }) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return false;

    bool hasPassword = user.providerData.any((p) => p.providerId == 'password');
    if (!hasPassword || user.email == null) {
      return true;
    }

    return await _reauthWithPassword(context, user, reason);
  }

  /// Lớp bảo vệ 3: Xác thực bằng phương thức gốc (OTP hoặc Google)
  static Future<bool> verifyNativeMethodOnly(BuildContext context) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return false;

    bool isGoogle = user.providerData.any((p) => p.providerId == 'google.com');
    bool isPhone = user.phoneNumber != null && user.phoneNumber!.isNotEmpty;
    if (!isPhone &&
        user.email != null &&
        user.email!.endsWith('@zenhome.local')) {
      isPhone = true;
    }

    if (isGoogle) {
      return await _reauthWithGoogle(
        context,
        user,
        context.tr('verify_identity') ?? 'xác minh danh tính',
      );
    } else if (isPhone) {
      return await _reauthWithPhone(context, user);
    } else {
      return true;
    }
  }

  static Future<bool> _reauthWithGoogle(
    BuildContext context,
    User user,
    String reason,
  ) async {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final zen = context.zenColors;
    bool isConfirmed = false;

    await showZenGlassBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      builder: (ctx) {
        return SafeArea(
          top: false,
          child: SingleChildScrollView(
            physics: const ClampingScrollPhysics(),
            padding: const EdgeInsets.fromLTRB(24, 10, 24, 28),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 64,
                  height: 64,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: LinearGradient(
                      colors: [
                        zen.primary.withOpacity(0.24),
                        zen.primaryAccent.withOpacity(0.08),
                      ],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    border: Border.all(
                      color: zen.primary.withOpacity(0.40),
                      width: 1.4,
                    ),
                  ),
                  child: Icon(
                    Icons.security_rounded,
                    color: isDark ? zen.primaryAccent : zen.primary,
                    size: 32,
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  context.tr('reauth_title') ?? 'Xác thực bảo mật',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w800,
                    letterSpacing: -0.3,
                    color: isDark ? AppColors.darkText : AppColors.lightText,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  context.l10n.reauth_reason_msg(reason),
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 14,
                    height: 1.45,
                    color: isDark
                        ? AppColors.darkTextMuted
                        : AppColors.lightTextMuted,
                  ),
                ),
                const SizedBox(height: 24),
                ZenLiquidGlass(
                  blurSigma: 0,
                  borderRadius: 16,
                  glowColor: zen.primary,
                  customGradient: zen.brandHero,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 18,
                    vertical: 14,
                  ),
                  onTap: () {
                    isConfirmed = true;
                    Navigator.pop(ctx, true);
                  },
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Container(
                        padding: const EdgeInsets.all(4),
                        decoration: const BoxDecoration(
                          color: Colors.white,
                          shape: BoxShape.circle,
                        ),
                        child: Image.asset(
                          'public/google_logo.png',
                          width: 18,
                          height: 18,
                        ),
                      ),
                      const SizedBox(width: 10),
                      Text(
                        context.tr('btn_continue') ?? 'Xác thực với Google',
                        style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w800,
                          color: Colors.white,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 10),
                SizedBox(
                  width: double.infinity,
                  child: ZenGlassButton(
                    label: context.tr('btn_cancel') ?? 'Hủy bỏ',
                    isPrimary: false,
                    onPressed: () => Navigator.pop(ctx, false),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );

    if (!isConfirmed) return false;

    LoadingOverlay.show(context);
    try {
      final String? clientId = dotenv.env['GOOGLE_CLIENT_ID'];
      final GoogleSignIn googleSignIn = GoogleSignIn(serverClientId: clientId);
      await googleSignIn.signOut();
      final GoogleSignInAccount? googleUser = await googleSignIn.signIn();
      if (googleUser == null) {
        LoadingOverlay.hide();
        return false;
      }

      final linkedGoogleProvider = user.providerData
          .where((p) => p.providerId == 'google.com')
          .firstOrNull;
      if (linkedGoogleProvider?.email != null &&
          googleUser.email.toLowerCase() !=
              linkedGoogleProvider!.email!.toLowerCase()) {
        await googleSignIn.signOut();
        LoadingOverlay.hide();
        if (context.mounted) {
          showFloatingToast(
            context,
            context.tr('error') ?? 'Lỗi',
            'Vui lòng chọn đúng tài khoản Google đã liên kết (${linkedGoogleProvider.email}) để xác thực!',
            isError: true,
          );
        }
        return false;
      }

      final GoogleSignInAuthentication googleAuth =
          await googleUser.authentication;
      final credential = GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken: googleAuth.idToken,
      );
      await user.reauthenticateWithCredential(credential);
      LoadingOverlay.hide();
      return true;
    } catch (e) {
      LoadingOverlay.hide();
      try {
        await GoogleSignIn().signOut();
      } catch (_) {}

      if (context.mounted) {
        showFloatingToast(
          context,
          context.tr('error') ?? 'Lỗi',
          context.tr('err_reauth_google_failed') ??
              'Không thể xác thực lại bằng Google',
          isError: true,
        );
      }
      return false;
    }
  }

  static Future<bool> _reauthWithPhone(BuildContext context, User user) async {
    String phoneNumber = user.phoneNumber ?? '';
    if (phoneNumber.isEmpty &&
        user.email != null &&
        user.email!.endsWith('@zenhome.local')) {
      phoneNumber = user.email!.replaceAll('@zenhome.local', '');
    }
    if (phoneNumber.isNotEmpty && !phoneNumber.startsWith('+')) {
      if (phoneNumber.startsWith('0')) {
        phoneNumber = '+84${phoneNumber.substring(1)}';
      } else {
        phoneNumber = '+$phoneNumber';
      }
    }

    if (phoneNumber.isEmpty) {
      try {
        final query = await FirebaseFirestore.instance
            .collection('users')
            .where('uid', isEqualTo: user.uid)
            .get();
        if (query.docs.isNotEmpty) {
          phoneNumber = query.docs.first.data()['phoneNumber'] ?? '';
          if (phoneNumber.isNotEmpty && !phoneNumber.startsWith('+')) {
            if (phoneNumber.startsWith('0')) {
              phoneNumber = '+84${phoneNumber.substring(1)}';
            } else {
              phoneNumber = '+$phoneNumber';
            }
          }
        }
      } catch (_) {}
    }

    if (phoneNumber.isEmpty) return false;

    final isDark = Theme.of(context).brightness == Brightness.dark;
    final zen = context.zenColors;
    bool isSuccess = false;
    String verificationId = '';
    bool codeSent = false;
    bool verifyRequested = false;

    await showZenGlassBottomSheet(
      context: context,
      isScrollControlled: true,
      padBottomForKeyboard: true,
      builder: (ctx) {
        final TextEditingController otpController = TextEditingController();
        return StatefulBuilder(
          builder: (context, setState) {
            if (!verifyRequested) {
              verifyRequested = true;
              FirebaseAuth.instance.verifyPhoneNumber(
                phoneNumber: phoneNumber,
                verificationCompleted: (_) {},
                verificationFailed: (e) {
                  Navigator.pop(ctx);
                  showFloatingToast(
                    context,
                    context.tr('error') ?? 'Lỗi',
                    context.l10n.err_send_otp_failed(e.message ?? ''),
                    isError: true,
                  );
                },
                codeSent: (verId, forceResendingToken) {
                  setState(() {
                    verificationId = verId;
                    codeSent = true;
                  });
                },
                codeAutoRetrievalTimeout: (_) {},
              );
            }

            return SafeArea(
              top: false,
              child: SingleChildScrollView(
                physics: const ClampingScrollPhysics(),
                padding: const EdgeInsets.fromLTRB(24, 10, 24, 26),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 62,
                      height: 62,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: AppColors.emeraldGlow.withOpacity(0.16),
                        border: Border.all(
                          color: AppColors.emeraldGlow.withOpacity(0.4),
                          width: 1.4,
                        ),
                      ),
                      child: const Icon(
                        Icons.sms_rounded,
                        color: AppColors.emeraldGlow,
                        size: 30,
                      ),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      context.tr('reauth_sms_title') ?? 'Xác thực qua SMS',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w800,
                        color: isDark ? AppColors.darkText : AppColors.lightText,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      !codeSent
                          ? (context.tr('reauth_sending_otp') ??
                              'Đang gửi mã OTP đến số điện thoại của bạn...')
                          : context.l10n.reauth_enter_otp_msg(phoneNumber),
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 14,
                        color: isDark
                            ? AppColors.darkTextMuted
                            : AppColors.lightTextMuted,
                      ),
                    ),
                    const SizedBox(height: 20),
                    if (!codeSent)
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 20),
                        child: LogoLoadingIndicator(
                          color: isDark ? zen.primaryAccent : zen.primary,
                          size: 34,
                        ),
                      )
                    else ...[
                      TextField(
                        controller: otpController,
                        keyboardType: TextInputType.number,
                        maxLength: 6,
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 8,
                          color: isDark ? AppColors.darkText : AppColors.lightText,
                        ),
                        decoration: zenGlassInputDecoration(
                          context,
                          hintText: '------',
                        ),
                      ),
                      const SizedBox(height: 14),
                      SizedBox(
                        width: double.infinity,
                        child: ZenGlassButton(
                          label: context.tr('btn_confirm') ?? 'Xác nhận',
                          icon: Icons.verified_rounded,
                          onPressed: () async {
                            if (otpController.text.length != 6) return;
                            LoadingOverlay.show(context);
                            try {
                              final credential = PhoneAuthProvider.credential(
                                verificationId: verificationId,
                                smsCode: otpController.text.trim(),
                              );
                              try {
                                await user
                                    .reauthenticateWithCredential(credential);
                              } catch (e) {
                                await user.linkWithCredential(credential);
                              }
                              isSuccess = true;
                              LoadingOverlay.hide();
                              if (context.mounted) Navigator.pop(ctx);
                            } catch (e) {
                              LoadingOverlay.hide();
                              showFloatingToast(
                                context,
                                context.tr('error') ?? 'Lỗi',
                                context.tr('err_invalid_otp_code') ??
                                    'Mã OTP không hợp lệ',
                                isError: true,
                              );
                            }
                          },
                        ),
                      ),
                    ],
                    const SizedBox(height: 10),
                    SizedBox(
                      width: double.infinity,
                      child: ZenGlassButton(
                        label: context.tr('btn_cancel') ?? 'Hủy',
                        isPrimary: false,
                        onPressed: () => Navigator.pop(ctx),
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
    return isSuccess;
  }

  static Future<bool> _reauthWithPassword(
    BuildContext context,
    User user,
    String reason,
  ) async {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final zen = context.zenColors;
    bool isSuccess = false;

    await showZenGlassBottomSheet(
      context: context,
      isScrollControlled: true,
      padBottomForKeyboard: true,
      builder: (ctx) {
        final TextEditingController passwordController =
            TextEditingController();
        bool obscurePassword = true;
        return StatefulBuilder(
          builder: (context, setState) {
            return SafeArea(
              top: false,
              child: SingleChildScrollView(
                physics: const ClampingScrollPhysics(),
                padding: const EdgeInsets.fromLTRB(24, 10, 24, 26),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 62,
                      height: 62,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: LinearGradient(
                          colors: [
                            zen.primary.withOpacity(0.24),
                            zen.primaryAccent.withOpacity(0.08),
                          ],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        border: Border.all(
                          color: zen.primary.withOpacity(0.40),
                          width: 1.4,
                        ),
                      ),
                      child: Icon(
                        Icons.lock_outline_rounded,
                        color: isDark ? zen.primaryAccent : zen.primary,
                        size: 30,
                      ),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      context.tr('reauth_title') ?? 'Xác thực mật khẩu',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w800,
                        color: isDark ? AppColors.darkText : AppColors.lightText,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      context.l10n.reauth_reason_msg(reason),
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 14,
                        color: isDark
                            ? AppColors.darkTextMuted
                            : AppColors.lightTextMuted,
                      ),
                    ),
                    const SizedBox(height: 20),
                    TextField(
                      controller: passwordController,
                      obscureText: obscurePassword,
                      autofocus: true,
                      decoration: zenGlassInputDecoration(
                        context,
                        labelText: context.tr('password') ?? 'Mật khẩu',
                        prefixIcon: Icons.lock_rounded,
                        suffixIcon: IconButton(
                          icon: Icon(
                            obscurePassword
                                ? Icons.visibility_off_rounded
                                : Icons.visibility_rounded,
                          ),
                          onPressed: () => setState(
                            () => obscurePassword = !obscurePassword,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 20),
                    SizedBox(
                      width: double.infinity,
                      child: ZenGlassButton(
                        label: context.tr('btn_confirm') ?? 'Xác nhận',
                        icon: Icons.verified_user_rounded,
                        onPressed: () async {
                          if (passwordController.text.isEmpty) {
                            showFloatingToast(
                              context,
                              context.tr('error') ?? 'Lỗi',
                              context.tr('err_empty_password') ??
                                  'Vui lòng nhập mật khẩu',
                              isError: true,
                            );
                            return;
                          }
                          LoadingOverlay.show(context);
                          try {
                            final credential = EmailAuthProvider.credential(
                              email: user.email!,
                              password: passwordController.text.trim(),
                            );
                            await user
                                .reauthenticateWithCredential(credential);
                            isSuccess = true;
                            LoadingOverlay.hide();
                            if (context.mounted) Navigator.pop(ctx);
                          } catch (e) {
                            LoadingOverlay.hide();
                            showFloatingToast(
                              context,
                              context.tr('error') ?? 'Lỗi',
                              context.tr('err_wrong_password') ??
                                  'Mật khẩu không đúng',
                              isError: true,
                            );
                          }
                        },
                      ),
                    ),
                    const SizedBox(height: 10),
                    SizedBox(
                      width: double.infinity,
                      child: ZenGlassButton(
                        label: context.tr('btn_cancel') ?? 'Hủy',
                        isPrimary: false,
                        onPressed: () => Navigator.pop(ctx),
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
    return isSuccess;
  }
}
